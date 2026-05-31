import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';
import 'widgets/days_tracker_calendar.dart';

enum OnboardingStep {
  intro,
  howPauseOnOpen,
  howBlockDistractions,
  enableAccessibility,
  accessibilityGoodStuff,
  trackDays,
  enableUsageAccess,
  allDone,
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.step,
    required this.onBack,
    required this.onGetStarted,
    required this.onContinueFromPauseDemo,
    required this.onContinueFromBlockDemo,
    required this.onOpenAccessibilitySettings,
    required this.onContinueFromAccessibilitySuccess,
    required this.onContinueFromTracking,
    required this.onOpenUsageAccessSettings,
    required this.onFinish,
  });

  final OnboardingStep step;
  final VoidCallback? onBack;
  final VoidCallback onGetStarted;
  final VoidCallback onContinueFromPauseDemo;
  final VoidCallback onContinueFromBlockDemo;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onContinueFromAccessibilitySuccess;
  final VoidCallback onContinueFromTracking;
  final VoidCallback onOpenUsageAccessSettings;
  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _introFadeStartDelays = [
    Duration(milliseconds: 1000),
    Duration(milliseconds: 2500),
    Duration(milliseconds: 4000),
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
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: widget.onBack == null
                      ? const SizedBox(width: 48, height: 48)
                      : Transform.translate(
                          offset: const Offset(-8, 0),
                          child: IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: const Color(0xFF111827),
                            tooltip: 'Back',
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                ),
              ),
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
    final textAlign = content.centerText ? TextAlign.center : TextAlign.left;
    final crossAxisAlignment = content.centerText
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.stretch;
    final showPreviewFirst = content.centerText;

    final contentColumn = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (showPreviewFirst && content.preview != null) ...[
          content.preview!,
          const SizedBox(height: 28),
        ],
        Text(
          content.title,
          textAlign: textAlign,
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
            textAlign: textAlign,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              color: Color(0xFF5F6B7A),
            ),
          ),
        ],
        if (!showPreviewFirst && content.preview != null) ...[
          const SizedBox(height: 28),
          content.preview!,
        ],
        if (content.description != null) ...[
          const SizedBox(height: 18),
          Text(
            content.description!,
            textAlign: textAlign,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF5F6B7A),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );

    if (content.centerVertically) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const Spacer(),
                contentColumn,
                const SizedBox(height: 44),
                const Spacer(),
              ],
            ),
          );
        },
      );
    }

    return SingleChildScrollView(child: contentColumn);
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
          centerVertically: true,
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
          centerVertically: true,
        );
      case OnboardingStep.enableAccessibility:
        return _OnboardingContent(
          title: 'Accessibility',
          subtitle:
              'Tempus needs Accessibility to detect supported apps and show blocking prompts.',
          preview: const _PermissionGuidePreview(
            firstStep: 'Find Tempus in Downloaded apps',
            firstCard: _PermissionListMock(
              sectionLabel: 'Downloaded apps',
              appName: 'Tempus',
              statusLabel: 'Tap to configure',
            ),
            secondStep: 'Turn on Use Tempus',
            secondCard: _PermissionToggleMock(toggleLabel: 'Tempus Guard'),
          ),
          buttonLabel: 'Open Accessibility Settings',
          onPressed: widget.onOpenAccessibilitySettings,
        );
      case OnboardingStep.accessibilityGoodStuff:
        return _OnboardingContent(
          title: 'Good Stuff',
          subtitle: 'Accessibility is on. Tempus can step in earlier.',
          preview: const _CenteredSuccessIcon(icon: Icons.verified_rounded),
          buttonLabel: 'Next',
          onPressed: widget.onContinueFromAccessibilitySuccess,
          centerVertically: true,
          centerText: true,
        );
      case OnboardingStep.trackDays:
        return _OnboardingContent(
          title: 'Tempus keeps track for you.',
          subtitle:
              'Your scrolling-free days are tracked automatically, so you can see momentum build over time.',
          preview: const _ScrollFreeDaysPreview(),
          buttonLabel: 'Next',
          onPressed: widget.onContinueFromTracking,
          centerVertically: true,
        );
      case OnboardingStep.enableUsageAccess:
        return _OnboardingContent(
          title: 'Usage Access',
          subtitle:
              'Usage access lets Tempus measure time limits and track how long apps are open.',
          preview: const _PermissionGuidePreview(
            firstStep: 'Open Tempus in the Usage access list',
            firstCard: _PermissionListMock(
              sectionLabel: 'Apps with access controls',
              appName: 'Tempus',
              statusLabel: 'Tap to allow',
            ),
            secondStep: 'Turn on Permit usage access',
            secondCard: _PermissionToggleMock(toggleLabel: 'Tempus Guard'),
          ),
          buttonLabel: 'Open Usage Access Settings',
          onPressed: widget.onOpenUsageAccessSettings,
        );
      case OnboardingStep.allDone:
        return _OnboardingContent(
          title: 'All Done',
          subtitle: 'Tempus is ready.',
          preview: const _CenteredSuccessIcon(icon: Icons.done_all_rounded),
          buttonLabel: 'Next',
          onPressed: widget.onFinish,
          centerVertically: true,
          centerText: true,
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
    this.centerVertically = false,
    this.centerText = false,
  });

  final String title;
  final String? subtitle;
  final Widget? preview;
  final String? description;
  final bool centerVertically;
  final bool centerText;
  final String buttonLabel;
  final VoidCallback onPressed;
}

class _CenteredSuccessIcon extends StatelessWidget {
  const _CenteredSuccessIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(icon, size: 74, color: brand));
  }
}

class _PermissionGuidePreview extends StatelessWidget {
  const _PermissionGuidePreview({
    required this.firstStep,
    required this.firstCard,
    required this.secondStep,
    required this.secondCard,
  });

  final String firstStep;
  final Widget firstCard;
  final String secondStep;
  final Widget secondCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _PermissionInstructionSection(label: '1. $firstStep', child: firstCard),
        const SizedBox(height: 46),
        _PermissionInstructionSection(
          label: '2. $secondStep',
          child: secondCard,
        ),
      ],
    );
  }
}

class _PermissionInstructionSection extends StatelessWidget {
  const _PermissionInstructionSection({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _PermissionListMock extends StatelessWidget {
  const _PermissionListMock({
    required this.sectionLabel,
    required this.appName,
    required this.statusLabel,
  });

  final String sectionLabel;
  final String appName;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return _PermissionPhoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: brand,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionToggleMock extends StatelessWidget {
  const _PermissionToggleMock({required this.toggleLabel});

  final String toggleLabel;

  @override
  Widget build(BuildContext context) {
    return _PermissionPhoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    toggleLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  width: 54,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: brand,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPhoneCard extends StatelessWidget {
  const _PermissionPhoneCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _HowItWorksCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: child,
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
