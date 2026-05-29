import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';
import 'widgets/days_tracker_calendar.dart';

enum OnboardingStep {
  intro,
  howPauseOnOpen,
  howBlockDistractions,
  enableAccessibility,
  trackDays,
  enableUsageAccess,
  allDone,
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.step,
    required this.onGetStarted,
    required this.onContinueFromPauseDemo,
    required this.onContinueFromBlockDemo,
    required this.onOpenAccessibilitySettings,
    required this.onContinueFromTracking,
    required this.onOpenUsageAccessSettings,
    required this.onFinish,
  });

  final OnboardingStep step;
  final VoidCallback onGetStarted;
  final VoidCallback onContinueFromPauseDemo;
  final VoidCallback onContinueFromBlockDemo;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onContinueFromTracking;
  final VoidCallback onOpenUsageAccessSettings;
  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _introFadeStartDelays = [
    Duration(seconds: 2),
    Duration(milliseconds: 5000),
    Duration(milliseconds: 7000),
  ];

  final List<bool> _introVisible = List<bool>.filled(3, false);

  @override
  void initState() {
    super.initState();
    _scheduleIntroAnimation();
  }

  @override
  void didUpdateWidget(covariant OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _scheduleIntroAnimation();
    }
  }

  void _scheduleIntroAnimation() {
    final showImmediately = widget.step != OnboardingStep.intro;
    for (var index = 0; index < _introVisible.length; index++) {
      _introVisible[index] = showImmediately;
    }
    if (mounted) {
      setState(() {});
    }
    if (showImmediately) return;

    for (var index = 0; index < _introFadeStartDelays.length; index++) {
      Future<void>.delayed(_introFadeStartDelays[index], () {
        if (!mounted || widget.step != OnboardingStep.intro) return;
        setState(() {
          _introVisible[index] = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentForStep();
    final isIntro = widget.step == OnboardingStep.intro;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        ...?currentChild == null ? null : [currentChild],
                      ],
                    );
                  },
                  child: Column(
                    key: ValueKey(widget.step),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: isIntro
                            ? _buildIntroContent()
                            : _buildStepContent(content),
                      ),
                      _fadeItem(
                        2,
                        FilledButton(
                          onPressed: content.onPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(content.buttonLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroContent() {
    const bodyStyle = TextStyle(
      fontSize: 24,
      height: 1.5,
      color: Color(0xFF5F6B7A),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _fadeItem(
          0,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/images/work_time_pana.svg',
                width: double.infinity,
                height: 320,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              const Text(
                'The average person spends 10.4% of their life scrolling.',
                textAlign: TextAlign.left,
                style: bodyStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _fadeItem(
          1,
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: bodyStyle,
              children: [
                TextSpan(
                  text: 'Tempus',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: brand,
                  ),
                ),
                const TextSpan(text: ' will help you.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fadeItem(int index, Widget child) {
    return AnimatedOpacity(
      opacity: _introVisible[index] ? 1 : 0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _introVisible[index] ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }

  Widget _buildStepContent(_OnboardingContent content) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          content.title,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        if (content.subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            content.subtitle!,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              color: Color(0xFF5F6B7A),
            ),
          ),
        ],
        if (content.preview != null) ...[
          const SizedBox(height: 28),
          content.preview!,
        ],
        if (content.description != null) ...[
          const SizedBox(height: 18),
          Text(
            content.description!,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF5F6B7A),
            ),
          ),
        ],
      ],
    );
  }

  _OnboardingContent _contentForStep() {
    switch (widget.step) {
      case OnboardingStep.intro:
        return _OnboardingContent(
          title: '',
          buttonLabel: 'Get Started',
          onPressed: widget.onGetStarted,
        );
      case OnboardingStep.howPauseOnOpen:
        return _OnboardingContent(
          title: 'How it works:',
          subtitle: '1. Pause on Open',
          preview: const _HowItWorksCard(
            child: _ReadonlyAppCard(
              appName: 'Instagram',
              iconAssetPath: 'assets/apps/instagram.svg',
              items: [
                _ReadonlyBlockItem(
                  label: 'Pause on Open',
                  iconAssetPath: 'assets/icons/pause_on_open.svg',
                  isEnabled: true,
                  borderWidth: 2,
                ),
              ],
            ),
          ),
          description:
              'Tempus can pause you before you slip into an automatic session. Open the app, check in with yourself, then decide if you actually want to continue.',
          buttonLabel: 'Next',
          onPressed: widget.onContinueFromPauseDemo,
        );
      case OnboardingStep.howBlockDistractions:
        return _OnboardingContent(
          title: 'How it works:',
          subtitle: '2. Block distractions',
          preview: const _HowItWorksCard(
            child: _ReadonlyAppCard(
              appName: 'Instagram',
              iconAssetPath: 'assets/apps/instagram.svg',
              items: [
                _ReadonlyBlockItem(label: 'Block Reels', isEnabled: true),
                _ReadonlyBlockItem(
                  label: 'Allow Reels in DMs',
                  iconAssetPath: 'assets/icons/instagram_reels_dm.svg',
                  isEnabled: false,
                  isSubItem: true,
                  useCheckbox: true,
                ),
              ],
            ),
          ),
          description:
              'You can block the parts of apps that waste your time most, while still keeping the rest of the app available for the things you actually need.',
          buttonLabel: 'Next',
          onPressed: widget.onContinueFromBlockDemo,
        );
      case OnboardingStep.enableAccessibility:
        return _OnboardingContent(
          title: 'Enable Accessibility',
          subtitle:
              'Tempus needs Accessibility to detect supported apps and show blocking prompts.',
          preview: const _PermissionBadge(
            icon: Icons.accessibility_new_rounded,
          ),
          buttonLabel: 'Open Accessibility Settings',
          onPressed: widget.onOpenAccessibilitySettings,
        );
      case OnboardingStep.trackDays:
        return _OnboardingContent(
          title: 'Tempus keeps track for you.',
          subtitle:
              'Your scrolling-free days are tracked automatically, so you can see momentum build over time.',
          preview: const _ScrollFreeDaysPreview(),
          buttonLabel: 'Next',
          onPressed: widget.onContinueFromTracking,
        );
      case OnboardingStep.enableUsageAccess:
        return _OnboardingContent(
          title: 'Enable Usage Access',
          subtitle:
              'Usage access lets Tempus measure time limits and track how long apps are open.',
          preview: const _PermissionBadge(icon: Icons.query_stats_rounded),
          buttonLabel: 'Open Usage Access Settings',
          onPressed: widget.onOpenUsageAccessSettings,
        );
      case OnboardingStep.allDone:
        return _OnboardingContent(
          title: 'All Done',
          subtitle:
              'Tempus is set up and ready. You can start using the app now.',
          preview: const _PermissionBadge(icon: Icons.done_all_rounded),
          buttonLabel: 'Next',
          onPressed: widget.onFinish,
        );
    }
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
    this.subtitle,
    this.preview,
    this.description,
  });

  final String title;
  final String? subtitle;
  final Widget? preview;
  final String? description;
  final String buttonLabel;
  final VoidCallback onPressed;
}

class _PermissionBadge extends StatelessWidget {
  const _PermissionBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: brand.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 50, color: brand),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _ReadonlyAppCard extends StatelessWidget {
  const _ReadonlyAppCard({
    required this.appName,
    required this.iconAssetPath,
    required this.items,
  });

  final String appName;
  final String iconAssetPath;
  final List<_ReadonlyBlockItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: SvgPicture.asset(iconAssetPath, fit: BoxFit.fill),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      appName,
                      style: const TextStyle(
                        color: appText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: appText,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          for (final item in items) _ReadonlyBlockItemRow(item: item),
        ],
      ),
    );
  }
}

