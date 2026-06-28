import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../tabs/statistics_tab.dart';

class StatisticsHistoryStore {
  static const _storageKey = 'statistics_history_v1';
  static const _maxStoredDays = 400;

  const StatisticsHistoryStore();

  Future<StatisticsSnapshot?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = prefs.getString(_storageKey);
    if (serialized == null || serialized.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! Map) return null;
      return StatisticsSnapshot.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<StatisticsSnapshot> mergeAndSave(StatisticsSnapshot freshSnapshot) async {
    final storedSnapshot = await loadSnapshot();
    final mergedSnapshot = _mergeSnapshots(storedSnapshot, freshSnapshot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_snapshotToMap(mergedSnapshot)));
    return mergedSnapshot;
  }

  StatisticsSnapshot _mergeSnapshots(
    StatisticsSnapshot? storedSnapshot,
    StatisticsSnapshot freshSnapshot,
  ) {
    final mergedDaily = _mergeDaily(storedSnapshot?.daily ?? const [], freshSnapshot.daily);
    final mergedApps = _buildApps(
      mergedDaily: mergedDaily,
      generatedAt: freshSnapshot.generatedAt,
      previousApps: storedSnapshot?.apps ?? const [],
      latestApps: freshSnapshot.apps,
    );
    final overview = _buildOverview(
      daily: mergedDaily,
      apps: mergedApps,
      generatedAt: freshSnapshot.generatedAt,
      fallback: freshSnapshot.overview,
    );

    return StatisticsSnapshot(
      generatedAt: freshSnapshot.generatedAt,
      overview: overview,
      daily: mergedDaily,
      protection: _buildProtection(mergedDaily),
      timeOfDay: _buildTimeOfDay(mergedDaily),
      apps: mergedApps,
      websites: freshSnapshot.websites,
    );
  }

  List<StatisticsDailyPoint> _mergeDaily(
    List<StatisticsDailyPoint> stored,
    List<StatisticsDailyPoint> fresh,
  ) {
    final mergedByDate = <String, StatisticsDailyPoint>{
      for (final day in stored) day.dateKey: day,
    };
    for (final day in fresh) {
      mergedByDate[day.dateKey] = day;
    }

    final merged = mergedByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (merged.length <= _maxStoredDays) {
      return merged;
    }
    return merged.sublist(merged.length - _maxStoredDays);
  }

  StatisticsOverview _buildOverview({
    required List<StatisticsDailyPoint> daily,
    required List<StatisticsApp> apps,
    required DateTime generatedAt,
    required StatisticsOverview fallback,
  }) {
    final byDateKey = {for (final day in daily) day.dateKey: day};
    final todayKey = _dateKey(generatedAt);
    final today = byDateKey[todayKey];
    final last7 = _daysForRange(daily, generatedAt, 7);
    final todayTrackedMinutes = today?.trackedMinutes ?? 0;
    final weekTrackedMinutes = last7.fold<int>(
      0,
      (sum, day) => sum + (day?.trackedMinutes ?? 0),
    );
    final todayBypassMinutes =
        today?.appBypassedMinutes.values.fold<int>(0, (sum, value) => sum + value) ?? 0;
    final weekBypassMinutes = last7.fold<int>(
      0,
      (sum, day) =>
          sum + (day?.appBypassedMinutes.values.fold<int>(0, (inner, value) => inner + value) ?? 0),
    );
    final mostUsedTodayApp = apps.fold<StatisticsApp?>(
      null,
      (best, app) => best == null || app.todayMinutes > best.todayMinutes ? app : best,
    );

    return StatisticsOverview(
      todayTrackedMinutes: todayTrackedMinutes,
      weekTrackedMinutes: weekTrackedMinutes,
      averageDailyTrackedMinutes7d: weekTrackedMinutes / 7,
      todayBlocks: today?.blocks ?? 0,
      todayBypasses: today?.bypasses ?? 0,
      todayBypassMinutes: todayBypassMinutes,
      weekBypassMinutes: weekBypassMinutes,
      todayLimitOverageMinutes: fallback.todayLimitOverageMinutes,
      weekLimitOverageMinutes: fallback.weekLimitOverageMinutes,
      currentStreak: fallback.currentStreak,
      longestStreak: fallback.longestStreak,
      mostUsedAppName: mostUsedTodayApp?.appName ?? fallback.mostUsedAppName,
      mostUsedAppMinutes: mostUsedTodayApp?.todayMinutes ?? fallback.mostUsedAppMinutes,
      blockedWebsitesCount: fallback.blockedWebsitesCount,
    );
  }

  StatisticsProtection _buildProtection(List<StatisticsDailyPoint> daily) {
    return StatisticsProtection(
      reelsBlocks: daily.fold<int>(0, (sum, day) => sum + day.reelsBlocks),
      shortsBlocks: daily.fold<int>(0, (sum, day) => sum + day.shortsBlocks),
      websiteBlocks: daily.fold<int>(0, (sum, day) => sum + day.websiteBlocks),
      pauseOnOpenPrompts: daily.fold<int>(
        0,
        (sum, day) => sum + day.pauseOnOpenPrompts,
      ),
      dailyLimitHits: daily.fold<int>(0, (sum, day) => sum + day.dailyLimitHits),
      totalBlocks: daily.fold<int>(0, (sum, day) => sum + day.blocks),
      shortFormBypasses: daily.fold<int>(
        0,
        (sum, day) => sum + day.shortFormBypasses,
      ),
      websiteBypasses: daily.fold<int>(
        0,
        (sum, day) => sum + day.websiteBypasses,
      ),
      pauseOnOpenBypasses: daily.fold<int>(
        0,
        (sum, day) => sum + day.pauseOnOpenBypasses,
      ),
      dailyLimitBypasses: daily.fold<int>(
        0,
        (sum, day) => sum + day.dailyLimitBypasses,
      ),
      totalBypasses: daily.fold<int>(0, (sum, day) => sum + day.bypasses),
    );
  }

  List<StatisticsTimeOfDayBucket> _buildTimeOfDay(
    List<StatisticsDailyPoint> daily,
  ) {
    const labels = ['Morning', 'Afternoon', 'Evening', 'Late Night'];
    return labels.map((label) {
      final blocks = daily.fold<int>(
        0,
        (sum, day) => sum + (day.timeOfDayBlocks[label] ?? 0),
      );
      final bypasses = daily.fold<int>(
        0,
        (sum, day) => sum + (day.timeOfDayBypasses[label] ?? 0),
      );
      return StatisticsTimeOfDayBucket(
        label: label,
        blocks: blocks,
        bypasses: bypasses,
      );
    }).toList();
  }

  List<StatisticsApp> _buildApps({
    required List<StatisticsDailyPoint> mergedDaily,
    required DateTime generatedAt,
    required List<StatisticsApp> previousApps,
    required List<StatisticsApp> latestApps,
  }) {
    final metadataById = <String, StatisticsApp>{
      for (final app in previousApps) app.id: app,
      for (final app in latestApps) app.id: app,
    };
    final allAppIds = <String>{
      ...metadataById.keys,
      for (final day in mergedDaily) ...day.appMinutes.keys,
    };
    final last7 = _daysForRange(mergedDaily, generatedAt, 7);
    final last30 = _daysForRange(mergedDaily, generatedAt, 30);
    final today = _dayForDate(mergedDaily, generatedAt);

    final apps = allAppIds.map((appId) {
      final metadata = metadataById[appId];
      final daySeries30 = last30
          .map((day) => day?.appMinutes[appId] ?? 0)
          .toList(growable: false);
      return StatisticsApp(
        id: appId,
        appName: metadata?.appName.isNotEmpty == true ? metadata!.appName : appId,
        packageName: metadata?.packageName.isNotEmpty == true
            ? metadata!.packageName
            : appId,
        iconBytes: null,
        todayMinutes: today?.appMinutes[appId] ?? 0,
        weekMinutes: last7.fold<int>(
          0,
          (sum, day) => sum + (day?.appMinutes[appId] ?? 0),
        ),
        averageDailyMinutes7d: last7.fold<int>(
              0,
              (sum, day) => sum + (day?.appMinutes[appId] ?? 0),
            ) /
            7,
        highestDayMinutes30d: daySeries30.fold<int>(
          0,
          (maxValue, minutes) => minutes > maxValue ? minutes : maxValue,
        ),
        launchCountToday: today?.appSessionCounts[appId] ?? 0,
        launchCountWeek: last7.fold<int>(
          0,
          (sum, day) => sum + (day?.appSessionCounts[appId] ?? 0),
        ),
        longestSessionMinutes30d: last30.fold<int>(
          0,
          (maxValue, day) {
            final minutes = day?.appLongestSessionMinutes[appId] ?? 0;
            return minutes > maxValue ? minutes : maxValue;
          },
        ),
        reelsBlocks: mergedDaily.fold<int>(
          0,
          (sum, day) => sum + (day.appReelsBlocks[appId] ?? 0),
        ),
        shortsBlocks: mergedDaily.fold<int>(
          0,
          (sum, day) => sum + (day.appShortsBlocks[appId] ?? 0),
        ),
        pauseOnOpenPrompts: mergedDaily.fold<int>(
          0,
          (sum, day) => sum + (day.appPauseOnOpenPrompts[appId] ?? 0),
        ),
        dailyLimitHits: mergedDaily.fold<int>(
          0,
          (sum, day) => sum + (day.appDailyLimitHits[appId] ?? 0),
        ),
        bypasses: mergedDaily.fold<int>(
          0,
          (sum, day) => sum + (day.appBypasses[appId] ?? 0),
        ),
        bypassedMinutes: mergedDaily.fold<int>(
          0,
          (sum, day) => sum + (day.appBypassedMinutes[appId] ?? 0),
        ),
        dailyMinutes30d: daySeries30,
      );
    }).where((app) {
      return mergedDaily.fold<int>(
            0,
            (sum, day) => sum + (day.appMinutes[app.id] ?? 0),
          ) >
          0;
    }).toList()
      ..sort((a, b) => b.weekMinutes.compareTo(a.weekMinutes));

    return apps;
  }

  List<StatisticsDailyPoint?> _daysForRange(
    List<StatisticsDailyPoint> daily,
    DateTime endDate,
    int dayCount,
  ) {
    final byDateKey = {for (final day in daily) day.dateKey: day};
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
    return List<StatisticsDailyPoint?>.generate(dayCount, (index) {
      final date = normalizedEnd.subtract(Duration(days: dayCount - 1 - index));
      return byDateKey[_dateKey(date)];
    });
  }

  StatisticsDailyPoint? _dayForDate(
    List<StatisticsDailyPoint> daily,
    DateTime date,
  ) {
    final targetKey = _dateKey(date);
    for (final day in daily) {
      if (day.dateKey == targetKey) {
        return day;
      }
    }
    return null;
  }

  Map<String, dynamic> _snapshotToMap(StatisticsSnapshot snapshot) {
    return {
      'generatedAtMillis': snapshot.generatedAt.millisecondsSinceEpoch,
      'overview': {
        'todayTrackedMinutes': snapshot.overview.todayTrackedMinutes,
        'weekTrackedMinutes': snapshot.overview.weekTrackedMinutes,
        'averageDailyTrackedMinutes7d':
            snapshot.overview.averageDailyTrackedMinutes7d,
        'todayBlocks': snapshot.overview.todayBlocks,
        'todayBypasses': snapshot.overview.todayBypasses,
        'todayBypassMinutes': snapshot.overview.todayBypassMinutes,
        'weekBypassMinutes': snapshot.overview.weekBypassMinutes,
        'todayLimitOverageMinutes': snapshot.overview.todayLimitOverageMinutes,
        'weekLimitOverageMinutes': snapshot.overview.weekLimitOverageMinutes,
        'currentStreak': snapshot.overview.currentStreak,
        'longestStreak': snapshot.overview.longestStreak,
        'mostUsedAppName': snapshot.overview.mostUsedAppName,
        'mostUsedAppMinutes': snapshot.overview.mostUsedAppMinutes,
        'blockedWebsitesCount': snapshot.overview.blockedWebsitesCount,
      },
      'daily': snapshot.daily.map(_dailyToMap).toList(growable: false),
      'protection': {
        'reelsBlocks': snapshot.protection.reelsBlocks,
        'shortsBlocks': snapshot.protection.shortsBlocks,
        'websiteBlocks': snapshot.protection.websiteBlocks,
        'pauseOnOpenPrompts': snapshot.protection.pauseOnOpenPrompts,
        'dailyLimitHits': snapshot.protection.dailyLimitHits,
        'totalBlocks': snapshot.protection.totalBlocks,
        'shortFormBypasses': snapshot.protection.shortFormBypasses,
        'websiteBypasses': snapshot.protection.websiteBypasses,
        'pauseOnOpenBypasses': snapshot.protection.pauseOnOpenBypasses,
        'dailyLimitBypasses': snapshot.protection.dailyLimitBypasses,
        'totalBypasses': snapshot.protection.totalBypasses,
      },
      'timeOfDay': snapshot.timeOfDay
          .map(
            (bucket) => {
              'label': bucket.label,
              'blocks': bucket.blocks,
              'bypasses': bucket.bypasses,
            },
          )
          .toList(growable: false),
      'apps': snapshot.apps
          .map(
            (app) => {
              'id': app.id,
              'appName': app.appName,
              'packageName': app.packageName,
              'todayMinutes': app.todayMinutes,
              'weekMinutes': app.weekMinutes,
              'averageDailyMinutes7d': app.averageDailyMinutes7d,
              'highestDayMinutes30d': app.highestDayMinutes30d,
              'launchCountToday': app.launchCountToday,
              'launchCountWeek': app.launchCountWeek,
              'longestSessionMinutes30d': app.longestSessionMinutes30d,
              'reelsBlocks': app.reelsBlocks,
              'shortsBlocks': app.shortsBlocks,
              'pauseOnOpenPrompts': app.pauseOnOpenPrompts,
              'dailyLimitHits': app.dailyLimitHits,
              'bypasses': app.bypasses,
              'bypassedMinutes': app.bypassedMinutes,
              'dailyMinutes30d': app.dailyMinutes30d,
            },
          )
          .toList(growable: false),
      'websites': snapshot.websites
          .map(
            (website) => {
              'domain': website.domain,
              'blocks': website.blocks,
              'bypasses': website.bypasses,
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _dailyToMap(StatisticsDailyPoint day) {
    return {
      'dateKey': day.dateKey,
      'trackedMinutes': day.trackedMinutes,
      'blocks': day.blocks,
      'bypasses': day.bypasses,
      'reelsBlocks': day.reelsBlocks,
      'shortsBlocks': day.shortsBlocks,
      'websiteBlocks': day.websiteBlocks,
      'pauseOnOpenPrompts': day.pauseOnOpenPrompts,
      'dailyLimitHits': day.dailyLimitHits,
      'shortFormBypasses': day.shortFormBypasses,
      'websiteBypasses': day.websiteBypasses,
      'pauseOnOpenBypasses': day.pauseOnOpenBypasses,
      'dailyLimitBypasses': day.dailyLimitBypasses,
      'sessionCount': day.sessionCount,
      'longestSessionMinutes': day.longestSessionMinutes,
      'appMinutes': day.appMinutes,
      'appSessionCounts': day.appSessionCounts,
      'appLongestSessionMinutes': day.appLongestSessionMinutes,
      'appReelsBlocks': day.appReelsBlocks,
      'appShortsBlocks': day.appShortsBlocks,
      'appPauseOnOpenPrompts': day.appPauseOnOpenPrompts,
      'appDailyLimitHits': day.appDailyLimitHits,
      'appBypasses': day.appBypasses,
      'appBypassedMinutes': day.appBypassedMinutes,
      'timeOfDayBlocks': day.timeOfDayBlocks,
      'timeOfDayBypasses': day.timeOfDayBypasses,
    };
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
