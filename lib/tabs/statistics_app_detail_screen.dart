part of 'statistics_tab.dart';

enum _AppDateRangePreset {
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  last14Days('Last 14 Days'),
  lastMonth('Last 28 Days'),
  last365Days('Last 365 Days'),
  custom('Custom');

  const _AppDateRangePreset(this.label);

  final String label;
}

class _AppDetailScreen extends StatefulWidget {
  const _AppDetailScreen({
    required this.app,
    required this.statistics,
    required this.isPremium,
    required this.onOpenPremium,
    required this.onBack,
  });

  final StatisticsApp app;
  final StatisticsSnapshot statistics;
  final bool isPremium;
  final VoidCallback onOpenPremium;
  final VoidCallback onBack;

  @override
  State<_AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<_AppDetailScreen> {
  _BreakdownMode _breakdownMode = _BreakdownMode.weekly;
  int _selectedWeekOffset = 0;
  int _selectedDayOffset = 0;
  int? _activeBarIndex;
  _AppDateRangePreset _selectedRangePreset = _AppDateRangePreset.last7Days;
  DateTimeRange? _customDateRange;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final statistics = widget.statistics;
    final appScopedDaily = _filterDailyByAppIds(statistics.daily, {app.id});
    final filteredDaily = _filterStatisticsDaily(
      appScopedDaily,
      _selectedRangePreset,
      _customDateRange,
    );
    final previousDaily = _previousStatisticsDaily(
      appScopedDaily,
      _selectedRangePreset,
      _customDateRange,
    );
    final appDaily = filteredDaily
        .map((day) => day.appMinutes[app.id] ?? 0)
        .toList();
    final appSessionCounts = filteredDaily
        .map((day) => day.appSessionCounts[app.id] ?? 0)
        .toList();
    final weekSlices = _buildAppWeekSlices(statistics.daily, app.id);
    final effectiveWeekOffset = weekSlices.isEmpty
        ? 0
        : math.min(_selectedWeekOffset, weekSlices.length - 1);
    final selectedWeekIndex = weekSlices.isEmpty
        ? -1
        : math.max(0, weekSlices.length - 1 - effectiveWeekOffset);
    final selectedWeek = selectedWeekIndex >= 0
        ? weekSlices[selectedWeekIndex]
        : null;
    final last7Days = appScopedDaily.takeLast(7);
    final effectiveDayOffset = last7Days.isEmpty
        ? 0
        : math.min(_selectedDayOffset, last7Days.length - 1);
    final selectedDayIndex = last7Days.isEmpty
        ? -1
        : math.max(0, last7Days.length - 1 - effectiveDayOffset);
    final selectedDay = selectedDayIndex >= 0
        ? last7Days[selectedDayIndex]
        : null;
    final isLockedWeek =
        !widget.isPremium &&
        selectedWeek != null &&
        _isWeekOutsideFreeWindow(selectedWeek.entries.last.date);
    final isLockedDay =
        !widget.isPremium && selectedDay != null && !_isToday(selectedDay.date);
    final selectedDayHourlyMinutes = selectedDay == null
        ? const <int>[]
        : (selectedDay.appHourlyTrackedMinutes[app.id] ??
              List<int>.filled(24, 0));
    final breakdownMaxBar = _breakdownMode == _BreakdownMode.weekly
        ? selectedWeek == null
              ? 0
              : selectedWeek.entries.fold<int>(
                  0,
                  (current, entry) => math.max(current, entry.minutes ?? 0),
                )
        : selectedDayHourlyMinutes.fold<int>(0, math.max);
    final breakdownTotal = _breakdownMode == _BreakdownMode.weekly
        ? selectedWeek == null
              ? 0
              : selectedWeek.entries.fold<int>(
                  0,
                  (sum, entry) => sum + (entry.minutes ?? 0),
                )
        : selectedDay?.appMinutes[app.id] ?? 0;
    final breakdownAverage = _breakdownMode == _BreakdownMode.weekly
        ? selectedWeek == null ||
                  selectedWeek.entries
                      .where((entry) => entry.minutes != null)
                      .isEmpty
              ? 0.0
              : breakdownTotal /
                    selectedWeek.entries
                        .where((entry) => entry.minutes != null)
                        .length
        : selectedDay == null
        ? 0.0
        : breakdownTotal / 24;
    final breakdownGuideValues = _buildChartGuideValues(breakdownMaxBar);
    const breakdownPlotHeight = 148.0;
    final breakdownScaleTop = breakdownGuideValues.first;
    final breakdownBarCount = _breakdownMode == _BreakdownMode.weekly
        ? (selectedWeek?.entries.length ?? 0)
        : selectedDayHourlyMinutes.length;
    final breakdownLabel = _breakdownMode == _BreakdownMode.weekly
        ? selectedWeek == null
              ? 'No data'
              : _weekRangeLabel(
                  selectedWeek.entries.first.date,
                  selectedWeek.entries.last.date,
                )
        : selectedDay == null
        ? 'No data'
        : _dayRangeLabel(selectedDay.date);
    final totalTrackedInRange = appDaily.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final averageTrackedInRange = appDaily.isEmpty
        ? 0.0
        : totalTrackedInRange / appDaily.length;
    final totalSessionsInRange = appSessionCounts.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final averageSessionsInRange = appDaily.isEmpty
        ? 0.0
        : totalSessionsInRange / appDaily.length;
    final previousTotalTrackedInRange = previousDaily.fold<int>(
      0,
      (sum, day) => sum + (day.appMinutes[app.id] ?? 0),
    );
    final previousAverageTrackedInRange = previousDaily.isEmpty
        ? 0.0
        : previousTotalTrackedInRange / previousDaily.length;
    final previousTotalSessionsInRange = previousDaily.fold<int>(
      0,
      (sum, day) => sum + (day.appSessionCounts[app.id] ?? 0),
    );
    final previousAverageSessionsInRange = previousDaily.isEmpty
        ? 0.0
        : previousTotalSessionsInRange / previousDaily.length;
    final protectionKind = _protectionKind(app);
    final protectionBlockedCount = _protectionBlockedCount(filteredDaily, app);
    final protectionBypassedCount = _protectionBypassedCount(
      filteredDaily,
      app,
    );
    final protectionSavedMinutes = _protectionSavedMinutes(filteredDaily, app);
    final protectionBypassedMinutes = _protectionBypassedMinutes(
      filteredDaily,
      app,
    );

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        StickyHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StickyTitleHeader(
              title: app.appName,
              onBack: widget.onBack,
              leading: _AppIcon(
                iconBytes: app.iconBytes,
                label: app.appName,
                size: 32,
                borderRadius: 8,
              ),
              centerTitle: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<_AppDateRangePreset>(
                  onSelected: (preset) async {
                    if ((preset == _AppDateRangePreset.lastMonth ||
                            preset == _AppDateRangePreset.last365Days) &&
                        !widget.isPremium) {
                      widget.onOpenPremium();
                      return;
                    }
                    if (preset == _AppDateRangePreset.custom) {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange:
                            _customDateRange ??
                            DateTimeRange(
                              start: DateTime.now().subtract(
                                const Duration(days: 6),
                              ),
                              end: DateTime.now(),
                            ),
                      );
                      if (!mounted || range == null) return;
                      final selectedDays =
                          range.end.difference(range.start).inDays + 1;
                      if (!widget.isPremium && selectedDays > 31) {
                        widget.onOpenPremium();
                        return;
                      }
                      setState(() {
                        _selectedRangePreset = preset;
                        _customDateRange = range;
                        _selectedWeekOffset = 0;
                        _selectedDayOffset = 0;
                        _activeBarIndex = null;
                      });
                      return;
                    }
                    setState(() {
                      _selectedRangePreset = preset;
                      _customDateRange = null;
                      _selectedWeekOffset = 0;
                      _selectedDayOffset = 0;
                      _activeBarIndex = null;
                    });
                  },
                  itemBuilder: (context) => [
                    for (final preset in [
                      _AppDateRangePreset.today,
                      _AppDateRangePreset.yesterday,
                      _AppDateRangePreset.last7Days,
                      _AppDateRangePreset.last14Days,
                      _AppDateRangePreset.lastMonth,
                      _AppDateRangePreset.last365Days,
                    ])
                      PopupMenuItem<_AppDateRangePreset>(
                        value: preset,
                        child:
                            preset == _AppDateRangePreset.lastMonth ||
                                preset == _AppDateRangePreset.last365Days
                            ? Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/diamond.svg',
                                    width: 18,
                                    height: 18,
                                    colorFilter: const ColorFilter.mode(
                                      appText,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(preset.label),
                                ],
                              )
                            : Text(preset.label),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem<_AppDateRangePreset>(
                      value: _AppDateRangePreset.custom,
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/date_range.svg',
                            width: 18,
                            height: 18,
                            colorFilter: const ColorFilter.mode(
                              appText,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Custom'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: appSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedRangePreset ==
                                _AppDateRangePreset.lastMonth ||
                            _selectedRangePreset ==
                                _AppDateRangePreset.last365Days)
                          SvgPicture.asset(
                            'assets/icons/diamond.svg',
                            width: 18,
                            height: 18,
                            colorFilter: const ColorFilter.mode(
                              appText,
                              BlendMode.srcIn,
                            ),
                          )
                        else
                          SvgPicture.asset(
                            'assets/icons/date_range.svg',
                            width: 18,
                            height: 18,
                            colorFilter: const ColorFilter.mode(
                              appText,
                              BlendMode.srcIn,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _dateRangeLabel(
                            _selectedRangePreset,
                            _customDateRange,
                          ),
                          style: const TextStyle(
                            color: appText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: appMutedText,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _StatsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Overview',
                            style: TextStyle(
                              color: brand,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: appBorder),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                              child: _OverviewInlineMetric(
                                label: 'Total Time',
                                value: _formatMinutes(totalTrackedInRange),
                                delta: _buildMetricDelta(
                                  currentValue: totalTrackedInRange.toDouble(),
                                  previousValue: previousTotalTrackedInRange
                                      .toDouble(),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: appBorder),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                              child: _OverviewInlineMetric(
                                label: 'Daily Average',
                                value: _formatMinutesWithSeconds(
                                  averageTrackedInRange,
                                ),
                                delta: _buildMetricDelta(
                                  currentValue: averageTrackedInRange,
                                  previousValue: previousAverageTrackedInRange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: appBorder),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
                              child: _OverviewInlineMetric(
                                label: 'Total Opens',
                                value: _formatGroupedInt(totalSessionsInRange),
                                delta: _buildMetricDelta(
                                  currentValue: totalSessionsInRange.toDouble(),
                                  previousValue: previousTotalSessionsInRange
                                      .toDouble(),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: appBorder),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                              child: _OverviewInlineMetric(
                                label: 'Daily Opens',
                                value: _formatDecimalMetric(
                                  averageSessionsInRange,
                                  decimalPlaces: 2,
                                ),
                                delta: _buildMetricDelta(
                                  currentValue: averageSessionsInRange,
                                  previousValue: previousAverageSessionsInRange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (protectionKind != null) ...[
                const SizedBox(height: 8),
                _StatsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Protection',
                        style: TextStyle(
                          color: brand,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: appBorder),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  10,
                                  10,
                                  10,
                                ),
                                child: _OverviewInlineMetric(
                                  label: '$protectionKind Blocked',
                                  value: _formatTimesCount(
                                    protectionBlockedCount,
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, color: appBorder),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  0,
                                  10,
                                ),
                                child: _OverviewInlineMetric(
                                  label: '$protectionKind Bypassed',
                                  value: _formatTimesCount(
                                    protectionBypassedCount,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: appBorder),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  10,
                                  10,
                                  0,
                                ),
                                child: _OverviewInlineMetric(
                                  label: 'Time saved',
                                  value: _formatMinutes(protectionSavedMinutes),
                                ),
                              ),
                            ),
                            Container(width: 1, color: appBorder),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  0,
                                  0,
                                ),
                                child: _OverviewInlineMetric(
                                  label: 'Time bypassed',
                                  value: _formatMinutes(
                                    protectionBypassedMinutes,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _StatsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Breakdown',
                            style: TextStyle(
                              color: brand,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _BreakdownModeMenu(
                          mode: _breakdownMode,
                          onSelected: (mode) {
                            setState(() {
                              _breakdownMode = mode;
                              _activeBarIndex = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            breakdownLabel,
                            style: const TextStyle(
                              color: appText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _WeekNavButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: _breakdownMode == _BreakdownMode.weekly
                              ? effectiveWeekOffset < weekSlices.length - 1
                                    ? () {
                                        setState(() {
                                          _selectedWeekOffset++;
                                          _activeBarIndex = null;
                                        });
                                      }
                                    : null
                              : effectiveDayOffset < last7Days.length - 1
                              ? () {
                                  setState(() {
                                    _selectedDayOffset++;
                                    _activeBarIndex = null;
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(width: 6),
                        _WeekNavButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: _breakdownMode == _BreakdownMode.weekly
                              ? effectiveWeekOffset > 0
                                    ? () {
                                        setState(() {
                                          _selectedWeekOffset--;
                                          _activeBarIndex = null;
                                        });
                                      }
                                    : null
                              : effectiveDayOffset > 0
                              ? () {
                                  setState(() {
                                    _selectedDayOffset--;
                                    _activeBarIndex = null;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 196,
                              child: _breakdownMode == _BreakdownMode.weekly
                                  ? selectedWeek == null
                                        ? const Center(
                                            child: _EmptyLine(
                                              label:
                                                  'No data available for this app.',
                                            ),
                                          )
                                        : Column(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    SizedBox(
                                                      width: 22,
                                                      child: _ChartGuides(
                                                        guideValues:
                                                            breakdownGuideValues,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Expanded(
                                                      child: LayoutBuilder(
                                                        builder: (context, constraints) {
                                                          return Stack(
                                                            clipBehavior:
                                                                Clip.none,
                                                            children: [
                                                              _ChartGrid(
                                                                guideValues:
                                                                    breakdownGuideValues,
                                                                height: constraints
                                                                    .maxHeight,
                                                              ),
                                                              Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .end,
                                                                children: [
                                                                  for (
                                                                    var index =
                                                                        0;
                                                                    index <
                                                                        selectedWeek
                                                                            .entries
                                                                            .length;
                                                                    index++
                                                                  )
                                                                    _BreakdownBar(
                                                                      onTap: () {
                                                                        setState(() {
                                                                          _activeBarIndex =
                                                                              _activeBarIndex ==
                                                                                  index
                                                                              ? null
                                                                              : index;
                                                                        });
                                                                      },
                                                                      onLongPressStart: () {
                                                                        setState(() {
                                                                          _activeBarIndex =
                                                                              index;
                                                                        });
                                                                      },
                                                                      onLongPressEnd: () {
                                                                        setState(() {
                                                                          if (_activeBarIndex ==
                                                                              index) {
                                                                            _activeBarIndex =
                                                                                null;
                                                                          }
                                                                        });
                                                                      },
                                                                      height: _barHeightForMinutes(
                                                                        selectedWeek
                                                                            .entries[index]
                                                                            .minutes,
                                                                        breakdownScaleTop,
                                                                        breakdownPlotHeight,
                                                                      ),
                                                                      color:
                                                                          selectedWeek.entries[index].minutes ==
                                                                              null
                                                                          ? appSurfaceStrong
                                                                          : _activeBarIndex ==
                                                                                index
                                                                          ? brand.withValues(
                                                                              alpha: 0.72,
                                                                            )
                                                                          : brand,
                                                                      radius: 4,
                                                                    ),
                                                                ],
                                                              ),
                                                              if (_activeBarIndex !=
                                                                  null)
                                                                Positioned(
                                                                  left: _barTooltipLeft(
                                                                    _activeBarIndex!,
                                                                    breakdownBarCount,
                                                                    constraints
                                                                        .maxWidth,
                                                                    _barTooltipLabel(
                                                                      selectedWeek
                                                                          .entries[_activeBarIndex!]
                                                                          .minutes,
                                                                    ),
                                                                  ),
                                                                  bottom:
                                                                      _barHeightForMinutes(
                                                                        selectedWeek
                                                                            .entries[_activeBarIndex!]
                                                                            .minutes,
                                                                        breakdownScaleTop,
                                                                        breakdownPlotHeight,
                                                                      ) +
                                                                      8,
                                                                  child: _BarTooltip(
                                                                    label: _barTooltipLabel(
                                                                      selectedWeek
                                                                          .entries[_activeBarIndex!]
                                                                          .minutes,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const SizedBox(width: 27),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        for (final entry
                                                            in selectedWeek
                                                                .entries)
                                                          Expanded(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        1,
                                                                  ),
                                                              child: Text(
                                                                _weekdayLabel(
                                                                  entry.date,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                  color:
                                                                      appMutedText,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                  : selectedDay == null
                                  ? const Center(
                                      child: _EmptyLine(
                                        label:
                                            'No data available for this app.',
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              SizedBox(
                                                width: 22,
                                                child: _ChartGuides(
                                                  guideValues:
                                                      breakdownGuideValues,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        _ChartGrid(
                                                          guideValues:
                                                              breakdownGuideValues,
                                                          height: constraints
                                                              .maxHeight,
                                                        ),
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            for (
                                                              var index = 0;
                                                              index <
                                                                  selectedDayHourlyMinutes
                                                                      .length;
                                                              index++
                                                            )
                                                              _BreakdownBar(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _activeBarIndex =
                                                                        _activeBarIndex ==
                                                                            index
                                                                        ? null
                                                                        : index;
                                                                  });
                                                                },
                                                                onLongPressStart: () {
                                                                  setState(() {
                                                                    _activeBarIndex =
                                                                        index;
                                                                  });
                                                                },
                                                                onLongPressEnd: () {
                                                                  setState(() {
                                                                    if (_activeBarIndex ==
                                                                        index) {
                                                                      _activeBarIndex =
                                                                          null;
                                                                    }
                                                                  });
                                                                },
                                                                height: _barHeightForMinutes(
                                                                  selectedDayHourlyMinutes[index],
                                                                  breakdownScaleTop,
                                                                  breakdownPlotHeight,
                                                                ),
                                                                color:
                                                                    _activeBarIndex ==
                                                                        index
                                                                    ? brand.withValues(
                                                                        alpha:
                                                                            0.72,
                                                                      )
                                                                    : brand,
                                                                radius: 2,
                                                              ),
                                                          ],
                                                        ),
                                                        if (_activeBarIndex !=
                                                            null)
                                                          Positioned(
                                                            left: _barTooltipLeft(
                                                              _activeBarIndex!,
                                                              breakdownBarCount,
                                                              constraints
                                                                  .maxWidth,
                                                              _hourlyBarTooltipLabel(
                                                                _activeBarIndex!,
                                                                selectedDayHourlyMinutes[_activeBarIndex!],
                                                              ),
                                                            ),
                                                            bottom:
                                                                _barHeightForMinutes(
                                                                  selectedDayHourlyMinutes[_activeBarIndex!],
                                                                  breakdownScaleTop,
                                                                  breakdownPlotHeight,
                                                                ) +
                                                                8,
                                                            child: _BarTooltip(
                                                              label: _hourlyBarTooltipLabel(
                                                                _activeBarIndex!,
                                                                selectedDayHourlyMinutes[_activeBarIndex!],
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const SizedBox(width: 27),
                                            Expanded(
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  return SizedBox(
                                                    height: 14,
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        for (final tick
                                                            in _dailyAxisTicks)
                                                          Positioned(
                                                            left:
                                                                ((constraints
                                                                            .maxWidth -
                                                                        1) *
                                                                    ((tick.hour +
                                                                            0.5) /
                                                                        24)) -
                                                                16,
                                                            width: 32,
                                                            child: Text(
                                                              tick.label,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: const TextStyle(
                                                                color:
                                                                    appMutedText,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledValue(
                                    label:
                                        _breakdownMode == _BreakdownMode.weekly
                                        ? 'Week Total'
                                        : 'Day Total',
                                    value: _formatMinutes(breakdownTotal),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledValue(
                                    label:
                                        _breakdownMode == _BreakdownMode.weekly
                                        ? 'Daily Average'
                                        : 'Hourly Average',
                                    value: _formatMinutesWithSeconds(
                                      breakdownAverage,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_breakdownMode == _BreakdownMode.weekly &&
                            isLockedWeek)
                          Positioned(
                            top: -10,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _PremiumWeeklyOverlay(
                              onUpgrade: widget.onOpenPremium,
                            ),
                          ),
                        if (_breakdownMode == _BreakdownMode.daily &&
                            isLockedDay)
                          Positioned(
                            top: -10,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _PremiumWeeklyOverlay(
                              onUpgrade: widget.onOpenPremium,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _AppWeekSlice {
  const _AppWeekSlice({required this.entries});

  final List<_AppWeekEntry> entries;
}

class _AppWeekEntry {
  const _AppWeekEntry({
    required this.date,
    required this.day,
    required this.minutes,
  });

  final DateTime date;
  final StatisticsDailyPoint? day;
  final int? minutes;
}

class _OverviewInlineMetric extends StatelessWidget {
  const _OverviewInlineMetric({
    required this.label,
    required this.value,
    this.delta,
  });

  final String label;
  final String value;
  final _MetricDelta? delta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: appMutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  color: appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 6),
              Icon(
                delta!.isIncrease
                    ? Icons.north_east_rounded
                    : Icons.south_east_rounded,
                size: 14,
                color: delta!.color,
              ),
              const SizedBox(width: 2),
              Text(
                delta!.label,
                style: TextStyle(
                  color: delta!.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

List<_AppWeekSlice> _buildAppWeekSlices(
  List<StatisticsDailyPoint> daily,
  String appId,
) {
  if (daily.isEmpty) return const <_AppWeekSlice>[];

  final daysByKey = {for (final day in daily) day.dateKey: day};
  final earliestDate = daily.first.date;
  final latestDate = daily.last.date;
  final firstWeekStart = earliestDate.subtract(
    Duration(days: earliestDate.weekday - 1),
  );
  final lastWeekEnd = latestDate.add(Duration(days: 7 - latestDate.weekday));
  final slices = <_AppWeekSlice>[];
  for (
    var weekStart = firstWeekStart;
    !weekStart.isAfter(lastWeekEnd);
    weekStart = weekStart.add(const Duration(days: 7))
  ) {
    final entries = List<_AppWeekEntry>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final day = daysByKey[_dateKey(date)];
      return _AppWeekEntry(
        date: date,
        day: day,
        minutes: day == null ? null : (day.appMinutes[appId] ?? 0),
      );
    });
    slices.add(_AppWeekSlice(entries: entries));
  }
  return slices;
}

List<StatisticsDailyPoint> _filterStatisticsDaily(
  List<StatisticsDailyPoint> daily,
  _AppDateRangePreset preset,
  DateTimeRange? customDateRange,
) {
  if (daily.isEmpty) return const <StatisticsDailyPoint>[];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  late final DateTime start;
  late final DateTime end;

  switch (preset) {
    case _AppDateRangePreset.today:
      start = today;
      end = today;
    case _AppDateRangePreset.yesterday:
      start = today.subtract(const Duration(days: 1));
      end = start;
    case _AppDateRangePreset.last7Days:
      start = today.subtract(const Duration(days: 6));
      end = today;
    case _AppDateRangePreset.last14Days:
      start = today.subtract(const Duration(days: 13));
      end = today;
    case _AppDateRangePreset.lastMonth:
      start = today.subtract(const Duration(days: 27));
      end = today;
    case _AppDateRangePreset.last365Days:
      start = today.subtract(const Duration(days: 364));
      end = today;
    case _AppDateRangePreset.custom:
      if (customDateRange == null) return daily;
      start = DateTime(
        customDateRange.start.year,
        customDateRange.start.month,
        customDateRange.start.day,
      );
      end = DateTime(
        customDateRange.end.year,
        customDateRange.end.month,
        customDateRange.end.day,
      );
  }

  return daily.where((day) {
    final date = DateTime(day.date.year, day.date.month, day.date.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList();
}

String _dateRangeLabel(
  _AppDateRangePreset preset,
  DateTimeRange? customDateRange,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (preset) {
    case _AppDateRangePreset.today:
      return preset.label;
    case _AppDateRangePreset.yesterday:
      return preset.label;
    case _AppDateRangePreset.last7Days:
      final start = today.subtract(const Duration(days: 6));
      return '${_shortDate(start)} - ${_shortDate(today)}';
    case _AppDateRangePreset.last14Days:
      final start = today.subtract(const Duration(days: 13));
      return '${_shortDate(start)} - ${_shortDate(today)}';
    case _AppDateRangePreset.lastMonth:
      final start = today.subtract(const Duration(days: 27));
      return '${_shortDate(start)} - ${_shortDate(today)}';
    case _AppDateRangePreset.last365Days:
      final start = today.subtract(const Duration(days: 364));
      return '${_shortDate(start)} - ${_shortDate(today)}';
    case _AppDateRangePreset.custom:
      if (customDateRange == null) {
        return preset.label;
      }
      return '${_shortDate(customDateRange.start)} - ${_shortDate(customDateRange.end)}';
  }
}

String? _protectionKind(StatisticsApp app) {
  final id = app.id.toLowerCase();
  final packageName = app.packageName.toLowerCase();
  if (id == 'instagram' || packageName.contains('instagram')) {
    return 'Reels';
  }
  if (id == 'youtube' ||
      packageName.contains('youtube') ||
      packageName.contains('revanced')) {
    return 'Shorts';
  }
  if (id == 'snapchat' || packageName.contains('snapchat')) {
    return 'Spotlight';
  }
  return null;
}

int _protectionBlockedCount(
  List<StatisticsDailyPoint> daily,
  StatisticsApp app,
) {
  final id = app.id.toLowerCase();
  final packageName = app.packageName.toLowerCase();
  if (id == 'instagram' || packageName.contains('instagram')) {
    return daily.fold<int>(
      0,
      (sum, day) => sum + (day.appReelsBlocks[app.id] ?? 0),
    );
  }
  if (id == 'youtube' ||
      packageName.contains('youtube') ||
      packageName.contains('revanced')) {
    return daily.fold<int>(
      0,
      (sum, day) => sum + (day.appShortsBlocks[app.id] ?? 0),
    );
  }
  if (id == 'snapchat' || packageName.contains('snapchat')) {
    return daily.fold<int>(
      0,
      (sum, day) => sum + (day.appSpotlightBlocks[app.id] ?? 0),
    );
  }
  return 0;
}

int _protectionBypassedCount(
  List<StatisticsDailyPoint> daily,
  StatisticsApp app,
) {
  return daily.fold<int>(0, (sum, day) => sum + (day.appBypasses[app.id] ?? 0));
}

int _protectionSavedMinutes(
  List<StatisticsDailyPoint> daily,
  StatisticsApp app,
) {
  return _protectionBlockedCount(daily, app) * 10;
}

int _protectionBypassedMinutes(
  List<StatisticsDailyPoint> daily,
  StatisticsApp app,
) {
  return daily.fold<int>(
    0,
    (sum, day) => sum + (day.appBypassedMinutes[app.id] ?? 0),
  );
}

double _barHeightForMinutes(int? minutes, int scaleTop, double plotHeight) {
  if (minutes == null) return 4;
  if (scaleTop <= 0) return 4;
  return math.max(4, (minutes / scaleTop) * plotHeight).toDouble();
}

String _formatMinutesWithSeconds(double minutes) {
  if (minutes <= 0) return '0m';
  final totalSeconds = (minutes * 60).round();
  final hours = totalSeconds ~/ 3600;
  final remainingSecondsAfterHours = totalSeconds % 3600;
  final wholeMinutes = remainingSecondsAfterHours ~/ 60;
  final seconds = remainingSecondsAfterHours % 60;
  if (hours > 0) {
    return '${_formatGroupedInt(hours)}h ${_formatGroupedInt(wholeMinutes)}m';
  }
  if (seconds == 0) return '${_formatGroupedInt(wholeMinutes)}m';
  return '${_formatGroupedInt(wholeMinutes)}m ${_formatGroupedInt(seconds)}s';
}

String _formatDecimalMetric(double value, {int decimalPlaces = 1}) {
  if (value == value.roundToDouble()) {
    return _formatGroupedInt(value.toInt());
  }
  return _formatGroupedDouble(value, decimalPlaces: decimalPlaces);
}

String _formatTimesCount(int value) {
  return '${_formatGroupedInt(value)} times';
}

String _formatTimesMetric(double value, {int decimalPlaces = 1}) {
  return '${_formatDecimalMetric(value, decimalPlaces: decimalPlaces)} times';
}

String _barTooltipLabel(int? minutes) {
  if (minutes == null) return 'No data yet';
  return _formatMinutes(minutes);
}

double _barTooltipWidthForLabel(String label) {
  return (label.length * 7.0 + 14).clamp(48.0, 96.0);
}

double _barTooltipLeft(
  int index,
  int count,
  double availableWidth,
  String label,
) {
  if (count <= 0) return 0;
  final tooltipWidth = _barTooltipWidthForLabel(label);
  final slotWidth = availableWidth / count;
  final centerX = (slotWidth * index) + (slotWidth / 2);
  final unclampedLeft = centerX - (tooltipWidth / 2);
  return unclampedLeft.clamp(0, math.max(0, availableWidth - tooltipWidth));
}

List<int> _buildChartGuideValues(int maxMinutes) {
  if (maxMinutes <= 0) return const [8, 6, 4, 2, 0];
  final step = _niceGuideStep(maxMinutes / 4);
  var top = ((maxMinutes / step).ceil()) * step;
  if (top <= maxMinutes) {
    top += step;
  }
  return [for (var value = top; value >= 0; value -= step) value];
}

int _niceGuideStep(double targetStep) {
  if (targetStep <= 1) return 1;
  final magnitude = math
      .pow(10, (math.log(targetStep) / math.ln10).floor())
      .toInt();
  final normalized = targetStep / magnitude;
  final multiplier = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return multiplier * magnitude;
}

String _formatGuideValue(int minutes) {
  if (minutes < 60) {
    return '${_formatGroupedInt(minutes)}m';
  }
  final hours = minutes / 60;
  if ((hours * 2).roundToDouble() == hours * 2) {
    if (hours == hours.roundToDouble()) {
      return '${_formatGroupedInt(hours.toInt())}h';
    }
    return '${_formatGroupedDouble(hours, decimalPlaces: 1)}h';
  }
  return '${_formatGroupedDouble(hours, decimalPlaces: 1)}h';
}

String _weekRangeLabel(DateTime start, DateTime end) {
  final startLabel = _shortDate(start);
  final endLabel = _shortDate(end);
  return startLabel == endLabel ? startLabel : '$startLabel - $endLabel';
}

class _WeekNavButton extends StatelessWidget {
  const _WeekNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null ? appSurfaceStrong : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: appBorder),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? appMutedText.withValues(alpha: 0.5) : appText,
        ),
      ),
    );
  }
}

class _BarTooltip extends StatelessWidget {
  const _BarTooltip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: _barTooltipWidthForLabel(label),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: appText,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
