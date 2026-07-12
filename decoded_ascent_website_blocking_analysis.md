# Decoded Ascent Website Blocking Analysis

## Scope

This document analyzes how `decoded_ascent` performs website blocking, based on the decompiled Android app contents under `decoded_ascent/`.

This is reverse-engineering, not source-level review. Some class names are obfuscated or generic, so a few details below are marked as **inference** when they are not explicitly named in code but are strongly implied by wiring and behavior.

## Executive Summary

The app does **not** appear to block websites at the network layer.

It is **not** using:

- Android `VpnService`
- DNS interception
- proxy-based filtering
- host file rewriting

Instead, website blocking is implemented primarily as an **AccessibilityService-driven foreground inspection system**:

1. The service watches app/window/accessibility events.
2. It determines the current foreground package.
3. For supported browsers and in-app browsers, it extracts visible URL/domain text from accessibility nodes.
4. It normalizes the extracted text into a host/domain.
5. It compares that host against the blocked website set using exact-or-subdomain matching.
6. When matched, it opens the app's generic block-state machine and routes into the Ascent block screen flow.

There is also a second path for **generic in-app content/webview detection** that reuses the same block framework. That path is broader than simple browser URL scraping and appears intended for apps whose content is web-like or content-classifiable through accessibility tree snapshots.

## High-Confidence Findings

### 1. Core mechanism is Accessibility, not network filtering

The manifest registers `com.sobol.oneSec.presentation.appblockscreen.AppBlockService` as an accessibility service and binds it with `android.permission.BIND_ACCESSIBILITY_SERVICE`.

There is no evidence of `VpnService`-style website interception in the manifest.

This means blocking is based on **what is currently visible and detectable in the UI**, not on packets, DNS requests, or TCP connections.

## Main Components

### AppBlockService

Primary class:

- `decoded_ascent/smali_classes2/com/sobol/oneSec/presentation/appblockscreen/AppBlockService.smali`

This is the main runtime entry point for blocking logic. It:

- receives accessibility events
- tracks the active package
- forwards events into website/content trackers
- owns the blocking coordinators

It lazily constructs `e3/l`, which is the central coordinator for website and content blocking.

Important detail: when `AppBlockService` constructs `e3/l`, it passes:

- `selfAppPackage` = the app's own package name
- `siteRedirectDomain` = **`google.com`**

This hardcoded `google.com` value is relevant to the anti-loop logic discussed later.

### Central coordinator: `e3/l`

Main file:

- `decoded_ascent/smali/e3/l.smali`

This class is the hub that ties together:

- browser-site tracking (`n3/j`)
- generic content/webview tracking (`l3/j`)
- current blocking parameters (`e3/j`)
- delay control
- block action emission

It implements both `n3/f` and `l3/f`, meaning it listens for state changes from both website-domain tracking and generic content tracking.

Its responsibilities include:

- resolving which blocking targets apply to the current package
- choosing whether a block action should be routed through the website matcher or the content matcher
- keeping `j:Lp3/c;` as the current active blocked target
- clearing or reinitializing state when packages change

## Foreground Event Flow

### Event gating in `AppBlockService`

Based on `AppBlockService.onAccessibilityEvent` behavior:

1. **Window/package change events** update the tracked foreground package.
2. Only if the event package matches the currently tracked active package does the service continue.
3. Some event types trigger the website/content extraction path.
4. The service avoids acting on stale or mismatched package events.

This is a crucial heuristic: the app is trying to prevent incorrect blocks caused by asynchronous accessibility noise.

### Active package resolution

`decoded_ascent/smali/d3/d.smali` contains helpers that:

- find the active/focused application window
- return its root node
- derive the active package from that root

This is safer than trusting every event's package blindly, because accessibility events can arrive after focus has shifted.

### Event-type heuristic

`d3/d.d(...)` only returns true for two event types:

- `0x800`
- `0x400000`

These are the event classes that trigger website/content snapshot processing.

This is a deliberate heuristic: the app does **not** re-run expensive extraction on every accessibility event. It limits website analysis to a narrower subset of content/window updates.

## Browser URL Extraction

## Supported-browser model

Browser support is encoded statically.

Main files:

