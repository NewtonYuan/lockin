import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';
import 'sticky_header.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.trackerMonth,
    required this.usageSegments,
    required this.blockSettings,
    required this.dailyTimeLimits,
    required this.canShowPreviousMonth,
    required this.canShowNextMonth,
    required this.onOpenBlockedShorts,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime trackerMonth;
  final List<AppUsageSegment> usageSegments;
  final Map<String, bool> blockSettings;
  final Map<String, int?> dailyTimeLimits;
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
                onPressed: () {},
                icon: SvgPicture.asset(
                  'assets/icons/notifications.svg',
                  width: 26,
                  height: 26,
                  colorFilter: const ColorFilter.mode(
                    appText,
                    BlendMode.srcIn,
                  ),
                ),
                splashRadius: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
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
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HomeShortcutCardsRow(
                  onOpenBlockedShorts: onOpenBlockedShorts,
                  blockSettings: blockSettings,
                  dailyTimeLimits: dailyTimeLimits,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DailyTrackerCard(
                  month: trackerMonth,
                  canShowPreviousMonth: canShowPreviousMonth,
                  canShowNextMonth: canShowNextMonth,
                  onPreviousMonth: onPreviousMonth,
                  onNextMonth: onNextMonth,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _StreakSummaryCard(),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DailyTrackerCard extends StatelessWidget {
  const _DailyTrackerCard({
    required this.month,
    required this.canShowPreviousMonth,
    required this.canShowNextMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final bool canShowPreviousMonth;
  final bool canShowNextMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  static const _monthNames = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _trackerCellSize = 27;
  static const double _trackerColumnGap = 16;
  static const double _trackerWidth =
      (_trackerCellSize * 7) + (_trackerColumnGap * 6);

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: appText,
      fontWeight: FontWeight.w700,
    );
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyDays = firstDayOfMonth.weekday - 1;
    final totalSlots = leadingEmptyDays + daysInMonth;
    final trailingEmptyDays = (7 - (totalSlots % 7)) % 7;
    final allSlots = List<int?>.filled(leadingEmptyDays, null, growable: true)
      ..addAll(List<int?>.generate(daysInMonth, (index) => index + 1))
      ..addAll(List<int?>.filled(trailingEmptyDays, null));
    final weekRows = List<List<int?>>.generate(
      allSlots.length ~/ 7,
      (index) => allSlots.sublist(index * 7, (index * 7) + 7),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scrolling-Free Days', style: titleStyle),
          const SizedBox(height: 14),
          Row(
            children: [
              _MonthArrowButton(
                icon: Icons.chevron_left_rounded,
                isEnabled: canShowPreviousMonth,
                onTap: onPreviousMonth,
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _MonthArrowButton(
                icon: Icons.chevron_right_rounded,
                isEnabled: canShowNextMonth,
                onTap: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: _trackerWidth,
              child: Row(
                children: List.generate(_weekdayLabels.length, (index) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) SizedBox(width: _trackerColumnGap),
                      SizedBox(
                        width: _trackerCellSize,
                        child: Center(
                          child: Text(
                            _weekdayLabels[index],
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: appMutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: weekRows
                .map(
                  (week) => Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TrackerWeekRow(
                        days: week,
                        month: month,
                        cellSize: _trackerCellSize,
                        columnGap: _trackerColumnGap,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ScrollMinutesRing extends StatelessWidget {
  const _ScrollMinutesRing({required this.segments});

  final List<AppUsageSegment> segments;

  int get _totalMinutes {
    return segments.fold<int>(
      0,
      (sum, segment) => sum + segment.minutes,
    );
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
  return '$hours hrs, $minutes mins';
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.assetPath,
    this.size = 18,
  });

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover),
    );
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: trailing,
                ),
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
        const _AppIcon(
          assetPath: 'assets/icons/instagram.png',
          size: 24,
        ),
      );
    }
    if (showYouTube) {
      if (icons.isNotEmpty) {
        icons.add(const SizedBox(width: 6));
      }
      icons.add(
        const _AppIcon(
          assetPath: 'assets/icons/youtube.png',
          size: 24,
        ),
      );
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }
}

class _HomeShortcutCardsRow extends StatelessWidget {
  const _HomeShortcutCardsRow({
    required this.onOpenBlockedShorts,
    required this.blockSettings,
    required this.dailyTimeLimits,
  });

  final VoidCallback onOpenBlockedShorts;
  final Map<String, bool> blockSettings;
  final Map<String, int?> dailyTimeLimits;

  static const _gap = 12.0;
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
          _measureTitleHeight('Restricted Apps', titleStyle, titleWidth),
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
                  title: 'Restricted Apps',
                  titleStyle: titleStyle,
                  onTap: onOpenBlockedShorts,
                  trailing: _ResponsiveRestrictedAppsTrail(
                    dailyTimeLimits: dailyTimeLimits,
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
  const _StreakSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: const [
            Expanded(
              child: _StreakSummaryItem(
                label: 'Current Streak',
                value: '12 Days',
              ),
            ),
            Expanded(
              child: _StreakSummaryItem(
                label: 'Longest Streak',
                value: '28 Days',
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
            colorFilter: const ColorFilter.mode(
              appText,
              BlendMode.srcIn,
            ),
          )
        else
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: _streakValueSpans(
                context,
                value ?? '',
              ),
            ),
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

  factory AppUsageSegment.fromJson(Map<String, Object> json) {
    return AppUsageSegment(
      appName: json['appName']! as String,
      minutes: json['minutes']! as int,
      color: _colorFromHex(json['color']! as String),
    );
  }

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
      _drawSegmentLabel(
        canvas: canvas,
        center: center,
        angle: startAngle + (sweepAngle / 2),
        segment: segment,
      );
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

Color _colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

class _RestrictedAppsTrail extends StatelessWidget {
  const _RestrictedAppsTrail({
    required this.visibleIcons,
    required this.overflowCount,
  }) : assetPaths = _icons;

  const _RestrictedAppsTrail.fromIcons({
    required this.assetPaths,
    required this.visibleIcons,
    required this.overflowCount,
  });

  final List<String> assetPaths;
  final int visibleIcons;
  final int overflowCount;

  static const _icons = [
    'assets/icons/instagram.png',
    'assets/icons/youtube.png',
    'assets/icons/tiktok.png',
    'assets/icons/snapchat.png',
    'assets/icons/facebook.png',
  ];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < visibleIcons; index++) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 6));
      }
      children.add(
        _AppIcon(
          assetPath: assetPaths[index],
          size: 24,
        ),
      );
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
    required this.dailyTimeLimits,
  });

  final Map<String, int?> dailyTimeLimits;

  static const _appIcons = [
    _RestrictedAppIconData(
      settingKey: 'instagram_app',
      assetPath: 'assets/icons/instagram.png',
    ),
    _RestrictedAppIconData(
      settingKey: 'youtube_app',
      assetPath: 'assets/icons/youtube.png',
    ),
    _RestrictedAppIconData(
      settingKey: 'tiktok_app',
      assetPath: 'assets/icons/tiktok.png',
    ),
    _RestrictedAppIconData(
      settingKey: 'snapchat_app',
      assetPath: 'assets/icons/snapchat.png',
    ),
    _RestrictedAppIconData(
      settingKey: 'facebook_app',
      assetPath: 'assets/icons/facebook.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleAppIcons = _appIcons
        .where((app) => dailyTimeLimits[app.settingKey] != null)
        .toList();

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
            child: _RestrictedAppsTrail.fromIcons(
              assetPaths: visibleAppIcons
                  .map((app) => app.assetPath)
                  .take(visibleIcons)
                  .toList(),
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
    required this.assetPath,
  });

  final String settingKey;
  final String assetPath;
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled
              ? appSurfaceStrong
              : appSurfaceStrong.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isEnabled ? appText : appMutedText.withValues(alpha: 0.45),
          size: 22,
        ),
      ),
    );
  }
}

class _TrackerDayCell extends StatelessWidget {
  const _TrackerDayCell({
    required this.day,
    required this.state,
    required this.size,
  });

  final int? day;
  final _TrackerDayState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return SizedBox(
        width: size,
        height: size,
      );
    }

    final isBlocked = state == _TrackerDayState.blocked;
    final backgroundColor = switch (state) {
      _TrackerDayState.blocked => brand,
      _TrackerDayState.none => appSurfaceStrong,
      _TrackerDayState.empty => Colors.transparent,
    };
    final textColor = isBlocked ? Colors.white : appText;

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: state == _TrackerDayState.none
                ? appBorder
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            '$day',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

enum _TrackerDayState { empty, none, blocked }

class _TrackerWeekRow extends StatelessWidget {
  const _TrackerWeekRow({
    required this.days,
    required this.month,
    required this.cellSize,
    required this.columnGap,
  });

  final List<int?> days;
  final DateTime month;
  final double cellSize;
  final double columnGap;

  @override
  Widget build(BuildContext context) {
    final states = days
        .map(
          (day) => day == null
              ? _TrackerDayState.empty
              : _sampleDayState(month, day),
        )
        .toList();

    return SizedBox(
      width: (cellSize * 7) + (columnGap * 6),
      height: cellSize,
      child: Stack(
        children: [
          for (var index = 0; index < days.length - 1; index++)
            if (days[index] != null && days[index + 1] != null)
              Positioned(
                left: ((cellSize + columnGap) * index) + cellSize,
                top: (cellSize / 2) - 0.5,
                child: Container(
                  width: columnGap,
                  height: 2,
                  color:
                      states[index] == _TrackerDayState.blocked &&
                          states[index + 1] == _TrackerDayState.blocked
                      ? brand
                      : appBorder,
                ),
              ),
          Row(
            children: List.generate(days.length, (index) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0) SizedBox(width: columnGap),
                  _TrackerDayCell(
                    day: days[index],
                    state: states[index],
                    size: cellSize,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

_TrackerDayState _sampleDayState(DateTime month, int day) {
  final value = (month.year * 100) + (month.month * 31) + day;
  if (value % 2 == 0 || value % 5 == 0) {
    return _TrackerDayState.blocked;
  }
  return _TrackerDayState.none;
}
