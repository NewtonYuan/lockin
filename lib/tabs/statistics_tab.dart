import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';
import 'block_tab.dart';
import 'sticky_header.dart';

part 'statistics_app_detail_screen.dart';

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.generatedAt,
    required this.overview,
    required this.daily,
    required this.protection,
    required this.timeOfDay,
    required this.apps,
    required this.websites,
  });

  factory StatisticsSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final generatedAtMillis = map['generatedAtMillis'];
    return StatisticsSnapshot(
      generatedAt: generatedAtMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(generatedAtMillis)
          : DateTime.now(),
      overview: StatisticsOverview.fromMap(
        (map['overview'] as Map?) ?? const <String, dynamic>{},
      ),
      daily: ((map['daily'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(StatisticsDailyPoint.fromMap)
          .toList(),
      protection: StatisticsProtection.fromMap(
        (map['protection'] as Map?) ?? const <String, dynamic>{},
      ),
      timeOfDay: ((map['timeOfDay'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(StatisticsTimeOfDayBucket.fromMap)
          .toList(),
      apps: ((map['apps'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(StatisticsApp.fromMap)
          .toList(),
      websites: ((map['websites'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(StatisticsWebsite.fromMap)
          .toList(),
    );
  }

  final DateTime generatedAt;
  final StatisticsOverview overview;
  final List<StatisticsDailyPoint> daily;
  final StatisticsProtection protection;
  final List<StatisticsTimeOfDayBucket> timeOfDay;
  final List<StatisticsApp> apps;
  final List<StatisticsWebsite> websites;
}

class StatisticsOverview {
  const StatisticsOverview({
    required this.todayTrackedMinutes,
    required this.weekTrackedMinutes,
    required this.averageDailyTrackedMinutes7d,
    required this.todayBlocks,
    required this.todayBypasses,
    required this.todayBypassMinutes,
    required this.weekBypassMinutes,
    required this.todayLimitOverageMinutes,
    required this.weekLimitOverageMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.mostUsedAppName,
    required this.mostUsedAppMinutes,
    required this.blockedWebsitesCount,
  });

  factory StatisticsOverview.fromMap(Map<dynamic, dynamic> map) {
    return StatisticsOverview(
      todayTrackedMinutes: _readInt(map['todayTrackedMinutes']),
      weekTrackedMinutes: _readInt(map['weekTrackedMinutes']),
      averageDailyTrackedMinutes7d: _readDouble(
        map['averageDailyTrackedMinutes7d'],
      ),
      todayBlocks: _readInt(map['todayBlocks']),
      todayBypasses: _readInt(map['todayBypasses']),
      todayBypassMinutes: _readInt(map['todayBypassMinutes']),
      weekBypassMinutes: _readInt(map['weekBypassMinutes']),
      todayLimitOverageMinutes: _readInt(map['todayLimitOverageMinutes']),
      weekLimitOverageMinutes: _readInt(map['weekLimitOverageMinutes']),
      currentStreak: _readInt(map['currentStreak']),
      longestStreak: _readInt(map['longestStreak']),
      mostUsedAppName: (map['mostUsedAppName'] as String?) ?? '',
      mostUsedAppMinutes: _readInt(map['mostUsedAppMinutes']),
      blockedWebsitesCount: _readInt(map['blockedWebsitesCount']),
    );
  }

  final int todayTrackedMinutes;
  final int weekTrackedMinutes;
  final double averageDailyTrackedMinutes7d;
  final int todayBlocks;
  final int todayBypasses;
  final int todayBypassMinutes;
  final int weekBypassMinutes;
  final int todayLimitOverageMinutes;
  final int weekLimitOverageMinutes;
  final int currentStreak;
  final int longestStreak;
  final String mostUsedAppName;
  final int mostUsedAppMinutes;
  final int blockedWebsitesCount;
}

class StatisticsDailyPoint {
  const StatisticsDailyPoint({
    required this.dateKey,
    required this.trackedMinutes,
    required this.blocks,
    required this.bypasses,
    required this.reelsBlocks,
    required this.shortsBlocks,
    required this.websiteBlocks,
    required this.pauseOnOpenPrompts,
    required this.dailyLimitHits,
    required this.shortFormBypasses,
    required this.websiteBypasses,
    required this.pauseOnOpenBypasses,
    required this.dailyLimitBypasses,
    required this.sessionCount,
    required this.longestSessionMinutes,
    required this.appMinutes,
    required this.appSessionCounts,
    required this.appLongestSessionMinutes,
    required this.appReelsBlocks,
    required this.appShortsBlocks,
    required this.appPauseOnOpenPrompts,
    required this.appDailyLimitHits,
    required this.appBypasses,
    required this.appBypassedMinutes,
    required this.timeOfDayBlocks,
    required this.timeOfDayBypasses,
  });

  factory StatisticsDailyPoint.fromMap(Map<dynamic, dynamic> map) {
    final rawAppMinutes = map['appMinutes'] as Map?;
    return StatisticsDailyPoint(
      dateKey: (map['dateKey'] as String?) ?? '',
      trackedMinutes: _readInt(map['trackedMinutes']),
      blocks: _readInt(map['blocks']),
      bypasses: _readInt(map['bypasses']),
      reelsBlocks: _readInt(map['reelsBlocks']),
      shortsBlocks: _readInt(map['shortsBlocks']),
      websiteBlocks: _readInt(map['websiteBlocks']),
      pauseOnOpenPrompts: _readInt(map['pauseOnOpenPrompts']),
      dailyLimitHits: _readInt(map['dailyLimitHits']),
      shortFormBypasses: _readInt(map['shortFormBypasses']),
      websiteBypasses: _readInt(map['websiteBypasses']),
      pauseOnOpenBypasses: _readInt(map['pauseOnOpenBypasses']),
      dailyLimitBypasses: _readInt(map['dailyLimitBypasses']),
      sessionCount: _readInt(map['sessionCount']),
      longestSessionMinutes: _readInt(map['longestSessionMinutes']),
      appMinutes: {
        for (final entry
            in (rawAppMinutes?.entries ?? <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appSessionCounts: {
        for (final entry
            in (((map['appSessionCounts'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appLongestSessionMinutes: {
        for (final entry
            in (((map['appLongestSessionMinutes'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appReelsBlocks: {
        for (final entry
            in (((map['appReelsBlocks'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appShortsBlocks: {
        for (final entry
            in (((map['appShortsBlocks'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appPauseOnOpenPrompts: {
        for (final entry
            in (((map['appPauseOnOpenPrompts'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appDailyLimitHits: {
        for (final entry
            in (((map['appDailyLimitHits'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appBypasses: {
        for (final entry
            in (((map['appBypasses'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      appBypassedMinutes: {
        for (final entry
            in (((map['appBypassedMinutes'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      timeOfDayBlocks: {
        for (final entry
            in (((map['timeOfDayBlocks'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
      timeOfDayBypasses: {
        for (final entry
            in (((map['timeOfDayBypasses'] as Map?)?.entries) ??
                <MapEntry<dynamic, dynamic>>[]))
          '${entry.key}': _readInt(entry.value),
      },
    );
  }

  final String dateKey;
  final int trackedMinutes;
  final int blocks;
  final int bypasses;
  final int reelsBlocks;
  final int shortsBlocks;
  final int websiteBlocks;
  final int pauseOnOpenPrompts;
  final int dailyLimitHits;
  final int shortFormBypasses;
  final int websiteBypasses;
  final int pauseOnOpenBypasses;
  final int dailyLimitBypasses;
  final int sessionCount;
  final int longestSessionMinutes;
  final Map<String, int> appMinutes;
  final Map<String, int> appSessionCounts;
  final Map<String, int> appLongestSessionMinutes;
  final Map<String, int> appReelsBlocks;
  final Map<String, int> appShortsBlocks;
  final Map<String, int> appPauseOnOpenPrompts;
  final Map<String, int> appDailyLimitHits;
  final Map<String, int> appBypasses;
  final Map<String, int> appBypassedMinutes;
  final Map<String, int> timeOfDayBlocks;
  final Map<String, int> timeOfDayBypasses;

  DateTime get date {
    final parts = dateKey.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }
}

class StatisticsProtection {
  const StatisticsProtection({
    required this.reelsBlocks,
    required this.shortsBlocks,
    required this.websiteBlocks,
    required this.pauseOnOpenPrompts,
    required this.dailyLimitHits,
    required this.totalBlocks,
    required this.shortFormBypasses,
    required this.websiteBypasses,
    required this.pauseOnOpenBypasses,
    required this.dailyLimitBypasses,
    required this.totalBypasses,
  });

  factory StatisticsProtection.fromMap(Map<dynamic, dynamic> map) {
    return StatisticsProtection(
      reelsBlocks: _readInt(map['reelsBlocks']),
      shortsBlocks: _readInt(map['shortsBlocks']),
      websiteBlocks: _readInt(map['websiteBlocks']),
      pauseOnOpenPrompts: _readInt(map['pauseOnOpenPrompts']),
      dailyLimitHits: _readInt(map['dailyLimitHits']),
      totalBlocks: _readInt(map['totalBlocks']),
      shortFormBypasses: _readInt(map['shortFormBypasses']),
      websiteBypasses: _readInt(map['websiteBypasses']),
      pauseOnOpenBypasses: _readInt(map['pauseOnOpenBypasses']),
      dailyLimitBypasses: _readInt(map['dailyLimitBypasses']),
      totalBypasses: _readInt(map['totalBypasses']),
    );
  }

  final int reelsBlocks;
  final int shortsBlocks;
  final int websiteBlocks;
  final int pauseOnOpenPrompts;
  final int dailyLimitHits;
  final int totalBlocks;
  final int shortFormBypasses;
  final int websiteBypasses;
  final int pauseOnOpenBypasses;
  final int dailyLimitBypasses;
  final int totalBypasses;
}

class StatisticsTimeOfDayBucket {
  const StatisticsTimeOfDayBucket({
    required this.label,
    required this.blocks,
    required this.bypasses,
  });

  factory StatisticsTimeOfDayBucket.fromMap(Map<dynamic, dynamic> map) {
    return StatisticsTimeOfDayBucket(
      label: (map['label'] as String?) ?? '',
      blocks: _readInt(map['blocks']),
      bypasses: _readInt(map['bypasses']),
    );
  }

  final String label;
  final int blocks;
  final int bypasses;
}

class StatisticsApp {
  const StatisticsApp({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.iconBytes,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.averageDailyMinutes7d,
    required this.highestDayMinutes30d,
    required this.launchCountToday,
    required this.launchCountWeek,
    required this.longestSessionMinutes30d,
    required this.reelsBlocks,
    required this.shortsBlocks,
    required this.pauseOnOpenPrompts,
    required this.dailyLimitHits,
    required this.bypasses,
    required this.bypassedMinutes,
    required this.dailyMinutes30d,
  });

  factory StatisticsApp.fromMap(Map<dynamic, dynamic> map) {
    return StatisticsApp(
      id: (map['id'] as String?) ?? '',
      appName: (map['appName'] as String?) ?? '',
      packageName: (map['packageName'] as String?) ?? '',
      iconBytes: map['iconBytes'] as Uint8List?,
      todayMinutes: _readInt(map['todayMinutes']),
      weekMinutes: _readInt(map['weekMinutes']),
      averageDailyMinutes7d: _readDouble(map['averageDailyMinutes7d']),
      highestDayMinutes30d: _readInt(map['highestDayMinutes30d']),
      launchCountToday: _readInt(map['launchCountToday']),
      launchCountWeek: _readInt(map['launchCountWeek']),
      longestSessionMinutes30d: _readInt(map['longestSessionMinutes30d']),
      reelsBlocks: _readInt(map['reelsBlocks']),
      shortsBlocks: _readInt(map['shortsBlocks']),
      pauseOnOpenPrompts: _readInt(map['pauseOnOpenPrompts']),
      dailyLimitHits: _readInt(map['dailyLimitHits']),
      bypasses: _readInt(map['bypasses']),
      bypassedMinutes: _readInt(map['bypassedMinutes']),
      dailyMinutes30d: ((map['dailyMinutes30d'] as List?) ?? const <dynamic>[])
          .map(_readInt)
          .toList(),
    );
  }

  final String id;
  final String appName;
  final String packageName;
  final Uint8List? iconBytes;
  final int todayMinutes;
  final int weekMinutes;
  final double averageDailyMinutes7d;
  final int highestDayMinutes30d;
  final int launchCountToday;
  final int launchCountWeek;
  final int longestSessionMinutes30d;
  final int reelsBlocks;
  final int shortsBlocks;
  final int pauseOnOpenPrompts;
  final int dailyLimitHits;
  final int bypasses;
  final int bypassedMinutes;
  final List<int> dailyMinutes30d;
}

class StatisticsWebsite {
  const StatisticsWebsite({
    required this.domain,
    required this.blocks,
    required this.bypasses,
  });

  factory StatisticsWebsite.fromMap(Map<dynamic, dynamic> map) {
    return StatisticsWebsite(
      domain: (map['domain'] as String?) ?? '',
      blocks: _readInt(map['blocks']),
      bypasses: _readInt(map['bypasses']),
    );
  }

  final String domain;
  final int blocks;
  final int bypasses;
}

enum _StatsAppFilter {
  allApps('All Apps'),
  onlyBlockedApps('Only Block Apps');

  const _StatsAppFilter(this.label);

  final String label;
}

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({
    super.key,
    required this.onBackToHome,
    required this.statistics,
    required this.installedApps,
    required this.isLoading,
    required this.isPremium,
    required this.onOpenPremium,
    required this.isUsageAccessAllowed,
    required this.onOpenUsageAccessSettings,
  });

  final VoidCallback onBackToHome;
  final StatisticsSnapshot? statistics;
  final List<CustomTrackedApp> installedApps;
  final bool isLoading;
  final bool isPremium;
  final VoidCallback onOpenPremium;
  final bool isUsageAccessAllowed;
  final VoidCallback onOpenUsageAccessSettings;

  @override
  State<StatisticsTab> createState() => StatisticsTabState();
}

class StatisticsTabState extends State<StatisticsTab> {
  StatisticsApp? _selectedApp;
  _AppDateRangePreset _selectedRangePreset = _AppDateRangePreset.last7Days;
  DateTimeRange? _customDateRange;
  _StatsAppFilter _selectedAppFilter = _StatsAppFilter.allApps;

  void resetToBase() {
    if (_selectedApp == null) return;
    setState(() {
      _selectedApp = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.statistics == null) {
      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          StickyHeaderSliver(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StickyTitleHeader(
                title: 'Statistics',
                onBack: widget.onBackToHome,
                centerTitle: false,
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: brand,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Loading statistics...',
                    style: TextStyle(
                      color: appMutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final snapshot = _statisticsSnapshotForDisplay(
      widget.statistics,
      widget.installedApps,
    );
    final visibleApps = _selectedAppFilter == _StatsAppFilter.onlyBlockedApps
        ? snapshot.apps.where(_isBlockedStatisticsApp).toList()
        : snapshot.apps;
    final visibleAppIds = visibleApps.map((app) => app.id).toSet();
    final appScopedDaily = _filterDailyByAppIds(snapshot.daily, visibleAppIds);
    final filteredDaily = _filterStatisticsDaily(
      appScopedDaily,
      _selectedRangePreset,
      _customDateRange,
    );

    if (_selectedApp != null) {
      return _AppDetailScreen(
        app: _selectedApp!,
        statistics: snapshot,
        isPremium: widget.isPremium,
        onOpenPremium: widget.onOpenPremium,
        onBack: () {
          setState(() {
            _selectedApp = null;
          });
        },
      );
    }

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        StickyHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StickyTitleHeader(
              title: 'Statistics',
              onBack: widget.onBackToHome,
              centerTitle: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (widget.isLoading) ...[
                const _StatisticsLoadingBanner(),
                const SizedBox(height: 12),
              ],
              if (!widget.isUsageAccessAllowed) ...[
                _PermissionBanner(onTap: widget.onOpenUsageAccessSettings),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PopupMenuButton<_AppDateRangePreset>(
                        onSelected: (preset) async {
                          if (preset == _AppDateRangePreset.last365Days &&
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
                                range.end
                                    .difference(range.start)
                                    .inDays +
                                1;
                            if (!widget.isPremium && selectedDays > 31) {
                              widget.onOpenPremium();
                              return;
                            }
                            setState(() {
                              _selectedRangePreset = preset;
                              _customDateRange = range;
                            });
                            return;
                          }
                          setState(() {
                            _selectedRangePreset = preset;
                            _customDateRange = null;
                          });
                        },
                        itemBuilder: (context) => [
                          for (final preset in [
                            _AppDateRangePreset.today,
                            _AppDateRangePreset.yesterday,
                            _AppDateRangePreset.last7Days,
                            _AppDateRangePreset.lastMonth,
                            _AppDateRangePreset.last365Days,
                          ])
                            PopupMenuItem<_AppDateRangePreset>(
                              value: preset,
                              child: preset == _AppDateRangePreset.last365Days
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
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_StatsAppFilter>(
                    onSelected: (value) {
                      setState(() {
                        _selectedAppFilter = value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<_StatsAppFilter>(
                        value: _StatsAppFilter.allApps,
                        child: Text('All Apps'),
                      ),
                      PopupMenuItem<_StatsAppFilter>(
                        value: _StatsAppFilter.onlyBlockedApps,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/block.svg',
                              width: 14,
                              height: 14,
                              colorFilter: const ColorFilter.mode(
                                appText,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text('Block Apps'),
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
                        color:
                            _selectedAppFilter ==
                                _StatsAppFilter.onlyBlockedApps
                            ? appText.withValues(alpha: 0.94)
                            : appSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedAppFilter ==
                              _StatsAppFilter.onlyBlockedApps) ...[
                            SvgPicture.asset(
                              'assets/icons/block.svg',
                              width: 14,
                              height: 14,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Block Apps',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else
                            Text(
                              _selectedAppFilter.label,
                              style: const TextStyle(
                                color: appText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.expand_more_rounded,
                            color:
                                _selectedAppFilter ==
                                    _StatsAppFilter.onlyBlockedApps
                                ? Colors.white
                                : appMutedText,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _OverviewSection(
                daily: appScopedDaily,
                preset: _selectedRangePreset,
                customDateRange: _customDateRange,
              ),
              const SizedBox(height: 8),
              _AppsSection(
                apps: visibleApps,
                daily: filteredDaily,
                onOpenApp: (app) {
                  setState(() {
                    _selectedApp = app;
                  });
                },
              ),
              const SizedBox(height: 8),
              _TrendSection(daily: appScopedDaily),
              const SizedBox(height: 8),
              _AdvancedSection(statistics: snapshot, daily: filteredDaily),
            ]),
          ),
        ),
      ],
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4F2),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFC65A43),
                size: 18,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Usage Access is off',
                  style: TextStyle(
                    color: Color(0xFFC65A43),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Fix',
                style: TextStyle(
                  color: Color(0xFFC65A43),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC65A43),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsLoadingBanner extends StatelessWidget {
  const _StatisticsLoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: brand,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Refreshing statistics...',
                style: TextStyle(
                  color: appText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.daily,
    required this.preset,
    required this.customDateRange,
  });

  final List<StatisticsDailyPoint> daily;
  final _AppDateRangePreset preset;
  final DateTimeRange? customDateRange;

  @override
  Widget build(BuildContext context) {
    final currentDaily = _filterStatisticsDaily(daily, preset, customDateRange);
    final previousDaily = _previousStatisticsDaily(
      daily,
      preset,
      customDateRange,
    );
    final currentSummary = _overviewSummary(currentDaily);
    final previousSummary = _overviewSummary(previousDaily);
    final totalMinutes = currentSummary.totalMinutes;
    final averageMinutes = currentSummary.averageMinutes;
    final totalSessions = currentSummary.totalSessions;
    final averageSessions = currentSummary.averageSessions;
    final totalBlocks = currentSummary.totalBlocks;
    final averageBlocks = currentSummary.averageBlocks;
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
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
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: _OverviewInlineMetric(
                      label: 'Total Time',
                      value: _formatMinutes(totalMinutes),
                      delta: _buildMetricDelta(
                        currentValue: totalMinutes.toDouble(),
                        previousValue: previousSummary.totalMinutes.toDouble(),
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
                      value: _formatMinutesWithSeconds(averageMinutes),
                      delta: _buildMetricDelta(
                        currentValue: averageMinutes,
                        previousValue: previousSummary.averageMinutes,
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
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: _OverviewInlineMetric(
                      label: 'Total Sessions',
                      value: _formatGroupedInt(totalSessions),
                      delta: _buildMetricDelta(
                        currentValue: totalSessions.toDouble(),
                        previousValue: previousSummary.totalSessions.toDouble(),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, color: appBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                    child: _OverviewInlineMetric(
                      label: 'Daily Sessions',
                      value: _formatDecimalMetric(
                        averageSessions,
                        decimalPlaces: 2,
                      ),
                      delta: _buildMetricDelta(
                        currentValue: averageSessions,
                        previousValue: previousSummary.averageSessions,
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
                      label: 'Total Blocks',
                      value: _formatGroupedInt(totalBlocks),
                    ),
                  ),
                ),
                Container(width: 1, color: appBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                    child: _OverviewInlineMetric(
                      label: 'Daily Blocks',
                      value: _formatDecimalMetric(
                        averageBlocks,
                        decimalPlaces: 2,
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

class _OverviewSummary {
  const _OverviewSummary({
    required this.totalMinutes,
    required this.averageMinutes,
    required this.totalSessions,
    required this.averageSessions,
    required this.totalBlocks,
    required this.averageBlocks,
  });

  final int totalMinutes;
  final double averageMinutes;
  final int totalSessions;
  final double averageSessions;
  final int totalBlocks;
  final double averageBlocks;
}

_OverviewSummary _overviewSummary(List<StatisticsDailyPoint> daily) {
  final totalMinutes = daily.fold<int>(
      0,
      (sum, day) => sum + day.trackedMinutes,
    );
    final averageMinutes = daily.isEmpty ? 0.0 : totalMinutes / daily.length;
    final totalSessions = daily.fold<int>(
      0,
      (sum, day) => sum + day.sessionCount,
    );
    final averageSessions = daily.isEmpty ? 0.0 : totalSessions / daily.length;
    final totalBlocks = daily.fold<int>(0, (sum, day) => sum + day.blocks);
    final averageBlocks = daily.isEmpty ? 0.0 : totalBlocks / daily.length;
  return _OverviewSummary(
    totalMinutes: totalMinutes,
    averageMinutes: averageMinutes,
    totalSessions: totalSessions,
    averageSessions: averageSessions,
    totalBlocks: totalBlocks,
    averageBlocks: averageBlocks,
  );
}

class _TrendSection extends StatefulWidget {
  const _TrendSection({required this.daily});

  final List<StatisticsDailyPoint> daily;

  @override
  State<_TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<_TrendSection> {
  int _selectedWeekOffset = 0;
  int? _activeBarIndex;

  @override
  Widget build(BuildContext context) {
    final weekSlices = _buildDailyWeekSlices(widget.daily);
    final selectedWeekIndex = weekSlices.isEmpty
        ? -1
        : math.max(0, weekSlices.length - 1 - _selectedWeekOffset);
    final selectedWeek = selectedWeekIndex >= 0
        ? weekSlices[selectedWeekIndex]
        : null;
    final maxBarMinutes = selectedWeek == null
        ? 0
        : selectedWeek.entries.fold<int>(
            0,
            (current, entry) =>
                math.max(current, entry.day?.trackedMinutes ?? 0),
          );
    final guideValues = _buildChartGuideValues(maxBarMinutes);
    const plotHeight = 148.0;
    final scaleTop = guideValues.first;
    final weekTotal = selectedWeek == null
        ? 0
        : selectedWeek.entries.fold<int>(
            0,
            (sum, entry) => sum + (entry.day?.trackedMinutes ?? 0),
          );
    final weekAverage =
        selectedWeek == null ||
            selectedWeek.entries.where((entry) => entry.day != null).isEmpty
        ? 0.0
        : weekTotal /
              selectedWeek.entries.where((entry) => entry.day != null).length;

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Breakdown',
            style: TextStyle(
              color: brand,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedWeek == null
                      ? 'No activity yet'
                      : _weekRangeLabel(
                          selectedWeek.entries.first.date,
                          selectedWeek.entries.last.date,
                        ),
                  style: const TextStyle(
                    color: appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _WeekNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: _selectedWeekOffset < weekSlices.length - 1
                    ? () {
                        setState(() {
                          _selectedWeekOffset++;
                          _activeBarIndex = null;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              _WeekNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _selectedWeekOffset > 0
                    ? () {
                        setState(() {
                          _selectedWeekOffset--;
                          _activeBarIndex = null;
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 196,
            child: selectedWeek == null
                ? const Center(
                    child: _EmptyLine(label: 'No data available yet.'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 22,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < guideValues.length;
                                        index++
                                      )
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top:
                                              (constraints.maxHeight /
                                                  (guideValues.length - 1)) *
                                              index,
                                          child: Transform.translate(
                                            offset: const Offset(0, -10),
                                            child: Text(
                                              _formatGuideValue(
                                                guideValues[index],
                                              ),
                                              textAlign: TextAlign.left,
                                              style: const TextStyle(
                                                color: appMutedText,
                                                fontSize: 10,
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
                            const SizedBox(width: 5),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final barCount = selectedWeek.entries.length;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < guideValues.length;
                                        index++
                                      )
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top:
                                              (constraints.maxHeight /
                                                  (guideValues.length - 1)) *
                                              index,
                                          child: Container(
                                            height: 1,
                                            color: appBorder,
                                          ),
                                        ),
                                      if (_activeBarIndex != null)
                                        Positioned(
                                          left: _barTooltipLeft(
                                            _activeBarIndex!,
                                            barCount,
                                            constraints.maxWidth,
                                            _barTooltipLabel(
                                              selectedWeek
                                                  .entries[_activeBarIndex!]
                                                  .day
                                                  ?.trackedMinutes,
                                            ),
                                          ),
                                          bottom:
                                              _barHeightForMinutes(
                                                selectedWeek
                                                    .entries[_activeBarIndex!]
                                                    .day
                                                    ?.trackedMinutes,
                                                scaleTop,
                                                plotHeight,
                                              ) +
                                              8,
                                          child: _BarTooltip(
                                            label: _barTooltipLabel(
                                              selectedWeek
                                                  .entries[_activeBarIndex!]
                                                  .day
                                                  ?.trackedMinutes,
                                            ),
                                          ),
                                        ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          for (
                                            var index = 0;
                                            index < selectedWeek.entries.length;
                                            index++
                                          )
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                    ),
                                                child: SizedBox.expand(
                                                  child: GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onTap: () {
                                                      setState(() {
                                                        _activeBarIndex =
                                                            _activeBarIndex ==
                                                                index
                                                            ? null
                                                            : index;
                                                      });
                                                    },
                                                    onLongPressStart: (_) {
                                                      setState(() {
                                                        _activeBarIndex = index;
                                                      });
                                                    },
                                                    onLongPressEnd: (_) {
                                                      setState(() {
                                                        if (_activeBarIndex ==
                                                            index) {
                                                          _activeBarIndex =
                                                              null;
                                                        }
                                                      });
                                                    },
                                                    child: Stack(
                                                      fit: StackFit.expand,
                                                      children: [
                                                        Align(
                                                          alignment: Alignment
                                                              .bottomCenter,
                                                          child: Container(
                                                            width:
                                                                double.infinity,
                                                            height: _barHeightForMinutes(
                                                              selectedWeek
                                                                  .entries[index]
                                                                  .day
                                                                  ?.trackedMinutes,
                                                              scaleTop,
                                                              plotHeight,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  selectedWeek
                                                                          .entries[index]
                                                                          .day ==
                                                                      null
                                                                  ? appSurfaceStrong
                                                                  : _activeBarIndex ==
                                                                        index
                                                                  ? brand.withValues(
                                                                      alpha:
                                                                          0.72,
                                                                    )
                                                                  : brand,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
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
                                for (final entry in selectedWeek.entries)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: Text(
                                        _weekdayLabel(entry.date),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: appMutedText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
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
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledValue(
                  label: 'Week Total',
                  value: _formatMinutes(weekTotal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledValue(
                  label: 'Daily Average',
                  value: _formatMinutesWithSeconds(weekAverage),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyWeekSlice {
  const _DailyWeekSlice({required this.entries});

  final List<_DailyWeekEntry> entries;
}

class _DailyWeekEntry {
  const _DailyWeekEntry({required this.date, required this.day});

  final DateTime date;
  final StatisticsDailyPoint? day;
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({required this.statistics, required this.daily});

  final StatisticsSnapshot statistics;
  final List<StatisticsDailyPoint> daily;

  @override
  Widget build(BuildContext context) {
    final busiestTime = statistics.timeOfDay.isEmpty
        ? null
        : statistics.timeOfDay.reduce(
            (best, current) => current.blocks > best.blocks ? current : best,
          );
    final protection = statistics.protection;
    final blockConversionRate =
        protection.totalBlocks + protection.totalBypasses <= 0
        ? 0
        : ((protection.totalBlocks /
                      (protection.totalBlocks + protection.totalBypasses)) *
                  100)
              .round();
    final weekendDays = daily.where((day) => day.date.weekday >= 6).toList();
    final weekdayDays = daily.where((day) => day.date.weekday <= 5).toList();
    final weekendAverage = weekendDays.isEmpty
        ? 0
        : weekendDays.fold<int>(0, (sum, day) => sum + day.trackedMinutes) /
              weekendDays.length;
    final weekdayAverage = weekdayDays.isEmpty
        ? 0
        : weekdayDays.fold<int>(0, (sum, day) => sum + day.trackedMinutes) /
              weekdayDays.length;
    final totalTrackedMinutes = daily.fold<int>(
      0,
      (sum, day) => sum + day.trackedMinutes,
    );
    final appTotals = <String, int>{};
    for (final day in daily) {
      for (final entry in day.appMinutes.entries) {
        appTotals.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    final topAppMinutes = appTotals.values.isEmpty
        ? 0
        : appTotals.values.reduce(math.max);
    final topAppShare = totalTrackedMinutes <= 0
        ? 0
        : ((topAppMinutes / totalTrackedMinutes) * 100).round();
    final longestSessionMinutes = daily.isEmpty
        ? 0
        : daily
              .map((day) {
                final visibleLongestSessions = day
                    .appLongestSessionMinutes
                    .entries
                    .where((entry) => day.appMinutes.containsKey(entry.key))
                    .map((entry) => entry.value);
                if (visibleLongestSessions.isEmpty) {
                  return day.longestSessionMinutes;
                }
                return visibleLongestSessions.reduce(math.max);
              })
              .reduce(math.max);

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advanced',
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
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: _OverviewInlineMetric(
                      label: 'Longest session',
                      value: _formatMinutes(longestSessionMinutes),
                    ),
                  ),
                ),
                Container(width: 1, color: appBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                    child: _OverviewInlineMetric(
                      label: 'Peak usage hour',
                      value: busiestTime?.label ?? 'None',
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
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: _OverviewInlineMetric(
                      label: 'Block conversion',
                      value: '${_formatGroupedInt(blockConversionRate)}%',
                    ),
                  ),
                ),
                Container(width: 1, color: appBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                    child: _OverviewInlineMetric(
                      label: 'Top app share',
                      value: '${_formatGroupedInt(topAppShare)}%',
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
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: _OverviewInlineMetric(
                      label: 'Weekend Average',
                      value: _formatMinutes(weekendAverage.round()),
                    ),
                  ),
                ),
                Container(width: 1, color: appBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                    child: _OverviewInlineMetric(
                      label: 'Weekday Average',
                      value: _formatMinutes(weekdayAverage.round()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Time of day',
            style: TextStyle(
              color: appText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final bucket in statistics.timeOfDay) ...[
            _BucketRow(bucket: bucket, isHighlighted: bucket == busiestTime),
            if (bucket != statistics.timeOfDay.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AppsSection extends StatelessWidget {
  const _AppsSection({
    required this.apps,
    required this.daily,
    required this.onOpenApp,
  });

  final List<StatisticsApp> apps;
  final List<StatisticsDailyPoint> daily;
  final ValueChanged<StatisticsApp> onOpenApp;

  @override
  Widget build(BuildContext context) {
    final appsWithUsage = apps.where((app) {
      return _minutesForAppInRange(daily, app.id) > 0;
    }).toList();
    final sortedApps = [...appsWithUsage]
      ..sort((a, b) {
        final aMinutes = _minutesForAppInRange(daily, a.id);
        final bMinutes = _minutesForAppInRange(daily, b.id);
        return bMinutes.compareTo(aMinutes);
      });
    final totalVisibleMinutes = sortedApps.fold<int>(
      0,
      (sum, app) => sum + _minutesForAppInRange(daily, app.id),
    );
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              'Apps',
              style: TextStyle(
                color: brand,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (sortedApps.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _EmptyLine(label: 'No app usage for this range.'),
            )
          else
            Column(
              children: [
                for (var index = 0; index < sortedApps.length; index++) ...[
                  _AppListRow(
                    app: sortedApps[index],
                    totalMinutes: _minutesForAppInRange(
                      daily,
                      sortedApps[index].id,
                    ),
                    totalSessions: _sessionCountForAppInRange(
                      daily,
                      sortedApps[index].id,
                    ),
                    shareOfTotal: totalVisibleMinutes <= 0
                        ? 0
                        : _minutesForAppInRange(daily, sortedApps[index].id) /
                              totalVisibleMinutes,
                    onTap: () => onOpenApp(sortedApps[index]),
                  ),
                  if (index < sortedApps.length - 1)
                    const Divider(height: 1, color: appBorder),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AppListRow extends StatelessWidget {
  const _AppListRow({
    required this.app,
    required this.totalMinutes,
    required this.totalSessions,
    required this.shareOfTotal,
    required this.onTap,
  });

  final StatisticsApp app;
  final int totalMinutes;
  final int totalSessions;
  final double shareOfTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(8));
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: Ink(
        decoration: const BoxDecoration(borderRadius: borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: brand.withValues(alpha: 0.18),
          highlightColor: appText.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _AppIcon(iconBytes: app.iconBytes, label: app.appName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.appName,
                              style: const TextStyle(
                                color: appText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatGroupedInt(totalSessions)} Sessions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: appMutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                height: 7,
                                child: LinearProgressIndicator(
                                  value: shareOfTotal.clamp(0, 1),
                                  color: brand,
                                  backgroundColor: appSurfaceStrong,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatMinutes(totalMinutes),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: appText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: appMutedText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.iconBytes,
    required this.label,
    this.size = 42,
    this.borderRadius = 12,
  });

  final Uint8List? iconBytes;
  final String label;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconBytes != null
          ? Image.memory(iconBytes!, fit: BoxFit.cover)
          : Center(
              child: Text(
                label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: brand,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket, required this.isHighlighted});

  final StatisticsTimeOfDayBucket bucket;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, bucket.blocks + bucket.bypasses);
    final blockFlex = bucket.blocks;
    final remainderFlex = math.max(0, total - bucket.blocks);
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            bucket.label,
            style: TextStyle(
              color: isHighlighted ? appText : appMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                if (blockFlex > 0)
                  Expanded(
                    flex: blockFlex,
                    child: Container(height: 8, color: brand),
                  ),
                if (remainderFlex > 0)
                  Expanded(
                    flex: remainderFlex,
                    child: Container(height: 8, color: appSurfaceStrong),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${bucket.blocks}',
          style: const TextStyle(
            color: appText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: appMutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: appText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: appMutedText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

StatisticsSnapshot _buildDummyStatisticsSnapshot(
  List<CustomTrackedApp> installedApps,
) {
  final now = DateTime.now();
  final groupedInstalledApps = _groupInstalledAppsForStatistics(installedApps);
  final presentPackageNames = groupedInstalledApps
      .map((app) => app.packageName.toLowerCase())
      .toSet();
  final seededApps = [
    ...groupedInstalledApps,
    if (!presentPackageNames.contains('com.discord'))
      const CustomTrackedApp(appName: 'Discord', packageName: 'com.discord'),
    if (!presentPackageNames.contains('com.twitter.android'))
      const CustomTrackedApp(appName: 'X', packageName: 'com.twitter.android'),
  ];
  final apps = seededApps.asMap().entries.map((entry) {
    final index = entry.key;
    final app = entry.value;
    final id = _statisticsAppId(app);
    final dailyMinutes = List<int>.generate(30, (dayIndex) {
      final base = 14 + ((index + 2) * 6);
      return base + ((dayIndex * (index + 3)) % (36 + index * 8));
    });
    final weekMinutes = dailyMinutes
        .takeLast(7)
        .fold<int>(0, (sum, value) => sum + value);
    final todayMinutes = dailyMinutes.isEmpty ? 0 : dailyMinutes.last;
    final appNameLower = app.appName.toLowerCase();
    final packageLower = app.packageName.toLowerCase();
    final isInstagram = packageLower.contains('instagram');
    final isYouTube =
        packageLower.contains('youtube') || packageLower.contains('revanced');
    final isTikTok =
        packageLower.contains('musically') || appNameLower.contains('tiktok');
    final emphasis = index + 1;
    final bypasses = 2 + (index % 6);
    return StatisticsApp(
      id: id,
      appName: app.appName,
      packageName: app.packageName,
      iconBytes: app.iconBytes,
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      averageDailyMinutes7d: weekMinutes / 7,
      highestDayMinutes30d: dailyMinutes.reduce(math.max),
      launchCountToday: 3 + ((index * 2) % 10),
      launchCountWeek: 24 + (index * 9),
      longestSessionMinutes30d: 28 + (index * 7),
      reelsBlocks: isInstagram ? 24 + emphasis * 3 : 0,
      shortsBlocks: isYouTube ? 16 + emphasis * 2 : 0,
      pauseOnOpenPrompts: (isInstagram || isYouTube || isTikTok)
          ? 8 + emphasis * 2
          : 5 + emphasis,
      dailyLimitHits: 1 + (index % 5),
      bypasses: bypasses,
      bypassedMinutes: 7 + (bypasses * (3 + (index % 3))),
      dailyMinutes30d: dailyMinutes,
    );
  }).toList();

  final daily = List<StatisticsDailyPoint>.generate(30, (dayIndex) {
    final date = now.subtract(Duration(days: 29 - dayIndex));
    final appMinutes = {
      for (final app in apps) app.id: app.dailyMinutes30d[dayIndex],
    };
    final total = appMinutes.values.fold<int>(0, (sum, value) => sum + value);
    return StatisticsDailyPoint(
      dateKey: _dateKey(date),
      trackedMinutes: total,
      blocks: 4 + (dayIndex % 9),
      bypasses: 1 + (dayIndex % 4),
      reelsBlocks: dayIndex % 3,
      shortsBlocks: dayIndex % 2,
      websiteBlocks: dayIndex % 2,
      pauseOnOpenPrompts: 2 + (dayIndex % 4),
      dailyLimitHits: dayIndex % 3,
      shortFormBypasses: dayIndex % 2,
      websiteBypasses: dayIndex % 3 == 0 ? 1 : 0,
      pauseOnOpenBypasses: dayIndex % 4 == 0 ? 1 : 0,
      dailyLimitBypasses: dayIndex % 5 == 0 ? 1 : 0,
      sessionCount: 9 + (dayIndex % 6),
      longestSessionMinutes: 18 + (dayIndex % 14),
      appMinutes: appMinutes,
      appSessionCounts: {
        for (final app in apps)
          app.id: math.max(1, ((app.dailyMinutes30d[dayIndex]) / 22).round()),
      },
      appLongestSessionMinutes: {
        for (final app in apps)
          app.id: math.max(4, ((app.dailyMinutes30d[dayIndex]) / 3).round()),
      },
      appReelsBlocks: {
        for (final app in apps)
          app.id: app.packageName.toLowerCase().contains('instagram')
              ? dayIndex % 3
              : 0,
      },
      appShortsBlocks: {
        for (final app in apps)
          app.id: app.packageName.toLowerCase().contains('youtube')
              ? dayIndex % 2
              : 0,
      },
      appPauseOnOpenPrompts: {
        for (final app in apps) app.id: (dayIndex + app.id.length) % 2,
      },
      appDailyLimitHits: {
        for (final app in apps)
          app.id: (dayIndex + app.id.length) % 3 == 0 ? 1 : 0,
      },
      appBypasses: {
        for (final app in apps)
          app.id: (dayIndex + app.id.length) % 4 == 0 ? 1 : 0,
      },
      appBypassedMinutes: {
        for (final app in apps)
          app.id: (dayIndex + app.id.length) % 4 == 0 ? 5 + (dayIndex % 6) : 0,
      },
      timeOfDayBlocks: {
        'Morning': dayIndex % 2,
        'Afternoon': 1 + (dayIndex % 3),
        'Evening': 2 + (dayIndex % 4),
        'Late Night': dayIndex % 2,
      },
      timeOfDayBypasses: {
        'Morning': dayIndex % 3 == 0 ? 1 : 0,
        'Afternoon': dayIndex % 4 == 0 ? 1 : 0,
        'Evening': dayIndex % 2,
        'Late Night': dayIndex % 5 == 0 ? 1 : 0,
      },
    );
  });

  final mostUsedApp = apps.isEmpty
      ? null
      : apps.reduce((best, current) {
          return current.todayMinutes > best.todayMinutes ? current : best;
        });
  final weekTrackedMinutes = daily
      .takeLast(7)
      .fold<int>(0, (sum, day) => sum + day.trackedMinutes);
  final todayTrackedMinutes = daily.isEmpty ? 0 : daily.last.trackedMinutes;
  final totalReels = apps.fold<int>(0, (sum, app) => sum + app.reelsBlocks);
  final totalShorts = apps.fold<int>(0, (sum, app) => sum + app.shortsBlocks);
  final totalPauseOnOpen = apps.fold<int>(
    0,
    (sum, app) => sum + app.pauseOnOpenPrompts,
  );
  final totalDailyLimitHits = apps.fold<int>(
    0,
    (sum, app) => sum + app.dailyLimitHits,
  );
  final totalBypasses = apps.fold<int>(0, (sum, app) => sum + app.bypasses);
  final topDomains = [
    'instagram.com',
    'youtube.com',
    'reddit.com',
    'x.com',
    'news.ycombinator.com',
    'tiktok.com',
  ];
  final websites = List<StatisticsWebsite>.generate(
    math.min(topDomains.length, math.max(2, apps.length + 1)),
    (index) => StatisticsWebsite(
      domain: topDomains[index],
      blocks: 3 + (index * 2),
      bypasses: index % 3,
    ),
  );

  return StatisticsSnapshot(
    generatedAt: now,
    overview: StatisticsOverview(
      todayTrackedMinutes: todayTrackedMinutes,
      weekTrackedMinutes: weekTrackedMinutes,
      averageDailyTrackedMinutes7d: weekTrackedMinutes / 7,
      todayBlocks: daily.isEmpty ? 0 : daily.last.blocks,
      todayBypasses: daily.isEmpty ? 0 : daily.last.bypasses,
      todayBypassMinutes: 11 + apps.length * 2,
      weekBypassMinutes: 54 + apps.length * 7,
      todayLimitOverageMinutes: 8 + apps.length,
      weekLimitOverageMinutes: 33 + apps.length * 5,
      currentStreak: 6,
      longestStreak: 19,
      mostUsedAppName: mostUsedApp?.appName ?? '',
      mostUsedAppMinutes: mostUsedApp?.todayMinutes ?? 0,
      blockedWebsitesCount: websites.length,
    ),
    daily: daily,
    protection: StatisticsProtection(
      reelsBlocks: totalReels,
      shortsBlocks: totalShorts,
      websiteBlocks: websites.fold<int>(0, (sum, site) => sum + site.blocks),
      pauseOnOpenPrompts: totalPauseOnOpen,
      dailyLimitHits: totalDailyLimitHits,
      totalBlocks:
          totalReels +
          totalShorts +
          totalPauseOnOpen +
          totalDailyLimitHits +
          websites.fold<int>(0, (sum, site) => sum + site.blocks),
      shortFormBypasses: 12 + apps.length * 3,
      websiteBypasses: websites.fold<int>(
        0,
        (sum, site) => sum + site.bypasses,
      ),
      pauseOnOpenBypasses: 9 + apps.length * 2,
      dailyLimitBypasses: 4 + apps.length,
      totalBypasses: totalBypasses + 21,
    ),
    timeOfDay: const [
      StatisticsTimeOfDayBucket(label: 'Morning', blocks: 18, bypasses: 6),
      StatisticsTimeOfDayBucket(label: 'Afternoon', blocks: 27, bypasses: 11),
      StatisticsTimeOfDayBucket(label: 'Evening', blocks: 61, bypasses: 28),
      StatisticsTimeOfDayBucket(label: 'Late Night', blocks: 49, bypasses: 13),
    ],
    apps: apps,
    websites: websites,
  );
}

StatisticsSnapshot _statisticsSnapshotForDisplay(
  StatisticsSnapshot? nativeSnapshot,
  List<CustomTrackedApp> installedApps,
) {
  if (nativeSnapshot == null) {
    return _buildDummyStatisticsSnapshot(installedApps);
  }

  final groupedInstalledApps = _groupInstalledAppsForStatistics(installedApps);
  final installedById = {
    for (final app in groupedInstalledApps) _statisticsAppId(app): app,
  };

  final mergedApps = nativeSnapshot.apps
      .where((app) => installedById.containsKey(app.id))
      .map((app) {
        final installedApp = installedById[app.id];
        return StatisticsApp(
          id: app.id,
          appName: installedApp?.appName ?? app.appName,
          packageName: installedApp?.packageName ?? app.packageName,
          iconBytes: installedApp?.iconBytes,
          todayMinutes: app.todayMinutes,
          weekMinutes: app.weekMinutes,
          averageDailyMinutes7d: app.averageDailyMinutes7d,
          highestDayMinutes30d: app.highestDayMinutes30d,
          launchCountToday: app.launchCountToday,
          launchCountWeek: app.launchCountWeek,
          longestSessionMinutes30d: app.longestSessionMinutes30d,
          reelsBlocks: app.reelsBlocks,
          shortsBlocks: app.shortsBlocks,
          pauseOnOpenPrompts: app.pauseOnOpenPrompts,
          dailyLimitHits: app.dailyLimitHits,
          bypasses: app.bypasses,
          bypassedMinutes: app.bypassedMinutes,
          dailyMinutes30d: app.dailyMinutes30d,
        );
      })
      .where((app) => _minutesForAppInRange(nativeSnapshot.daily, app.id) > 0)
      .toList();

  return StatisticsSnapshot(
    generatedAt: nativeSnapshot.generatedAt,
    overview: nativeSnapshot.overview,
    daily: nativeSnapshot.daily,
    protection: nativeSnapshot.protection,
    timeOfDay: nativeSnapshot.timeOfDay,
    apps: mergedApps,
    websites: nativeSnapshot.websites,
  );
}

List<CustomTrackedApp> _groupInstalledAppsForStatistics(
  List<CustomTrackedApp> installedApps,
) {
  final groupedApps = <String, CustomTrackedApp>{};
  for (final app in installedApps) {
    final groupId = _statisticsAppId(app);
    groupedApps.putIfAbsent(groupId, () => app);
  }
  return groupedApps.values.toList();
}

String _statisticsAppId(CustomTrackedApp app) {
  final packageLower = app.packageName.toLowerCase();
  if (packageLower == 'com.google.android.youtube' ||
      packageLower.startsWith('app.revanced.android.youtube')) {
    return 'youtube';
  }
  if (packageLower == 'com.instagram.android') {
    return 'instagram';
  }
  return app.packageName;
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatGroupedInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  final formatted = buffer.toString();
  return value < 0 ? '-$formatted' : formatted;
}

String _formatGroupedDouble(double value, {int decimalPlaces = 1}) {
  final fixed = value.toStringAsFixed(decimalPlaces);
  final parts = fixed.split('.');
  final whole = _formatGroupedInt(int.tryParse(parts.first) ?? 0);
  if (parts.length == 1) return whole;

  final fraction = parts.last;
  if (int.tryParse(fraction) == 0) {
    return whole;
  }
  return '$whole.$fraction';
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours <= 0) return '${_formatGroupedInt(minutes)}m';
  if (remainder == 0) return '${_formatGroupedInt(hours)}h';
  return '${_formatGroupedInt(hours)}h ${_formatGroupedInt(remainder)}m';
}

String _weekdayLabel(DateTime date) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[date.weekday - 1];
}

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

List<_DailyWeekSlice> _buildDailyWeekSlices(List<StatisticsDailyPoint> daily) {
  if (daily.isEmpty) return const <_DailyWeekSlice>[];

  final daysByKey = {for (final day in daily) day.dateKey: day};
  final earliestDate = daily.first.date;
  final latestDate = daily.last.date;
  final firstWeekStart = earliestDate.subtract(
    Duration(days: earliestDate.weekday - 1),
  );
  final lastWeekEnd = latestDate.add(Duration(days: 7 - latestDate.weekday));
  final slices = <_DailyWeekSlice>[];
  for (
    var weekStart = firstWeekStart;
    !weekStart.isAfter(lastWeekEnd);
    weekStart = weekStart.add(const Duration(days: 7))
  ) {
    final entries = List<_DailyWeekEntry>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return _DailyWeekEntry(date: date, day: daysByKey[_dateKey(date)]);
    });
    slices.add(_DailyWeekSlice(entries: entries));
  }
  return slices;
}

List<StatisticsDailyPoint> _filterDailyByAppIds(
  List<StatisticsDailyPoint> daily,
  Set<String> appIds,
) {
  if (appIds.isEmpty) {
    return daily
        .map(
          (day) => StatisticsDailyPoint(
            dateKey: day.dateKey,
            trackedMinutes: 0,
            blocks: day.blocks,
            bypasses: day.bypasses,
            reelsBlocks: day.reelsBlocks,
            shortsBlocks: day.shortsBlocks,
            websiteBlocks: day.websiteBlocks,
            pauseOnOpenPrompts: day.pauseOnOpenPrompts,
            dailyLimitHits: day.dailyLimitHits,
            shortFormBypasses: day.shortFormBypasses,
            websiteBypasses: day.websiteBypasses,
            pauseOnOpenBypasses: day.pauseOnOpenBypasses,
            dailyLimitBypasses: day.dailyLimitBypasses,
            sessionCount: 0,
            longestSessionMinutes: 0,
            appMinutes: const <String, int>{},
            appSessionCounts: const <String, int>{},
            appLongestSessionMinutes: const <String, int>{},
            appReelsBlocks: const <String, int>{},
            appShortsBlocks: const <String, int>{},
            appPauseOnOpenPrompts: const <String, int>{},
            appDailyLimitHits: const <String, int>{},
            appBypasses: const <String, int>{},
            appBypassedMinutes: const <String, int>{},
            timeOfDayBlocks: day.timeOfDayBlocks,
            timeOfDayBypasses: day.timeOfDayBypasses,
          ),
        )
        .toList();
  }

  return daily.map((day) {
    final filteredAppMinutes = <String, int>{
      for (final entry in day.appMinutes.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppSessionCounts = <String, int>{
      for (final entry in day.appSessionCounts.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppLongestSessionMinutes = <String, int>{
      for (final entry in day.appLongestSessionMinutes.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppReelsBlocks = <String, int>{
      for (final entry in day.appReelsBlocks.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppShortsBlocks = <String, int>{
      for (final entry in day.appShortsBlocks.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppPauseOnOpenPrompts = <String, int>{
      for (final entry in day.appPauseOnOpenPrompts.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppDailyLimitHits = <String, int>{
      for (final entry in day.appDailyLimitHits.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppBypasses = <String, int>{
      for (final entry in day.appBypasses.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredAppBypassedMinutes = <String, int>{
      for (final entry in day.appBypassedMinutes.entries)
        if (appIds.contains(entry.key)) entry.key: entry.value,
    };
    return StatisticsDailyPoint(
      dateKey: day.dateKey,
      trackedMinutes: filteredAppMinutes.values.fold<int>(
        0,
        (sum, value) => sum + value,
      ),
      blocks: day.blocks,
      bypasses: day.bypasses,
      reelsBlocks: day.reelsBlocks,
      shortsBlocks: day.shortsBlocks,
      websiteBlocks: day.websiteBlocks,
      pauseOnOpenPrompts: day.pauseOnOpenPrompts,
      dailyLimitHits: day.dailyLimitHits,
      shortFormBypasses: day.shortFormBypasses,
      websiteBypasses: day.websiteBypasses,
      pauseOnOpenBypasses: day.pauseOnOpenBypasses,
      dailyLimitBypasses: day.dailyLimitBypasses,
      sessionCount: filteredAppSessionCounts.values.fold<int>(
        0,
        (sum, value) => sum + value,
      ),
      longestSessionMinutes: filteredAppLongestSessionMinutes.values.isEmpty
          ? 0
          : filteredAppLongestSessionMinutes.values.reduce(math.max),
      appMinutes: filteredAppMinutes,
      appSessionCounts: filteredAppSessionCounts,
      appLongestSessionMinutes: filteredAppLongestSessionMinutes,
      appReelsBlocks: filteredAppReelsBlocks,
      appShortsBlocks: filteredAppShortsBlocks,
      appPauseOnOpenPrompts: filteredAppPauseOnOpenPrompts,
      appDailyLimitHits: filteredAppDailyLimitHits,
      appBypasses: filteredAppBypasses,
      appBypassedMinutes: filteredAppBypassedMinutes,
      timeOfDayBlocks: day.timeOfDayBlocks,
      timeOfDayBypasses: day.timeOfDayBypasses,
    );
  }).toList();
}

bool _isBlockedStatisticsApp(StatisticsApp app) {
  return _protectionKind(app) != null;
}

int _minutesForAppInRange(List<StatisticsDailyPoint> daily, String appId) {
  return daily.fold<int>(0, (sum, day) => sum + (day.appMinutes[appId] ?? 0));
}

int _sessionCountForAppInRange(List<StatisticsDailyPoint> daily, String appId) {
  return daily.fold<int>(
    0,
    (sum, day) => sum + (day.appSessionCounts[appId] ?? 0),
  );
}

List<StatisticsDailyPoint> _previousStatisticsDaily(
  List<StatisticsDailyPoint> daily,
  _AppDateRangePreset preset,
  DateTimeRange? customDateRange,
) {
  final bounds = _statisticsRangeBounds(preset, customDateRange);
  if (bounds == null) return const <StatisticsDailyPoint>[];
  final rangeLength = bounds.end.difference(bounds.start).inDays + 1;
  final previousEnd = bounds.start.subtract(const Duration(days: 1));
  final previousStart = previousEnd.subtract(Duration(days: rangeLength - 1));
  return daily.where((day) {
    final date = DateTime(day.date.year, day.date.month, day.date.day);
    return !date.isBefore(previousStart) && !date.isAfter(previousEnd);
  }).toList();
}

DateTimeRange? _statisticsRangeBounds(
  _AppDateRangePreset preset,
  DateTimeRange? customDateRange,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (preset) {
    case _AppDateRangePreset.today:
      return DateTimeRange(start: today, end: today);
    case _AppDateRangePreset.yesterday:
      final day = today.subtract(const Duration(days: 1));
      return DateTimeRange(start: day, end: day);
    case _AppDateRangePreset.last7Days:
      return DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      );
    case _AppDateRangePreset.lastMonth:
      return DateTimeRange(
        start: today.subtract(const Duration(days: 27)),
        end: today,
      );
    case _AppDateRangePreset.last365Days:
      return DateTimeRange(
        start: today.subtract(const Duration(days: 364)),
        end: today,
      );
    case _AppDateRangePreset.custom:
      if (customDateRange == null) return null;
      return DateTimeRange(
        start: DateTime(
          customDateRange.start.year,
          customDateRange.start.month,
          customDateRange.start.day,
        ),
        end: DateTime(
          customDateRange.end.year,
          customDateRange.end.month,
          customDateRange.end.day,
        ),
      );
  }
}

_MetricDelta? _buildMetricDelta({
  required double currentValue,
  required double previousValue,
}) {
  if (currentValue == 0 && previousValue == 0) return null;
  if (currentValue == previousValue) {
    return const _MetricDelta(
      label: '0%',
      isIncrease: false,
      color: appMutedText,
    );
  }
  final isIncrease = currentValue > previousValue;
  final percent = previousValue <= 0
      ? 100
      : (((currentValue - previousValue).abs() / previousValue) * 100).round();
  return _MetricDelta(
    label: '${_formatGroupedInt(percent)}%',
    isIncrease: isIncrease,
    color: isIncrease ? const Color(0xFFC65A43) : const Color(0xFF3E9B55),
  );
}

class _MetricDelta {
  const _MetricDelta({
    required this.label,
    required this.isIncrease,
    required this.color,
  });

  final String label;
  final bool isIncrease;
  final Color color;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse('$value') ?? 0;
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

extension _TakeLastExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count <= 0) return <T>[];
    if (length <= count) return List<T>.from(this);
    return sublist(length - count);
  }
}