- `decoded_ascent/smali/s5/c.smali`
- `decoded_ascent/smali/s5/i.smali`

`s5/c` contains a catalog of package identifiers for supported browsers and in-app browsers.

Examples present in the package catalog include:

- Chrome / Chrome Go
- Google app browser
- Firefox variants
- Brave variants
- Opera variants
- Edge
- DuckDuckGo
- Samsung Internet
- Xiaomi browser
- Instagram in-app browser
- TikTok variants
- LinkedIn in-app browser

### Per-browser locator configuration

`s5/i` is effectively a table of browser-specific extraction configs.

Each entry binds a browser package to:

- one or more accessibility node locators (`q3/c$d`)
- optional text transformation logic
- flags controlling extraction behavior
- an optional view-class matcher

Examples visible in the table:

- Chrome uses `com.android.chrome:id/url_bar`
- Chrome Go uses `com.google.android.apps.searchlite:id/webx_url_bar`
- other browsers use their own address-bar IDs
- Instagram in-app browser uses `com.instagram.android:id/ig_browser_text_subtitle`

This means the system is **not** using a universal browser API. It is scraping the visible browser UI with a compatibility table.

### Why this matters

This approach has clear properties:

- It works without network privileges.
- It can block based on the actual foreground browser page.
- It is brittle against browser UI changes.
- Coverage depends on known packages and stable view IDs.

If a browser updates its address bar structure or resource IDs, detection can degrade until the app ships updated mappings.

## Text extraction and sanitation

Several helper layers are involved in getting useful text out of accessibility nodes.

### `p4/d.a(node, strict)`

File:

- `decoded_ascent/smali/p4/d.smali`

This helper:

- reads node text through accessibility helpers
- removes replacement-character noise (`U+FFFD`)
- trims whitespace
- optionally requires at least one alphanumeric character before considering the text usable

That is a small but meaningful heuristic: it helps reject garbage strings or decorative text that can appear in accessibility trees.

### Accessibility traversal helpers

`decoded_ascent/smali/d3/c.smali` is a large utility around `AccessibilityNodeInfo`. It includes:

- recursive traversal
- visibility checks
- `findAccessibilityNodeInfosByViewId(...)`
- content/class checks including `WebView`

This utility layer is likely reused by both browser URL extraction and the broader view-tree snapshot path.

## Domain Normalization

The most important normalization code lives in:

- `decoded_ascent/smali/n7/a.smali`
- `decoded_ascent/smali/n3/e.smali`

### `n7/a.a(urlOrHost)`

Behavior:

1. If the input is a valid URL according to `URLUtil.isValidUrl(...)`:
   - parse with `java.net.URI`
   - take the host
   - strip a leading `www.`
2. Otherwise:
   - run a regex-based extraction helper to pull domain-like text out of arbitrary strings
3. On failure:
   - fall back toward the original string or regex result

This is important because accessibility text is often not a clean URL. Browsers may show:

- just a hostname
- a shortened URL
- a subtitle-like domain string
- partially formatted strings

The fallback regex path is what lets the app still recover a usable domain from those UI strings.

### `n3/e.b(input)`

After `n7/a.a(...)`, this layer:

- strips everything after the first `/`
- returns an empty string on failure

So the final comparison unit is effectively a host/domain, not a full URL path.

## Matching Logic

### Core matcher

The core match rule is in `n3/e.a(candidate, blocked)`.

The rule is:

- match if `candidate == blocked` ignoring case
- or match if `candidate` ends with `"." + blocked` ignoring case

Examples:

- blocked `instagram.com` matches `instagram.com`
- blocked `instagram.com` matches `www.instagram.com`
- blocked `instagram.com` matches `help.instagram.com`

This is a simple but effective **exact-or-subdomain** model.

### Implications

Benefits:

- good coverage for real browsing
- users do not need to enter every subdomain manually

Risks:

- matching is suffix-based, not public-suffix aware
- correctness depends on blocked entries being reasonable domain values

I did not find evidence here of a stricter eTLD+1 or PSL-aware host matcher.

## Website State Machine

### Event bus

`decoded_ascent/smali/n3/d.smali` is a listener dispatcher with three relevant signals:

