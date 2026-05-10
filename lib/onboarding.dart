import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';

enum OnboardingStep {
  intro,
  enableAccessibility,
  accessibilityEnabled,
  enableUsageAccess,
  allDone,
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.step,
    required this.onGetStarted,
    required this.onOpenAccessibilitySettings,
    required this.onOpenUsageAccessSettings,
    required this.onNextFromAccessibilityEnabled,
    required this.onFinish,
  });

  final OnboardingStep step;
  final VoidCallback onGetStarted;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenUsageAccessSettings;
  final VoidCallback onNextFromAccessibilityEnabled;
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
              _ProgressBars(step: widget.step),
              const SizedBox(height: 36),
              Expanded(
                child: isIntro
                    ? _buildIntroContent()
                    : _buildDefaultContent(content),
              ),
              _fadeItem(
                2,
                FilledButton(
                  onPressed: content.onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildDefaultContent(_OnboardingContent content) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(content.icon, size: 50, color: brand),
        ),
        const SizedBox(height: 28),
        Text(
          content.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          content.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            height: 1.45,
            color: Color(0xFF5F6B7A),
          ),
        ),
      ],
    );
  }

  _OnboardingContent _contentForStep() {
    switch (widget.step) {
      case OnboardingStep.intro:
        return _OnboardingContent(
          icon: Icons.hourglass_top_rounded,
          title: 'Get Started',
          description: '',
          buttonLabel: 'Get Started',
          onPressed: widget.onGetStarted,
        );
      case OnboardingStep.enableAccessibility:
        return _OnboardingContent(
          icon: Icons.accessibility_new_rounded,
          title: 'Enable Accessibility',
          description:
              'Tempus needs Accessibility to detect supported apps and show blocking prompts.',
          buttonLabel: 'Open Accessibility Settings',
          onPressed: widget.onOpenAccessibilitySettings,
        );
      case OnboardingStep.accessibilityEnabled:
        return _OnboardingContent(
          icon: Icons.check_rounded,
          title: 'Great Job',
          description: 'Accessibility is enabled. Next, enable usage access.',
          buttonLabel: 'Next',
          onPressed: widget.onNextFromAccessibilityEnabled,
        );
      case OnboardingStep.enableUsageAccess:
        return _OnboardingContent(
          icon: Icons.query_stats_rounded,
          title: 'Enable Usage Access',
          description:
              'Usage access lets Tempus measure time limits and track how long apps are open.',
          buttonLabel: 'Open Usage Access Settings',
          onPressed: widget.onOpenUsageAccessSettings,
        );
      case OnboardingStep.allDone:
        return _OnboardingContent(
          icon: Icons.done_all_rounded,
          title: 'All Done',
          description:
              'Tempus is set up and ready. You can start using the app now.',
          buttonLabel: 'Next',
          onPressed: widget.onFinish,
        );
    }
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final currentIndex = switch (step) {
      OnboardingStep.intro => 0,
      OnboardingStep.enableAccessibility => 1,
      OnboardingStep.accessibilityEnabled => 2,
      OnboardingStep.enableUsageAccess => 3,
      OnboardingStep.allDone => 4,
    };

    return Row(
      children: List.generate(5, (index) {
        final isActive = index <= currentIndex;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
            decoration: BoxDecoration(
              color: isActive ? brand : const Color(0xFFD7DEE7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
}