class _ReadonlyBlockItem {
  const _ReadonlyBlockItem({
    required this.label,
    this.iconAssetPath,
    required this.isEnabled,
    this.isSubItem = false,
    this.useCheckbox = false,
    this.borderWidth = 1.5,
  });

  final String label;
  final String? iconAssetPath;
  final bool isEnabled;
  final bool isSubItem;
  final bool useCheckbox;
  final double borderWidth;
}

class _ReadonlyBlockItemRow extends StatelessWidget {
  const _ReadonlyBlockItemRow({required this.item});

  final _ReadonlyBlockItem item;

  @override
  Widget build(BuildContext context) {
    final rowMinHeight = item.isSubItem ? 42.0 : 52.0;
    final horizontalPadding = item.isSubItem ? 12.0 : 14.0;
    final leadingGap = item.isSubItem ? 8.0 : 10.0;
    final leadingInset = item.isSubItem ? 26.0 : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: rowMinHeight),
        child: Row(
          children: [
            SizedBox(width: leadingInset),
            if (item.iconAssetPath != null)
              SvgPicture.asset(
                item.iconAssetPath!,
                width: item.isSubItem ? 20 : 22,
                height: item.isSubItem ? 20 : 22,
                colorFilter: const ColorFilter.mode(
                  appMutedText,
                  BlendMode.srcIn,
                ),
              )
            else
              const SizedBox(width: 22, height: 22),
            SizedBox(width: leadingGap),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.useCheckbox)
              _ReadonlyCheckbox(
                value: item.isEnabled,
                borderWidth: item.borderWidth,
              )
            else
              _ReadonlySwitch(
                value: item.isEnabled,
                borderWidth: item.borderWidth,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadonlySwitch extends StatelessWidget {
  const _ReadonlySwitch({required this.value, required this.borderWidth});

  final bool value;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Switch(
        value: value,
        onChanged: (_) {},
        activeThumbColor: brand,
        activeTrackColor: brand.withValues(alpha: 0.35),
        inactiveThumbColor: appBackground,
        inactiveTrackColor: appBorder,
        trackOutlineColor: WidgetStateProperty.all(brand),
        trackOutlineWidth: WidgetStateProperty.all(borderWidth),
      ),
    );
  }
}

class _ReadonlyCheckbox extends StatelessWidget {
  const _ReadonlyCheckbox({required this.value, required this.borderWidth});

  final bool value;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Checkbox(
        value: value,
        onChanged: (_) {},
        activeColor: brand,
        checkColor: appBackground,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brand;
          }
          return appBackground;
        }),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: brand, width: borderWidth);
          }
          return BorderSide(color: brand, width: borderWidth);
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ScrollFreeDaysPreview extends StatelessWidget {
  const _ScrollFreeDaysPreview();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final previewSpanDays = today.day >= 5 ? 4 : today.day - 1;
    final firstTrackableDate = today.subtract(Duration(days: previewSpanDays));
    final previewMonth = DateTime(today.year, today.month);
    final previewStatuses = <String, ScrollDayStatus>{
      for (var offset = 1; offset <= previewSpanDays; offset++)
        calendarDateKey(
          firstTrackableDate.add(Duration(days: offset)),
        ): offset < previewSpanDays
            ? ScrollDayStatus.noScroll
            : ScrollDayStatus.partialScroll,
    };

    return DaysTrackerCalendarCard(
      title: 'Distraction-Free Days',
      month: previewMonth,
      dayStatuses: previewStatuses,
      firstTrackableDate: firstTrackableDate,
      cellSize: 24,
      columnGap: 10,
      padding: const EdgeInsets.all(14),
    );
  }
}