- `a(package)` -> package closed/left
- `r0(package, domain)` -> direct package/domain signal
- `w0(event)` -> richer event object `n3/d$b`

### Domain tracker and state machine wrapper: `n3/j`

File:

- `decoded_ascent/smali/n3/j.smali`

This is the main website-domain blocking state controller.

It:

- listens to the browser-site tracker event bus
- resolves observed domains against the blocked set
- feeds a state machine (`i3/c`)
- deduplicates repeated observations
- closes state when package context changes

### How `l(n3/d$b)` behaves

This is the richest part of the logic.

When a normalized observed domain arrives:

1. It reads the currently blocked website set from `blockingParamsHolder.getState().c()`.
2. It tries to find a matching blocked target via `n3/e.c(blockedSet, observedInput)`.
3. If matched, it uses the matched blocked target.
4. If not matched, it still creates a `p3/c$i(observedInput)` target.
5. It checks the current machine state:
   - if the current state is already open for the same target, it does nothing
6. Otherwise it:
   - closes the previous state
   - opens a new context if the observed domain is nonblank

This means the website tracker maintains a **current foreground site context**, even when the observed site is not currently blocked. The block/allow decision is layered on top of that context.

### Direct package-domain path: `W(package, domain)`

A second path accepts a package/domain pair directly.

Before opening state, it rejects:

- blocked-by-delay situations
- blank domains

Then it opens the state machine for `k3/a(package, p3/c$i(domain))`.

### Close behavior

`a(package)` closes the current website state unless delay logic suppresses activity.

This is the package-exit cleanup path.

## Anti-loop / self-app logic

One subtle behavior is in `n3/j.z(previousPackage, newPackage)`.

There are two distinct branches:

### If leaving a package that is not the app itself

It closes the current website state immediately.

### If the app itself is now foreground

If:

- the previous package equals the app's own package
- the current state is open
- the new package equals the package already tracked in the open context

then it reopens the current context using a synthetic website target:

- `p3/c$i(siteRedirectDomain)`

and that redirect domain is the hardcoded `google.com`.

### Interpretation

This appears to be a **self-loop guard / redirect sentinel**.

Most likely purpose:

- when Ascent's own block UI becomes foreground during a website-block flow, the service rewrites the tracked website target to a safe sentinel domain so it does not keep recursively treating its own UI transition as the original blocked website still being actively visited

This is one of the stronger signs that the blocking system is built around foreground UI state rather than network events.

## Generic Content / WebView Snapshot Path

Website blocking is not limited to classic browser URL bars.

There is another path centered on:

- `decoded_ascent/smali/l3/j.smali`
- base class `decoded_ascent/smali/m3/d.smali`
- analyzer `decoded_ascent/smali/l3/d.smali`

### What this path does

This machinery takes a current target context and a view-tree snapshot, then tries to locate relevant nodes for content-based blocking.

`e3/l.m(activePackage, event)`:

- gets package-specific `p3/c$e` targets from the current blocking state
- caches them for the active package
- sends them into `l3/j.S0(...)`

The `p3/c$e` targets include content-like targets such as `p3/c$d` and `p3/c$h`, not plain website-domain targets.

### Base behavior in `m3/d`

The generic snapshot engine:

- owns another `i3/c` state machine
- requests view-tree snapshots through `a3/u`
- debounces analysis
- refreshes/validates nodes before accepting them
- closes state when nodes become invalid or package changes

Important timing heuristics:

- snapshot helper `a3/h` is created with a `3000 ms` interval
- temporary timers (`y6/d`) are used to age out or debounce state

### Node validity checks

`l3/e.b(config, node)` enforces:

- optional `node.refresh()` success
- optional `node.isVisibleToUser()`

If a node fails these checks, the state is closed.

This prevents stale hidden nodes from keeping a block context alive.

### Snapshot-analysis throttling

`l3/d` keeps a per-target map keyed by target name and stores a `500 ms` timer (`y6/d`) when a node is accepted.

Interpretation:

- after a successful content detection for a given target category, the app likely throttles immediate re-analysis for that category

This is a practical heuristic to reduce accessibility-tree churn and repeated work.

### Why this matters for website blocking

The app appears to have **two layers**:

1. **Domain-oriented website blocking** for browsers and in-app browsers
2. **Content/webview-oriented blocking** for cases where the URL alone is insufficient or unavailable

That makes the system broader than "read the address bar and compare strings".

## How browser extraction feeds the matcher

`AppBlockService$a` bridges lower-level extraction results into the website tracker:

- `a(packageName)` -> forwards close/package-exit events to `n3/d.a(package)`
- `b(packageName, domain)` -> normalizes the domain via `n3/e.b(...)`, then forwards `n3/d.r0(package, normalizedDomain)`
- `c(url, packageName)` -> normalizes the URL/domain into `n3/d$b(normalizedHost, package)` and forwards it via `n3/d.w0(...)`

This bridge matters because it shows normalization is enforced before the website tracker receives data.

## Blocked Website Storage

Relevant files:

- `decoded_ascent/smali/jj/a.smali`
- `decoded_ascent/smali/jg/b.smali`
- `decoded_ascent/smali/jg/k.smali`

### Data model

`jj/a` is a `BlockedWebsiteEntity(domain, isSelected)` model.

### Repository behavior

`jg/k` appears to be the repository backing website blocking state, likely through preferences/DataStore-style persistence.

Visible operations include:

- add single domain
- remove single domain
- bulk remove domains
- get deduplicated flow of current blocked websites
- clear primary collection

There also appears to be a secondary collection/flow, likely related to temporarily disabled or timeout-managed website blocking.

## Timed Disable / Re-enable

Website blocking includes a timeout layer, but it is **not** the interception mechanism itself.

Relevant files:

- `decoded_ascent/smali/lj/a.smali`
- `decoded_ascent/smali/lj/b.smali`
- `decoded_ascent/smali/kj/d.smali`
- `decoded_ascent/smali/kj/c.smali`
- `decoded_ascent/smali/kj/b.smali`
- `decoded_ascent/smali_classes2/com/sobol/oneSec/presentation/appsectionsblock/websiteblock/timeout/EnableWebsitesBlockWorker.smali`

### What it does

This subsystem uses WorkManager to re-enable website blocking after a timed suspension.

The worker reads a website option key, then calls back into the website-block timeout activator.

Interpretation:

- user temporarily disables a website block
- app schedules unique background work for that domain
- when the timeout expires, the worker restores the blocked status

This is operational policy, not runtime detection.

## Integration with the Generic Ascent Block Flow

Website blocking is not a standalone browser redirect feature. It plugs into the app's broader restriction framework.

### Website block action builder

`decoded_ascent/smali_classes2/bk/a.smali`

This class:

- accepts only `p3/c$i` website targets
- checks current block-state collections
- emits `AscentBlockScreenAction$ProcessSiteBlock(...)`

The action includes:

- the block target
- whether premium is purchased
- the blocked site string

### Block screen model path

Files such as:

- `decoded_ascent/smali_classes2/com/sobol/oneSec/presentation/appblockscreen/model/AscentBlockScreenAction$ProcessSiteBlock.smali`
- `decoded_ascent/smali/jj/c.smali`

show that website blocks are rendered through the same block-screen framework used by the rest of the app. The screen can also incorporate alternative actions such as bookmarks/shortcuts.

## Heuristics Summary

These are the main heuristics and design choices visible in the code.

### Foreground/package heuristics

- trust the active window/root package, not every raw event
- ignore mismatched package events
- close state on package transitions

### Event-frequency heuristics

- only process website/content extraction on selected event types
- throttle or debounce repeated snapshot analysis

### Browser-support heuristics

- use a static allowlist of supported browser packages
- use browser-specific address-bar node IDs
- fall back to content/webview analysis for broader app contexts

### Text-quality heuristics

- remove malformed replacement characters
- trim whitespace
- require alphanumeric content in stricter paths
- recover domain-like text via regex when input is not a valid URL

### Match heuristics

- compare normalized hostnames
- match exact domain or subdomain suffix
- ignore path/query components

### Node-validity heuristics

- require `refresh()` success in some paths
- require visibility in some paths
- close state when nodes become stale/invisible

### Loop-prevention heuristics

- rewrite active target to sentinel `google.com` in a self-app foreground transition case

## Strengths of This Design

