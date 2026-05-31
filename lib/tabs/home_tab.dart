import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';
import '../widgets/days_tracker_calendar.dart';
import 'block_tab.dart';
import 'sticky_header.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.trackerMonth,
    required this.usageSegments,
    required this.scrollDayStatuses,
    required this.firstTrackableDate,
    required this.blockSettings,
    required this.dailyTimeLimits,
    required this.customTrackedApps,
    required this.canShowPreviousMonth,
    required this.canShowNextMonth,
    required this.onOpenBlockedShorts,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime trackerMonth;
  final List<AppUsageSegment> usageSegments;
  final Map<String, ScrollDayStatus> scrollDayStatuses;
  final DateTime firstTrackableDate;
  final Map<String, bool> blockSettings;
  final Map<String, int?> dailyTimeLimits;
  final List<CustomTrackedApp> customTrackedApps;
  final bool canShowPreviousMonth;
  final bool canShowNextMonth;
  final VoidCallback onOpenBlockedShorts;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        StickyHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StickyTitleHeader(
              title: 'Overview',
              centerTitle: false,
              trailing: IconButton(
                onPressed: () => _showNotificationsSheet(context),
                icon: SvgPicture.asset(
                  'assets/icons/notifications.svg',
                  width: 26,
                  height: 26,
                  colorFilter: const ColorFilter.mode(appText, BlendMode.srcIn),
                ),
                splashRadius: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: _ScrollMinutesRing(segments: usageSegments),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HomeShortcutCardsRow(
                  onOpenBlockedShorts: onOpenBlockedShorts,
                  blockSettings: blockSettings,
                  dailyTimeLimits: dailyTimeLimits,
                  customTrackedApps: customTrackedApps,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DailyTrackerCard(
                  month: trackerMonth,
                  scrollDayStatuses: scrollDayStatuses,
                  firstTrackableDate: firstTrackableDate,
                  canShowPreviousMonth: canShowPreviousMonth,
                  canShowNextMonth: canShowNextMonth,
                  onPreviousMonth: onPreviousMonth,
                  onNextMonth: onNextMonth,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StreakSummaryCard(
                  scrollDayStatuses: scrollDayStatuses,
                  firstTrackableDate: firstTrackableDate,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _showNotificationsSheet(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _NotificationsDropdown();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}

class _DailyTrackerCard extends StatelessWidget {
  const _DailyTrackerCard({
    required this.month,
    required this.scrollDayStatuses,
    required this.firstTrackableDate,
    required this.canShowPreviousMonth,
    required this.canShowNextMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final Map<String, ScrollDayStatus> scrollDayStatuses;
  final DateTime firstTrackableDate;
  final bool canShowPreviousMonth;
  final bool canShowNextMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return DaysTrackerCalendarCard(
      title: 'Distraction-Free Days',
      tooltipMessage:
          'No Scroll: 0-5 min of Shorts/Reels after bypass and no tracked '
          'app limit overage.\n'
          'Partial: 6-20 min of Shorts/Reels after bypass, or up to 20 min '
          'combined tracked app limit overage.\n'
          'Scrolled: over 20 min of Shorts/Reels after bypass, or over 20 '
          'min combined tracked app limit overage.',
      month: month,
      dayStatuses: scrollDayStatuses,
      firstTrackableDate: firstTrackableDate,
      canShowPreviousMonth: canShowPreviousMonth,
      canShowNextMonth: canShowNextMonth,
      onPreviousMonth: onPreviousMonth,
      onNextMonth: onNextMonth,
      padding: const EdgeInsets.all(12),
    );
  }
}

class _ScrollMinutesRing extends StatelessWidget {
  const _ScrollMinutesRing({required this.segments});

  final List<AppUsageSegment> segments;

  int get _totalMinutes {
    return segments.fold<int>(0, (sum, segment) => sum + segment.minutes);
  }

  @override
  Widget build(BuildContext context) {
    final hasActivity = _totalMinutes > 0;

    return Column(
      children: [
        SizedBox(
          width: 270,
          height: 270,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: _SegmentedRingPainter(segments: segments),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasActivity
                        ? _formatTodayDuration(_totalMinutes)
                        : 'No activity',
                    style: const TextStyle(
                      color: appText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TODAY',
                    style: const TextStyle(
                      color: appMutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 170,
                child: Tooltip(
                  richMessage: WidgetSpan(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(text: 'Only counting apps listed in '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: SizedBox(
                              width: 13,
                              height: 13,
                              child: _TooltipBlockIcon(),
                            ),
                          ),
                          TextSpan(text: ' Block'),
                        ],
                      ),
                    ),
                  ),
                  triggerMode: TooltipTriggerMode.tap,
                  waitDuration: Duration.zero,
                  showDuration: Duration(seconds: 3),
                  preferBelow: true,
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  decoration: BoxDecoration(
                    color: appText.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/help.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(brand, BlendMode.srcIn),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatTodayDuration(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return '$minutes mins';
  }
  return '$hours hrs, $minutes mins';
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.assetPath, this.size = 18});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _AssetIcon(assetPath: assetPath, fit: BoxFit.fill),
      ),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon({
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (assetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
      );
    }
    return Image.asset(assetPath, width: width, height: height, fit: fit);
  }
}

class _HomeShortcutCard extends StatelessWidget {
  const _HomeShortcutCard({
    required this.title,
    required this.trailing,
    required this.onTap,
    this.titleStyle,
  });

  final String title;
  final Widget trailing;
  final VoidCallback onTap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: brand.withValues(alpha: 0.18),
          highlightColor: appText.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            titleStyle ??
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: appText,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: appText,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedShortsTrail extends StatelessWidget {
  const _BlockedShortsTrail({
    required this.showInstagram,
    required this.showYouTube,
  });

  final bool showInstagram;
  final bool showYouTube;

  @override
  Widget build(BuildContext context) {
    final icons = <Widget>[];
    if (showInstagram) {
      icons.add(
        const _AppIcon(assetPath: 'assets/apps/instagram.svg', size: 24),
      );
    }
    if (showYouTube) {
      if (icons.isNotEmpty) {
        icons.add(const SizedBox(width: 6));
      }
      icons.add(const _AppIcon(assetPath: 'assets/apps/youtube.svg', size: 24));
    }

    if (icons.isEmpty) {
      return Text(
        'Tap to Configure',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: appMutedText,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
}

class _HomeShortcutCardsRow extends StatelessWidget {
  const _HomeShortcutCardsRow({
    required this.onOpenBlockedShorts,
    required this.blockSettings,
    required this.dailyTimeLimits,
    required this.customTrackedApps,
  });

  final VoidCallback onOpenBlockedShorts;
  final Map<String, bool> blockSettings;
  final Map<String, int?> dailyTimeLimits;
  final List<CustomTrackedApp> customTrackedApps;

  static const _gap = 8.0;
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 12.0;
  static const _titleIconGap = 4.0;
  static const _chevronWidth = 20.0;
  static const _titleTrailingGap = 16.0;
  static const _trailingHeight = 24.0;
  static const _heightBuffer = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - _gap) / 2;
        final titleWidth =
            cardWidth -
            (_horizontalPadding * 2) -
            _titleIconGap -
            _chevronWidth;
        final titleStyle =
            Theme.of(context).textTheme.titleMedium?.copyWith(
              color: appText,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ) ??
            const TextStyle(
              color: appText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.08,
            );
        final titleHeight = math.max(
          _measureTitleHeight('Blocked Shorts', titleStyle, titleWidth),
          _measureTitleHeight('Restricted', titleStyle, titleWidth),
        );
        final cardHeight =
            (_verticalPadding * 2) +
            titleHeight +
            _titleTrailingGap +
            _trailingHeight +
            _heightBuffer;

        return SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HomeShortcutCard(
                  title: 'Blocked Shorts',
                  titleStyle: titleStyle,
                  onTap: onOpenBlockedShorts,
                  trailing: _BlockedShortsTrail(
                    showInstagram: blockSettings['instagram_reels'] ?? false,
                    showYouTube: blockSettings['youtube_shorts'] ?? false,
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _HomeShortcutCard(
                  title: 'Restricted',
                  titleStyle: titleStyle,
                  onTap: onOpenBlockedShorts,
                  trailing: _ResponsiveRestrictedAppsTrail(
                    blockSettings: blockSettings,
                    dailyTimeLimits: dailyTimeLimits,
                    customTrackedApps: customTrackedApps,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _measureTitleHeight(String text, TextStyle style, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return textPainter.height;
  }
}

class _StreakSummaryCard extends StatelessWidget {
  const _StreakSummaryCard({
    required this.scrollDayStatuses,
    required this.firstTrackableDate,
  });

  final Map<String, ScrollDayStatus> scrollDayStatuses;
  final DateTime firstTrackableDate;

  @override
  Widget build(BuildContext context) {
    final streaks = _calculateStreaks(
      scrollDayStatuses: scrollDayStatuses,
      firstTrackableDate: firstTrackableDate,
    );

    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _StreakSummaryItem(
                label: 'Current',
                value: '${streaks.current} Days',
              ),
            ),
            Expanded(
              child: _StreakSummaryItem(
                label: 'Longest',
                value: '${streaks.longest} Days',
              ),
            ),
            Expanded(
              child: _StreakSummaryItem(
                label: 'Share',
                iconAssetPath: 'assets/icons/share.svg',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({int current, int longest}) _calculateStreaks({
  required Map<String, ScrollDayStatus> scrollDayStatuses,
  required DateTime firstTrackableDate,
}) {
  final today = DateTime.now();
  final firstDate = DateTime(
    firstTrackableDate.year,
    firstTrackableDate.month,
    firstTrackableDate.day,
  );
  final todayDate = DateTime(today.year, today.month, today.day);

  int current = 0;
  var cursor = todayDate;
  while (!cursor.isBefore(firstDate)) {
    final status =
        scrollDayStatuses[calendarDateKey(cursor)] ?? ScrollDayStatus.scrolled;
    if (status != ScrollDayStatus.noScroll) break;
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  int longest = 0;
  int running = 0;
  for (
    var date = firstDate;
    !date.isAfter(todayDate);
    date = date.add(const Duration(days: 1))
  ) {
    final status =
        scrollDayStatuses[calendarDateKey(date)] ?? ScrollDayStatus.scrolled;
    if (status == ScrollDayStatus.noScroll) {
      running++;
      if (running > longest) {
        longest = running;
      }
    } else {
      running = 0;
    }
  }

  return (current: current, longest: longest);
}

class _NotificationsDropdown extends StatelessWidget {
  const _NotificationsDropdown();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topOffset = MediaQuery.paddingOf(context).top + 78;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: topOffset,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 300,
                constraints: const BoxConstraints(minHeight: 220),
                decoration: BoxDecoration(
                  color: appBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: appBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: textTheme.titleLarge?.copyWith(
                        color: appText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: appSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/notifications.svg',
                            width: 42,
                            height: 42,
                            colorFilter: const ColorFilter.mode(
                              appMutedText,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications yet.',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              color: appText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Updates and reminders will show up here.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: appMutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakSummaryItem extends StatelessWidget {
  const _StreakSummaryItem({
    required this.label,
    this.value,
    this.iconAssetPath,
  });

  final String label;
  final String? value;
  final String? iconAssetPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconAssetPath != null)
          SvgPicture.asset(
            iconAssetPath!,
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(appText, BlendMode.srcIn),
          )
        else
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: _streakValueSpans(context, value ?? '')),
          ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: appMutedText,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

List<InlineSpan> _streakValueSpans(BuildContext context, String value) {
  final parts = value.split(' ');
  final number = parts.isEmpty ? value : parts.first;
  final unit = parts.length > 1 ? parts.sublist(1).join(' ') : '';

  return [
    TextSpan(
      text: number,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: brand,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
      ),
    ),
    if (unit.isNotEmpty)
      TextSpan(
        text: ' $unit',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: appText,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
  ];
}

class AppUsageSegment {
  const AppUsageSegment({
    required this.appName,
    required this.minutes,
    required this.color,
  });

  final String appName;
  final int minutes;
  final Color color;
}

class _SegmentedRingPainter extends CustomPainter {
  const _SegmentedRingPainter({required this.segments});

  final List<AppUsageSegment> segments;
  static const _strokeWidth = 11.0;
  static const _segmentGap = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 90.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final backgroundPaint = Paint()
      ..color = brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final total = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.minutes,
    );
    if (total <= 0) {
      canvas.drawCircle(center, radius, backgroundPaint);
      return;
    }

    backgroundPaint.color = appSurfaceStrong;
    canvas.drawCircle(center, radius, backgroundPaint);

    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.butt;
    var startAngle = -math.pi / 2;
    final gap = segments.length > 1 ? _segmentGap : 0.0;

    for (final segment in segments) {
      final sweepAngle = (segment.minutes / total) * math.pi * 2;
      final visibleSweep = math.max(0.0, sweepAngle - gap);
      final visibleStart = startAngle + (gap / 2);
      segmentPaint.color = segment.color;
      canvas.drawArc(rect, visibleStart, visibleSweep, false, segmentPaint);
      if (segments.length > 1 && segment.appName.isNotEmpty) {
        _drawSegmentLabel(
          canvas: canvas,
          center: center,
          angle: startAngle + (sweepAngle / 2),
          segment: segment,
        );
      }
      startAngle += sweepAngle;
    }
  }

  void _drawSegmentLabel({
    required Canvas canvas,
    required Offset center,
    required double angle,
    required AppUsageSegment segment,
  }) {
    const maxLabelWidth = 72.0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: segment.appName,
        style: const TextStyle(
          color: appText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxLabelWidth);
    final horizontalBias = math.cos(angle).abs();
    final verticalBias = math.sin(angle).abs();
    final labelRadius =
        102.0 +
        ((textPainter.width / 2) * horizontalBias) +
        ((textPainter.height / 2) * verticalBias) +
        5.0;
    final labelCenter = Offset(
      center.dx + math.cos(angle) * labelRadius,
      center.dy + math.sin(angle) * labelRadius,
    );

    final offset = Offset(
      labelCenter.dx - (textPainter.width / 2),
      labelCenter.dy - (textPainter.height / 2),
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter oldDelegate) {
    return segments != oldDelegate.segments;
  }
}

class _RestrictedAppsTrail extends StatelessWidget {
  const _RestrictedAppsTrail({
    required this.visibleApps,
    required this.visibleIcons,
    required this.overflowCount,
  });

  final List<_RestrictedAppVisual> visibleApps;
  final int visibleIcons;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < visibleIcons; index++) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 6));
      }
      children.add(_RestrictedAppIcon(visual: visibleApps[index]));
    }

    if (overflowCount > 0) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 6));
      }
      children.add(
        Text(
          '+$overflowCount',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: appMutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _ResponsiveRestrictedAppsTrail extends StatelessWidget {
  const _ResponsiveRestrictedAppsTrail({
    required this.blockSettings,
    required this.dailyTimeLimits,
    required this.customTrackedApps,
  });

  final Map<String, bool> blockSettings;
  final Map<String, int?> dailyTimeLimits;
  final List<CustomTrackedApp> customTrackedApps;

  static const _appIcons = [
    _RestrictedAppIconData(
      settingKey: 'instagram_app',
      pauseOnOpenKey: 'instagram_pause_on_open',
      assetPath: 'assets/apps/instagram.svg',
    ),
    _RestrictedAppIconData(
      settingKey: 'youtube_app',
      pauseOnOpenKey: 'youtube_pause_on_open',
      assetPath: 'assets/apps/youtube.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleAppIcons = <_RestrictedAppVisual>[
      ..._appIcons
          .where((app) {
            return dailyTimeLimits[app.settingKey] != null ||
                (blockSettings[app.pauseOnOpenKey] ?? false);
          })
          .map((app) => _RestrictedAppVisual.asset(app.assetPath)),
      ...customTrackedApps
          .where((app) {
            return dailyTimeLimits[app.settingKey] != null ||
                (blockSettings[customTrackedAppPauseOnOpenSettingKey(
                      app.packageName,
                    )] ??
                    false);
          })
          .map((app) => _RestrictedAppVisual.memory(app.iconBytes)),
    ];

    if (visibleAppIcons.isEmpty) {
      return Text(
        'Tap to Configure',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: appMutedText,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconCount = visibleAppIcons.length;
        const iconSize = 24.0;
        const iconGap = 6.0;
        const overflowWidth = 28.0;

        var visibleIcons = iconCount;
        var overflowCount = 0;
        while (visibleIcons > 1) {
          final needsOverflow = visibleIcons < iconCount;
          final requiredWidth =
              (visibleIcons * iconSize) +
              ((visibleIcons - 1) * iconGap) +
              (needsOverflow ? iconGap + overflowWidth : 0);
          if (requiredWidth <= constraints.maxWidth) {
            break;
          }
          visibleIcons--;
        }

        if (visibleIcons < iconCount) {
          overflowCount = iconCount - visibleIcons;
        }

        return SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _RestrictedAppsTrail(
              visibleApps: visibleAppIcons.take(visibleIcons).toList(),
              visibleIcons: visibleIcons,
              overflowCount: overflowCount,
            ),
          ),
        );
      },
    );
  }
}

class _RestrictedAppIconData {
  const _RestrictedAppIconData({
    required this.settingKey,
    required this.pauseOnOpenKey,
    required this.assetPath,
  });

  final String settingKey;
  final String pauseOnOpenKey;
  final String assetPath;
}

class _RestrictedAppVisual {
  const _RestrictedAppVisual.asset(this.assetPath) : iconBytes = null;

  const _RestrictedAppVisual.memory(this.iconBytes) : assetPath = null;

  final String? assetPath;
  final Uint8List? iconBytes;
}

class _RestrictedAppIcon extends StatelessWidget {
  const _RestrictedAppIcon({required this.visual});

  final _RestrictedAppVisual visual;

  @override
  Widget build(BuildContext context) {
    if (visual.assetPath != null) {
      return _AppIcon(assetPath: visual.assetPath!, size: 24);
    }

    return SizedBox(
      width: 24,
      height: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: visual.iconBytes != null
            ? Image.memory(visual.iconBytes!, fit: BoxFit.cover)
            : Container(color: appSurfaceStrong),
      ),
    );
  }
}

class _TooltipBlockIcon extends StatelessWidget {
  const _TooltipBlockIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/block.svg',
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}
