import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';

enum ScrollDayStatus { noScroll, partialScroll, scrolled }

class DaysTrackerCalendarCard extends StatelessWidget {
  const DaysTrackerCalendarCard({
    super.key,
    required this.title,
    required this.month,
    required this.dayStatuses,
    required this.firstTrackableDate,
    this.canShowPreviousMonth = false,
    this.canShowNextMonth = false,
    this.onPreviousMonth,
    this.onNextMonth,
    this.cellSize = 27,
    this.columnGap = 16,
    this.padding = const EdgeInsets.all(12),
  });

  final String title;
  final DateTime month;
  final Map<String, ScrollDayStatus> dayStatuses;
  final DateTime firstTrackableDate;
  final bool canShowPreviousMonth;
  final bool canShowNextMonth;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final double cellSize;
  final double columnGap;
  final EdgeInsetsGeometry padding;

  static const monthNames = [
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

  static const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: appText,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 14),
          Row(
            children: [
              _MonthArrowButton(
                icon: Icons.chevron_left_rounded,
                isEnabled: canShowPreviousMonth,
                onTap: onPreviousMonth,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${monthNames[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: titleStyle,
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
          _CalendarMonthBody(
            month: month,
            dayStatuses: dayStatuses,
            firstTrackableDate: firstTrackableDate,
            cellSize: cellSize,
            columnGap: columnGap,
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthBody extends StatelessWidget {
  const _CalendarMonthBody({
    required this.month,
    required this.dayStatuses,
    required this.firstTrackableDate,
    required this.cellSize,
    required this.columnGap,
  });

  final DateTime month;
  final Map<String, ScrollDayStatus> dayStatuses;
  final DateTime firstTrackableDate;
  final double cellSize;
  final double columnGap;

  @override
  Widget build(BuildContext context) {
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
    final trackerWidth = (cellSize * 7) + (columnGap * 6);

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: trackerWidth,
            child: Row(
              children: List.generate(
                DaysTrackerCalendarCard.weekdayLabels.length,
                (index) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) SizedBox(width: columnGap),
                      SizedBox(
                        width: cellSize,
                        child: Center(
                          child: Text(
                            DaysTrackerCalendarCard.weekdayLabels[index],
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
                },
              ),
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
                      dayStatuses: dayStatuses,
                      firstTrackableDate: firstTrackableDate,
                      cellSize: cellSize,
                      columnGap: columnGap,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback? onTap;

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
      return SizedBox(width: size, height: size);
    }

    final isBlocked = state == _TrackerDayState.blocked;
    final textColor = isBlocked ? Colors.white : appText;
    final decoration = switch (state) {
      _TrackerDayState.blocked => BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(8),
      ),
      _TrackerDayState.partial => BoxDecoration(
        color: brand.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appBorder),
      ),
      _TrackerDayState.none => BoxDecoration(
        color: appSurfaceStrong,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appBorder),
      ),
      _TrackerDayState.installDay => BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(8),
      ),
      _TrackerDayState.disabled => BoxDecoration(
        color: appSurfaceStrong.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appBorder.withValues(alpha: 0.35)),
      ),
      _TrackerDayState.empty => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
    };

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: decoration,
        child: Center(
          child: state == _TrackerDayState.installDay
              ? SvgPicture.asset(
                  'assets/icons/install_day_star.svg',
                  width: size * 0.98,
                  height: size * 0.98,
                )
              : Text(
                  '$day',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: state == _TrackerDayState.disabled
                        ? appMutedText.withValues(alpha: 0.4)
                        : textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

enum _TrackerDayState { empty, none, partial, blocked, installDay, disabled }

class _TrackerWeekRow extends StatelessWidget {
  const _TrackerWeekRow({
    required this.days,
    required this.month,
    required this.dayStatuses,
    required this.firstTrackableDate,
    required this.cellSize,
    required this.columnGap,
  });

  final List<int?> days;
  final DateTime month;
  final Map<String, ScrollDayStatus> dayStatuses;
  final DateTime firstTrackableDate;
  final double cellSize;
  final double columnGap;

  @override
  Widget build(BuildContext context) {
    final states = days
        .map(
          (day) => day == null
              ? _TrackerDayState.empty
              : _calendarDayState(
                  month: month,
                  day: day,
                  firstTrackableDate: firstTrackableDate,
                  dayStatuses: dayStatuses,
                ),
        )
        .toList();

    return SizedBox(
      width: (cellSize * 7) + (columnGap * 6),
      height: cellSize,
      child: Stack(
        children: [
          for (var index = 0; index < days.length - 1; index++)
            if (_shouldShowConnector(
              leftDay: days[index],
              rightDay: days[index + 1],
              month: month,
              firstTrackableDate: firstTrackableDate,
            ))
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

bool _shouldShowConnector({
  required int? leftDay,
  required int? rightDay,
  required DateTime month,
  required DateTime firstTrackableDate,
}) {
  if (leftDay == null || rightDay == null) {
    return false;
  }

  final leftDate = DateTime(month.year, month.month, leftDay);
  final rightDate = DateTime(month.year, month.month, rightDay);
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final firstDate = DateTime(
    firstTrackableDate.year,
    firstTrackableDate.month,
    firstTrackableDate.day,
  );

  return !leftDate.isBefore(firstDate) && !rightDate.isAfter(todayDate);
}

_TrackerDayState _calendarDayState({
  required DateTime month,
  required int day,
  required DateTime firstTrackableDate,
  required Map<String, ScrollDayStatus> dayStatuses,
}) {
  final actualDate = DateTime(month.year, month.month, day);
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final firstDate = DateTime(
    firstTrackableDate.year,
    firstTrackableDate.month,
    firstTrackableDate.day,
  );

  if (actualDate == firstDate) {
    return _TrackerDayState.installDay;
  }

  if (actualDate.isAfter(todayDate) || actualDate.isBefore(firstDate)) {
    return _TrackerDayState.disabled;
  }

  final dateKey = calendarDateKey(actualDate);
  final status = dayStatuses[dateKey] ?? ScrollDayStatus.scrolled;
  return switch (status) {
    ScrollDayStatus.noScroll => _TrackerDayState.blocked,
    ScrollDayStatus.partialScroll => _TrackerDayState.partial,
    ScrollDayStatus.scrolled => _TrackerDayState.none,
  };
}

String calendarDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