- No VPN permission required.
- Works across many browsers and in-app browsers.
- Can act on what the user is actually viewing.
- Integrates cleanly with an app-level block/pause/reminder framework.
- Subdomain matching gives practical coverage for normal browsing.

## Weaknesses / Likely Failure Modes

### 1. Browser UI fragility

Because extraction relies on package-specific accessibility IDs, browser updates can break detection.

### 2. Coverage gaps for unsupported browsers

If a browser or embedded browser is not in the static compatibility table, direct URL-based website blocking may fail.

### 3. Accessibility visibility limits

If the URL is hidden, collapsed, non-accessible, or rendered in a custom inaccessible widget, the URL path may fail and the app must rely on broader snapshot/content heuristics.

### 4. Suffix-based matching simplicity

The matcher is practical but simple. It does not appear to perform full public-suffix or registrable-domain reasoning.

### 5. Foreground-only nature

This system blocks based on foreground UI context. It is not stopping network access in the background.

Implication:

- if content is fetched in the background but never presented in a detectable foreground UI state, this logic would not block it at the transport layer

## Best Reconstruction of the Runtime Logic

Pseudo-flow:

```text
onAccessibilityEvent(event):
  activePackage = resolveForegroundPackage()
  updateTrackedPackageIfNeeded(activePackage)

  if event.package != activePackage:
    ignore

  if eventType is package/window transition:
    notify package-change trackers

  if eventType is content/window-content relevant:
    if active package is supported browser/in-app browser:
      scrape visible URL/domain text from configured nodes
      normalize to host
      emit browser site event

    also run package-specific content/webview snapshot checks

browser site event(domain, package):
  normalized = normalize(domain)
  blockedMatch = find blocked target by exact-or-subdomain match

  if current open site target == blockedMatch or observed target:
    keep state
  else:
    close old site state
    open new site context

if context resolves to blocked website:
  emit ProcessSiteBlock
  show Ascent block screen
```

## Bottom Line

`decoded_ascent` performs website blocking through a **foreground accessibility-inspection architecture** built from:

- browser-specific address-bar scraping
- URL/domain normalization
- suffix-based domain matching
- a state machine that tracks the current website context
- a secondary content/webview snapshot path
- the app's generic block-screen action framework

The blocking is therefore best described as:

**UI-observed website blocking**, not network enforcement.

That is the single most important architectural fact about how this app blocks websites.

## Evidence Index

- Accessibility service and service wiring:
  - `decoded_ascent/AndroidManifest.xml`
  - `decoded_ascent/smali_classes2/com/sobol/oneSec/presentation/appblockscreen/AppBlockService.smali`
- Browser package catalog and per-browser URL-node mappings:
  - `decoded_ascent/smali/s5/c.smali`
  - `decoded_ascent/smali/s5/i.smali`
- Active package / event filtering helpers:
  - `decoded_ascent/smali/d3/d.smali`
- Domain normalization and matching:
  - `decoded_ascent/smali/n7/a.smali`
  - `decoded_ascent/smali/n3/e.smali`
- Website-domain tracker and state machine:
  - `decoded_ascent/smali/n3/d.smali`
  - `decoded_ascent/smali/n3/j.smali`
- Content/webview snapshot path:
  - `decoded_ascent/smali/e3/l.smali`
  - `decoded_ascent/smali/l3/j.smali`
  - `decoded_ascent/smali/l3/d.smali`
  - `decoded_ascent/smali/l3/e.smali`
  - `decoded_ascent/smali/m3/d.smali`
- Blocked website persistence:
  - `decoded_ascent/smali/jg/k.smali`
  - `decoded_ascent/smali/jj/a.smali`
- Timeout re-enable path:
  - `decoded_ascent/smali/kj/b.smali`
  - `decoded_ascent/smali/kj/c.smali`
  - `decoded_ascent/smali_classes2/com/sobol/oneSec/presentation/appsectionsblock/websiteblock/timeout/EnableWebsitesBlockWorker.smali`
- Site block UI integration:
  - `decoded_ascent/smali_classes2/bk/a.smali`
  - `decoded_ascent/smali_classes2/com/sobol/oneSec/presentation/appblockscreen/model/AscentBlockScreenAction$ProcessSiteBlock.smali`
