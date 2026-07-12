# Stats Tab Performance And Reliability Plan

## Objective

Reduce stats tab load time, eliminate the production case where the tab appears to load forever, and improve fallback behavior when native stats generation is slow.

## Root Problems

1. Native stats generation rescans `UsageEvents` many times across overlapping ranges.
2. Native stats generation pulls in heavyweight installed-app metadata and icon encoding that the stats computation does not need.
3. A long-running native stats request can occupy the single-thread executor and block all later refreshes.
4. Flutter blocks the whole stats tab on loading instead of showing cached data while refresh work continues.
5. Persisted fallback snapshots are incomplete and lose some chart/detail data.
6. Flutter rebuilds some derived statistics structures repeatedly in widget build paths.

## Implementation Plan

### 1. Refactor Android stats aggregation to a shared precomputed model

Replace repeated `UsageEvents` rescans in `getStatisticsData` with a single shared aggregation pass over the 30-day window.

Scope:

- Build one in-memory model for:
  - foreground usage by package
  - per-day usage totals
  - per-day hourly totals
  - per-app session counts
  - per-app longest session lengths
  - per-app daily minutes
  - per-app hourly minutes
- Reuse that model to derive:
  - overview
  - daily summaries
  - app summaries
  - trend data
  - time-of-day data

Expected impact:

- Largest reduction in native compute time
- Lower chance of timeout on slower devices
- Cleaner foundation for later fixes

### 2. Remove heavyweight app discovery from native stats generation

Ensure the stats endpoint does not call the full installed-app loading path or encode icons.

Scope:

- Split app definition discovery from UI app metadata loading
- Keep stats generation limited to lightweight identifiers and names
- Leave icons and richer app metadata to the separate Flutter-side installed-app request

Expected impact:

- Faster native stats generation
- Less memory allocation
- Less unnecessary package manager and bitmap work

### 3. Make stats refreshes stale-safe

Prevent one long-running native stats request from blocking future refreshes indefinitely.

Scope:

- Add request generation or cancellation semantics around `getStatisticsData`
- Ensure queued or stale work does not continue to own the only executor worker once a newer request exists
- Make repeated refreshes safe under slow or failing native work

Expected impact:

- Fix for the production “loads forever” class of failure
- Better recovery after timeouts
- More predictable refresh behavior

### 4. Improve Flutter loading UX

Render usable statistics as early as possible instead of blocking the tab on a loading state.

Scope:

- If a cached snapshot exists, show it immediately while native refresh continues
- Treat installed-app metadata as non-blocking
- Avoid full-screen loading when only enrichment work is pending
- Preserve retry and error messaging without hiding existing data

Expected impact:

- Better perceived performance
- Fewer blank/spinner-only states
- Better resilience when native refresh is slow

### 5. Persist the full fallback snapshot shape

Make timeout fallback data complete enough to support the full stats UI.

Scope:

- Save hourly fields such as:
  - `hourlyTrackedMinutes`
  - `appHourlyTrackedMinutes`
- Verify persisted data covers the charts and app detail views used by the tab

Expected impact:

- Better fallback experience after timeout or native failure
- Fewer degraded charts or missing details

### 6. Reduce Flutter-side recomputation

Move derived statistics transforms out of hot build paths where possible.

Scope:

- Cache or precompute:
  - merged display snapshot
  - app-filtered daily structures
  - other repeated per-build reductions over large daily/app collections
- Recompute only when snapshot or filter inputs change

Expected impact:

- Smoother rendering
- Lower UI thread work
- Less rebuild overhead on interactions

## Execution Order

Implement in this order:

1. Android aggregation refactor
2. Remove heavyweight app discovery from stats path
3. Stale-safe refresh handling
4. Flutter loading UX improvements
5. Full snapshot persistence
6. Flutter-side recomputation cleanup

Rationale:

- Steps 1 and 2 remove the root compute cost.
- Step 3 addresses the worst production reliability failure.
- Steps 4 through 6 improve perceived performance and fallback quality after the main bottlenecks are fixed.

## Validation Plan

After implementation, validate:

1. Cold open of the stats tab on a device with significant usage history
2. Repeated manual refreshes while a previous refresh is still running
3. Timeout path with cached snapshot fallback
4. App-detail navigation from home usage segments into the stats tab
5. Rendering of hourly charts and app detail views from persisted fallback data
6. Native refresh recovery after a previous slow or failed request

## Success Criteria

- Stats tab becomes meaningfully faster on first open
- Refreshes no longer get stuck behind stale long-running native work
- Cached data appears quickly when available
- Timeout fallback remains fully usable
- UI interactions in the stats tab remain smooth after data loads
