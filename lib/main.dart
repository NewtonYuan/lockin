import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';
import 'onboarding.dart';
import 'tabs/block_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/statistics_tab.dart';
import 'widgets/days_tracker_calendar.dart';

void main() {
  runApp(const MyApp());
}

const _trackedUsageApps = [
  _TrackedUsageApp(
    appName: 'Instagram',
    packageNames: ['com.instagram.android'],
    color: Color(0xFF00688F),
  ),
  _TrackedUsageApp(
    appName: 'YouTube',
    packageNames: ['com.google.android.youtube'],
    packagePrefixes: ['app.revanced.android.youtube'],
    color: Color(0xFF2784A3),
  ),
];

class _TrackedUsageApp {
  const _TrackedUsageApp({
    required this.appName,
    required this.packageNames,
    this.packagePrefixes = const [],
    required this.color,
  });

  final String appName;
  final List<String> packageNames;
  final List<String> packagePrefixes;
  final Color color;
}

class _CustomUsageApp {
  const _CustomUsageApp({
    required this.appName,
    required this.packageName,
    required this.color,
  });

  final String appName;
  final String packageName;
  final Color color;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tempus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _accessibilityChannel = MethodChannel('tempus/accessibility');
  static const _navFadeDuration = Duration(milliseconds: 150);

  int _selectedIndex = 0;
  late final PageController _pageController;
  double _pageOpacity = 1;
  bool _isFadingBetweenTabs = false;
  bool? _isAccessibilityEnabled;
  bool? _isUsageAccessEnabled;
  bool _bypassAccessibilityGate = false;
  bool _hasCompletedOnboarding = false;
  bool _hasLoadedOnboardingState = false;
  bool _allowOnboardingBackNavigation = false;
  OnboardingStep _onboardingStep = OnboardingStep.intro;
  DateTime _trackerMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _appInstalledOn = DateTime.now();
  List<AppUsageSegment> _usageSegments = const [];
  final Map<String, ScrollDayStatus> _scrollDayStatuses = {};
  Set<String>? _installedTrackedPackages;
  List<CustomTrackedApp> _customTrackedApps = const [];
  final List<BlockedWebsiteEntry> _blockedWebsites = [];
  String _blockCategory = 'Apps';
  final Set<String> _expandedApps = {};
  final Map<String, int?> _dailyTimeLimits = {
    'instagram_app': null,
    'youtube_app': null,
  };
  final Map<String, bool> _blockSettings = {
    'instagram_pause_on_open': false,
    'instagram_reels': false,
    'instagram_reels_dms': false,
    'instagram_explore': false,
    'youtube_pause_on_open': false,
    'youtube_shorts': false,
    'youtube_home_feed': false,
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccessibilityStatus();
    _refreshUsageAccessStatus();
    _loadOnboardingState();
    _loadSavedBlockConfig();
    _refreshInstalledTrackedPackages();
    _refreshUsageStats();
    _loadAppInstallDate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeSharedWebsite();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAccessibilityStatus();
      _refreshUsageAccessStatus();
      _refreshInstalledTrackedPackages();
      _refreshUsageStats();
      _consumeSharedWebsite();
    }
  }

  Future<void> _refreshAccessibilityStatus() async {
    try {
      final previousValue = _isAccessibilityEnabled;
      final enabled = await _accessibilityChannel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      if (!mounted) return;
      setState(() {
        _isAccessibilityEnabled = enabled ?? false;
        if (_isAccessibilityEnabled == true) {
          _bypassAccessibilityGate = false;
          if (previousValue == false) {
            _allowOnboardingBackNavigation = false;
            _onboardingStep = OnboardingStep.accessibilityGoodStuff;
          }
        }
      });
      await _consumeAccessibilityEnabledSuccess();
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _isAccessibilityEnabled = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _isAccessibilityEnabled = false;
      });
    }
  }

  Future<void> _consumeAccessibilityEnabledSuccess() async {
    try {
      final shouldShow = await _accessibilityChannel.invokeMethod<bool>(
        'consumeAccessibilityEnabledSuccess',
      );
      if (!mounted || shouldShow != true) return;
      setState(() {
        _allowOnboardingBackNavigation = false;
        _onboardingStep = OnboardingStep.accessibilityGoodStuff;
      });
    } on PlatformException {
      // Android-only setup flow. Other platforms ignore this.
    } on MissingPluginException {
      // Android-only setup flow. Other platforms ignore this.
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _accessibilityChannel.invokeMethod<void>(
        'openAccessibilitySettings',
      );
    } on PlatformException {
      // Android-only setup. Other platforms can still render the app shell.
    } on MissingPluginException {
      // Android-only setup. Other platforms can still render the app shell.
    }
  }

  Future<void> _requestAccessibilityAccess() async {
    if (_isAccessibilityEnabled == true) {
      await _openAccessibilitySettings();
      return;
    }

    final consented = await _showAccessibilityDisclosureDialog();
    if (consented == true) {
      await _openAccessibilitySettings();
    }
  }

  Future<bool?> _showAccessibilityDisclosureDialog() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PermissionDisclosureSheet(
        title: 'Allow Accessibility?',
        description:
            'Tempus uses Accessibility to detect when supported apps or blocked websites open, read the on-screen app state needed for those rules, and show pause or blocking prompts. Tempus only uses this access for distraction blocking features.',
      ),
    );
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await _accessibilityChannel.invokeMethod<void>('openUsageAccessSettings');
    } on PlatformException {
      // Android-only setup. Other platforms can still render the app shell.
    } on MissingPluginException {
      // Android-only setup. Other platforms can still render the app shell.
    }
  }

  Future<void> _requestUsageAccess() async {
    if (_isUsageAccessEnabled == true) {
      await _openUsageAccessSettings();
      return;
    }

    final consented = await _showUsageAccessDisclosureDialog();
    if (consented == true) {
      await _openUsageAccessSettings();
    }
  }

  Future<bool?> _showUsageAccessDisclosureDialog() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PermissionDisclosureSheet(
        title: 'Allow Usage Access?',
        description:
            'Tempus uses Usage Access to measure app time, enforce daily limits, and track your distraction-free days.',
      ),
    );
  }

  Future<void> _openWebsite(String url) async {
    try {
      await _accessibilityChannel.invokeMethod<void>('openWebsite', {
        'url': url,
      });
    } on PlatformException {
      // Android-only helper. Other platforms can still render the app shell.
    } on MissingPluginException {
      // Android-only helper. Other platforms can still render the app shell.
    }
  }

  Future<void> _shareText(String text) async {
    try {
      await _accessibilityChannel.invokeMethod<void>('shareText', {
        'text': text,
      });
    } on PlatformException {
      // Android-only helper. Other platforms can still render the app shell.
    } on MissingPluginException {
      // Android-only helper. Other platforms can still render the app shell.
    }
  }

  String _shareAppMessage() {
    final currentStreak = _currentDistractionFreeStreak();
    final dayLabel = currentStreak == 1 ? 'day' : 'days';
    return "I've spent $currentStreak $dayLabel distraction free! Join me on Tempus "
        'https://play.google.com/store/apps/details?id=com.prestige.tempus';
  }

  int _currentDistractionFreeStreak() {
    final today = DateTime.now();
    final firstDate = DateTime(
      _appInstalledOn.year,
      _appInstalledOn.month,
      _appInstalledOn.day,
    );
    final todayDate = DateTime(today.year, today.month, today.day);

    var current = 0;
    var cursor = todayDate;
    while (!cursor.isBefore(firstDate)) {
      final status =
          _scrollDayStatuses[_dateKey(cursor)] ?? ScrollDayStatus.scrolled;
      if (status != ScrollDayStatus.noScroll) break;
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return current;
  }

  Future<void> _refreshUsageAccessStatus() async {
    try {
      final enabled = await _accessibilityChannel.invokeMethod<bool>(
        'isUsageAccessEnabled',
      );
      if (!mounted) return;
      setState(() {
        _isUsageAccessEnabled = enabled ?? false;
        if (_isUsageAccessEnabled == true &&
            _isAccessibilityEnabled == true &&
            !_hasCompletedOnboarding) {
          _allowOnboardingBackNavigation = false;
          _onboardingStep = OnboardingStep.allDone;
        }
      });
      await _consumeUsageAccessEnabledSuccess();
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _isUsageAccessEnabled = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _isUsageAccessEnabled = false;
      });
    }
  }

  Future<void> _refreshUsageStats() async {
    try {
      final usageStats = await _accessibilityChannel.invokeListMethod<dynamic>(
        'getTodayUsageStats',
      );
      final scrollHeuristicMetrics = await _accessibilityChannel
          .invokeMapMethod<String, dynamic>('getTodayScrollHeuristicMetrics');
      if (!mounted || usageStats == null) return;
      final usageSegments = _usageSegmentsFromStats(usageStats);
      setState(() {
        _usageSegments = usageSegments;
      });
      _updateTodayScrollStatus(scrollHeuristicMetrics);
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _usageSegments = const [];
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _usageSegments = const [];
      });
    }
  }

  Future<void> _loadSavedBlockConfig() async {
    try {
      final savedConfig = await _accessibilityChannel
          .invokeMapMethod<String, dynamic>('getSavedBlockConfig');
      if (!mounted || savedConfig == null) return;

      final rawDailyTimeLimits =
          savedConfig['dailyTimeLimits'] as Map<dynamic, dynamic>?;
      final rawBlockSettings =
          savedConfig['blockSettings'] as Map<dynamic, dynamic>?;
      final rawScrollDayStatuses =
          savedConfig['scrollDayStatuses'] as Map<dynamic, dynamic>?;
      final rawBlockedWebsites =
          savedConfig['blockedWebsites'] as List<dynamic>?;
      final rawCustomTrackedApps =
          savedConfig['customTrackedApps'] as List<dynamic>?;

      setState(() {
        if (rawCustomTrackedApps != null) {
          _customTrackedApps = rawCustomTrackedApps
              .whereType<Map>()
              .map(CustomTrackedApp.fromMap)
              .where(
                (entry) =>
                    entry.appName.isNotEmpty && entry.packageName.isNotEmpty,
              )
              .toList();

          for (final app in _customTrackedApps) {
            _dailyTimeLimits.putIfAbsent(app.settingKey, () => null);
            _blockSettings.putIfAbsent(
              customTrackedAppPauseOnOpenSettingKey(app.packageName),
              () => false,
            );
          }
        }

        if (rawDailyTimeLimits != null) {
          for (final entry in rawDailyTimeLimits.entries) {
            final key = entry.key;
            if (key is String) {
              final value = entry.value;
              _dailyTimeLimits[key] = value is int ? value : null;
            }
          }
        }

        if (rawBlockSettings != null) {
          for (final entry in rawBlockSettings.entries) {
            final key = entry.key;
            if (key is String && _blockSettings.containsKey(key)) {
              final value = entry.value;
              if (value is bool) {
                _blockSettings[key] = value;
              }
            }
          }
        }

        if (rawScrollDayStatuses != null) {
          _scrollDayStatuses
            ..clear()
            ..addEntries(
              rawScrollDayStatuses.entries
                  .map((entry) {
                    final key = entry.key;
                    final value = entry.value;
                    if (key is! String || value is! int) {
                      return const MapEntry('', ScrollDayStatus.scrolled);
                    }
                    return MapEntry(key, _scrollDayStatusFromInt(value));
                  })
                  .where((entry) => entry.key.isNotEmpty),
            );
        }

        if (rawBlockedWebsites != null) {
          _blockedWebsites
            ..clear()
            ..addAll(
              rawBlockedWebsites
                  .whereType<Map>()
                  .map((entry) {
                    final domain = entry['domain'] as String? ?? '';
                    final blockedSince = entry['blockedSince'];
                    final blockedSinceMillis = blockedSince is int
                        ? blockedSince
                        : 0;
                    return BlockedWebsiteEntry(
                      domain: domain,
                      blockedSince: DateTime.fromMillisecondsSinceEpoch(
                        blockedSinceMillis,
                      ),
                    );
                  })
                  .where((entry) => entry.domain.isNotEmpty),
            );
        }
      });
      _refreshUsageStats();
    } on PlatformException {
      // Android-only persistence. Other platforms use in-memory defaults.
    } on MissingPluginException {
      // Android-only persistence. Other platforms use in-memory defaults.
    }
  }

  Future<void> _setNativeDailyTimeLimit(String settingKey, int? minutes) async {
    try {
      await _accessibilityChannel.invokeMethod<void>('setDailyTimeLimit', {
        'settingKey': settingKey,
        'minutes': minutes,
      });
    } on PlatformException {
      // Android-only enforcement. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only enforcement. Other platforms keep local UI state only.
    }
  }

  Future<void> _setNativeBlockSetting(String settingKey, bool value) async {
    try {
      await _accessibilityChannel.invokeMethod<void>('setBlockSetting', {
        'settingKey': settingKey,
        'value': value,
      });
    } on PlatformException {
      // Android-only enforcement. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only enforcement. Other platforms keep local UI state only.
    }
  }

  Future<void> _persistBlockedWebsites() async {
    try {
      await _accessibilityChannel.invokeMethod<void>('setBlockedWebsites', {
        'blockedWebsites': _blockedWebsites
            .map(
              (entry) => {
                'domain': entry.domain,
                'blockedSince': entry.blockedSince.millisecondsSinceEpoch,
              },
            )
            .toList(),
      });
    } on PlatformException {
      // Android-only persistence. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only persistence. Other platforms keep local UI state only.
    }
  }

  Future<void> _consumeUsageAccessEnabledSuccess() async {
    try {
      final shouldShow = await _accessibilityChannel.invokeMethod<bool>(
        'consumeUsageAccessEnabledSuccess',
      );
      if (!mounted || shouldShow != true) return;
      setState(() {
        _onboardingStep = OnboardingStep.allDone;
      });
    } on PlatformException {
      // Android-only setup flow. Other platforms ignore this.
    } on MissingPluginException {
      // Android-only setup flow. Other platforms ignore this.
    }
  }

  Future<void> _loadOnboardingState() async {
    try {
      final completed = await _accessibilityChannel.invokeMethod<bool>(
        'getOnboardingCompleted',
      );
      if (!mounted) return;
      setState(() {
        _hasCompletedOnboarding = completed ?? false;
        _hasLoadedOnboardingState = true;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _hasLoadedOnboardingState = true;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _hasLoadedOnboardingState = true;
      });
    }
  }

  Future<void> _setOnboardingCompleted(bool completed) async {
    try {
      await _accessibilityChannel.invokeMethod<void>('setOnboardingCompleted', {
        'completed': completed,
      });
    } on PlatformException {
      // Android-only persistence. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only persistence. Other platforms keep local UI state only.
    }
  }

  Future<void> _openWebsiteExternally(String domain) async {
    final normalizedDomain = _normalizeWebsite(domain);
    if (normalizedDomain.isEmpty) return;
    final url = 'https://$normalizedDomain';
    try {
      await _accessibilityChannel.invokeMethod<void>('openWebsite', {
        'url': url,
      });
    } on PlatformException {
      // Android-only launch path. Other platforms ignore for now.
    } on MissingPluginException {
      // Android-only launch path. Other platforms ignore for now.
    }
  }

  Future<void> _consumeSharedWebsite() async {
    try {
      final sharedWebsite = await _accessibilityChannel.invokeMethod<String>(
        'consumeSharedWebsite',
      );
      if (!mounted || sharedWebsite == null || sharedWebsite.trim().isEmpty) {
        return;
      }
      await _handleSharedWebsite(sharedWebsite);
    } on PlatformException {
      // Android-only share path.
    } on MissingPluginException {
      // Android-only share path.
    }
  }

  Future<void> _handleSharedWebsite(String rawWebsite) async {
    final website = _normalizeWebsite(rawWebsite);
    if (website.isEmpty || !mounted) return;

    _selectTab(
      1,
      update: () {
        _blockCategory = 'Websites';
      },
    );

    final existingEntry = _blockedWebsites
        .cast<BlockedWebsiteEntry?>()
        .firstWhere(
          (entry) => entry?.domain.toLowerCase() == website.toLowerCase(),
          orElse: () => null,
        );

    if (existingEntry != null) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            backgroundColor: appBackground,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Do you really need this?',
              style: TextStyle(color: appText, fontWeight: FontWeight.w700),
            ),
            content: Text(
              existingEntry.domain,
              style: const TextStyle(
                color: appMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No, not really'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
      if (shouldContinue == true) {
        await _openWebsiteExternally(existingEntry.domain);
      }
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appBackground,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Add blocked website?',
            style: TextStyle(color: appText, fontWeight: FontWeight.w700),
          ),
          content: Text(
            website,
            style: const TextStyle(
              color: appMutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (shouldAdd == true) {
      _addBlockedWebsite(website);
    }
  }

  Future<void> _persistCustomTrackedApps() async {
    try {
      await _accessibilityChannel.invokeMethod<void>('setCustomTrackedApps', {
        'customTrackedApps': _customTrackedApps
            .map((app) => app.toMap())
            .toList(),
      });
    } on PlatformException {
      // Android-only persistence. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only persistence. Other platforms keep local UI state only.
    }
  }

  Future<void> _persistTodayScrollStatus(ScrollDayStatus status) async {
    final dateKey = _dateKey(DateTime.now());
    try {
      await _accessibilityChannel.invokeMethod<void>('setScrollDayStatus', {
        'dateKey': dateKey,
        'status': _scrollDayStatusToInt(status),
      });
    } on PlatformException {
      // Android-only persistence. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only persistence. Other platforms keep local UI state only.
    }
  }

  Future<void> _refreshInstalledTrackedPackages() async {
    try {
      final installedPackages = await _accessibilityChannel
          .invokeListMethod<String>('getInstalledTrackedPackages');
      if (!mounted || installedPackages == null) return;
      setState(() {
        _installedTrackedPackages = installedPackages.toSet();
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _installedTrackedPackages = null;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _installedTrackedPackages = null;
      });
    }
  }

  Future<List<CustomTrackedApp>> _requestInstalledApps() async {
    try {
      final installedApps = await _accessibilityChannel
          .invokeListMethod<dynamic>('getInstalledApps');
      if (installedApps == null) return const [];
      return installedApps
          .whereType<Map>()
          .map(CustomTrackedApp.fromMap)
          .where(
            (entry) => entry.appName.isNotEmpty && entry.packageName.isNotEmpty,
          )
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  void _updateTodayScrollStatus(Map<String, dynamic>? scrollHeuristicMetrics) {
    if (_isUsageAccessEnabled != true) return;
    final shortFormBypassMinutes =
        scrollHeuristicMetrics?['shortFormBypassMinutes'] as int? ?? 0;
    final trackedLimitOverageMinutes =
        scrollHeuristicMetrics?['trackedLimitOverageMinutes'] as int? ?? 0;
    final nextStatus = switch ((
      trackedLimitOverageMinutes,
      shortFormBypassMinutes,
    )) {
      (> 20, _) || (_, > 20) => ScrollDayStatus.scrolled,
      (> 0, _) || (_, > 5) => ScrollDayStatus.partialScroll,
      _ => ScrollDayStatus.noScroll,
    };
    final dateKey = _dateKey(DateTime.now());
    if (_scrollDayStatuses[dateKey] == nextStatus) return;
    setState(() {
      _scrollDayStatuses[dateKey] = nextStatus;
    });
    _persistTodayScrollStatus(nextStatus);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  ScrollDayStatus _scrollDayStatusFromInt(int value) {
    return switch (value) {
      1 => ScrollDayStatus.noScroll,
      2 => ScrollDayStatus.partialScroll,
      _ => ScrollDayStatus.scrolled,
    };
  }

  int _scrollDayStatusToInt(ScrollDayStatus status) {
    return switch (status) {
      ScrollDayStatus.noScroll => 1,
      ScrollDayStatus.partialScroll => 2,
      ScrollDayStatus.scrolled => 3,
    };
  }

  List<AppUsageSegment> _usageSegmentsFromStats(List<dynamic> usageStats) {
    final minutesByPackage = <String, int>{};
    for (final rawStat in usageStats) {
      if (rawStat is! Map) continue;
      final packageName = rawStat['packageName'] as String?;
      final minutes = rawStat['minutes'] as int?;
      if (packageName == null || minutes == null || minutes <= 0) continue;
      minutesByPackage.update(
        packageName,
        (currentMinutes) => currentMinutes + minutes,
        ifAbsent: () => minutes,
      );
    }

    final segments = <AppUsageSegment>[];
    for (final app in _trackedUsageApps) {
      final totalMinutes =
          app.packageNames.fold<int>(
            0,
            (sum, packageName) => sum + (minutesByPackage[packageName] ?? 0),
          ) +
          minutesByPackage.entries.fold<int>(
            0,
            (sum, entry) =>
                app.packagePrefixes.any(
                  (prefix) => entry.key.startsWith(prefix),
                )
                ? sum + entry.value
                : sum,
          );
      if (totalMinutes <= 0) continue;
      segments.add(
        AppUsageSegment(
          appName: app.appName,
          minutes: totalMinutes,
          color: app.color,
        ),
      );
    }

    for (final app in _customUsageApps) {
      final totalMinutes = minutesByPackage[app.packageName] ?? 0;
      if (totalMinutes <= 0) continue;
      segments.add(
        AppUsageSegment(
          appName: app.appName,
          minutes: totalMinutes,
          color: app.color,
        ),
      );
    }

    return segments;
  }

  List<_CustomUsageApp> get _customUsageApps {
    return _customTrackedApps.map((app) {
      return _CustomUsageApp(
        appName: app.appName,
        packageName: app.packageName,
        color: _colorForPackageName(app.packageName),
      );
    }).toList();
  }

  Color _colorForPackageName(String packageName) {
    const palette = [
      Color(0xFF00688F),
      Color(0xFF2784A3),
      Color(0xFF4A9AB6),
      Color(0xFF71B6C9),
      Color(0xFF005776),
      Color(0xFF0E7397),
      Color(0xFF3C8DAA),
      Color(0xFF96CBDB),
    ];
    final index = packageName.hashCode.abs() % palette.length;
    return palette[index];
  }

  Future<void> _loadAppInstallDate() async {
    try {
      final installTimeMillis = await _accessibilityChannel.invokeMethod<int>(
        'getFirstInstallTime',
      );
      if (!mounted || installTimeMillis == null) return;
      setState(() {
        _appInstalledOn = DateTime.fromMillisecondsSinceEpoch(
          installTimeMillis,
        );
        if (_isBeforeMonth(_trackerMonth, _firstTrackerMonth)) {
          _trackerMonth = _firstTrackerMonth;
        }
      });
    } on PlatformException {
      // Android-only install metadata. Other platforms use this session date.
    } on MissingPluginException {
      // Android-only install metadata. Other platforms use this session date.
    }
  }

  DateTime get _firstTrackerMonth {
    return DateTime(_appInstalledOn.year, _appInstalledOn.month);
  }

  DateTime get _latestTrackerDataMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1);
  }

  bool get _canShowPreviousTrackerMonth {
    return _isAfterMonth(_trackerMonth, _firstTrackerMonth);
  }

  bool get _canShowNextTrackerMonth {
    return _isBeforeMonth(_trackerMonth, _latestTrackerDataMonth);
  }

  bool _isBeforeMonth(DateTime first, DateTime second) {
    return first.year < second.year ||
        (first.year == second.year && first.month < second.month);
  }

  bool _isAfterMonth(DateTime first, DateTime second) {
    return first.year > second.year ||
        (first.year == second.year && first.month > second.month);
  }

  void _addBlockedWebsite(String rawWebsite) {
    final website = _normalizeWebsite(rawWebsite);
    if (website.isEmpty) return;
    final alreadyExists = _blockedWebsites.any(
      (entry) => entry.domain.toLowerCase() == website.toLowerCase(),
    );
    if (alreadyExists) return;
    setState(() {
      _blockedWebsites.insert(
        0,
        BlockedWebsiteEntry(domain: website, blockedSince: DateTime.now()),
      );
    });
    _persistBlockedWebsites();
  }

  void _deleteBlockedWebsite(BlockedWebsiteEntry entry) {
    setState(() {
      _blockedWebsites.remove(entry);
    });
    _persistBlockedWebsites();
  }

  String _normalizeWebsite(String input) {
    var normalized = input.trim().toLowerCase();
    normalized = normalized.replaceFirst(RegExp(r'^https?://'), '');
    normalized = normalized.replaceFirst(RegExp(r'^www\.'), '');
    normalized = normalized.replaceAll(RegExp(r'/$'), '');
    return normalized;
  }

  void _selectTab(int index, {VoidCallback? update}) {
    if (index == _selectedIndex) {
      if (update != null) {
        setState(update);
      }
      return;
    }

    setState(() {
      update?.call();
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _fadeToTab(int index) async {
    if (index == _selectedIndex || _isFadingBetweenTabs) {
      return;
    }

    setState(() {
      _isFadingBetweenTabs = true;
      _selectedIndex = index;
      _pageOpacity = 0;
    });

    await Future<void>.delayed(_navFadeDuration);
    if (!mounted) return;

    _pageController.jumpToPage(index);

    setState(() {
      _pageOpacity = 1;
    });

    await Future<void>.delayed(_navFadeDuration);
    if (!mounted) return;

    setState(() {
      _isFadingBetweenTabs = false;
    });
  }

  List<Widget> _buildScreens(BuildContext context) {
    return [
      HomeOverview(
        trackerMonth: _trackerMonth,
        usageSegments: _usageSegments,
        scrollDayStatuses: _scrollDayStatuses,
        firstTrackableDate: _appInstalledOn,
        blockSettings: _blockSettings,
        dailyTimeLimits: _dailyTimeLimits,
        customTrackedApps: _customTrackedApps,
        canShowPreviousMonth: _canShowPreviousTrackerMonth,
        canShowNextMonth: _canShowNextTrackerMonth,
        onOpenBlockedShorts: () {
          _selectTab(
            1,
            update: () {
              _expandedApps.addAll({'Instagram', 'YouTube'});
            },
          );
        },
        onShareApp: () {
          _shareText(_shareAppMessage());
        },
        onPreviousMonth: () {
          if (!_canShowPreviousTrackerMonth) return;
          setState(() {
            _trackerMonth = DateTime(
              _trackerMonth.year,
              _trackerMonth.month - 1,
            );
          });
        },
        onNextMonth: () {
          if (!_canShowNextTrackerMonth) return;
          setState(() {
            _trackerMonth = DateTime(
              _trackerMonth.year,
              _trackerMonth.month + 1,
            );
          });
        },
      ),
      BlockScreen(
        onBackToHome: () {
          _fadeToTab(0);
        },
        selectedCategory: _blockCategory,
        expandedApps: _expandedApps,
        installedPackageNames: _installedTrackedPackages,
        customTrackedApps: _customTrackedApps,
        blockedWebsites: _blockedWebsites,
        dailyTimeLimits: _dailyTimeLimits,
        blockSettings: _blockSettings,
        onAddWebsite: _addBlockedWebsite,
        onDeleteWebsite: _deleteBlockedWebsite,
        onRequestInstalledApps: _requestInstalledApps,
        onAddCustomTrackedApp: (selection) {
          final app = selection.app;
          final alreadyExists = _customTrackedApps.any(
            (entry) => entry.packageName == app.packageName,
          );
          if (alreadyExists) return;
          setState(() {
            _customTrackedApps = [..._customTrackedApps, app];
            _dailyTimeLimits[app.settingKey] = selection.minutes;
            final pauseOnOpenKey = customTrackedAppPauseOnOpenSettingKey(
              app.packageName,
            );
            _blockSettings[pauseOnOpenKey] = selection.pauseOnOpen;
          });
          _persistCustomTrackedApps();
          _setNativeDailyTimeLimit(app.settingKey, selection.minutes);
          _setNativeBlockSetting(
            customTrackedAppPauseOnOpenSettingKey(app.packageName),
            selection.pauseOnOpen,
          );
          _refreshUsageStats();
        },
        onDeleteCustomTrackedApp: (app) {
          setState(() {
            _customTrackedApps = _customTrackedApps
                .where((entry) => entry.packageName != app.packageName)
                .toList();
            _dailyTimeLimits.remove(app.settingKey);
            _blockSettings.remove(
              customTrackedAppPauseOnOpenSettingKey(app.packageName),
            );
          });
          _persistCustomTrackedApps();
          _setNativeDailyTimeLimit(app.settingKey, null);
          _setNativeBlockSetting(
            customTrackedAppPauseOnOpenSettingKey(app.packageName),
            false,
          );
          _refreshUsageStats();
        },
        onSelectCategory: (category) {
          setState(() {
            _blockCategory = category;
          });
        },
        onToggleExpanded: (appName) {
          setState(() {
            if (_expandedApps.contains(appName)) {
              _expandedApps.remove(appName);
            } else {
              const builtInApps = {'Instagram', 'YouTube'};
              final customAppKeys = _customTrackedApps
                  .map((app) => app.packageName)
                  .toSet();

              if (builtInApps.contains(appName)) {
                _expandedApps.removeAll(builtInApps);
              } else if (customAppKeys.contains(appName)) {
                _expandedApps.removeAll(customAppKeys);
              }

              _expandedApps.add(appName);
            }
          });
        },
        onToggleSetting: (settingKey, value) {
          setState(() {
            _blockSettings[settingKey] = value;
          });
          _setNativeBlockSetting(settingKey, value);
        },
        onSelectTimeLimit: (settingKey, minutes) {
          setState(() {
            _dailyTimeLimits[settingKey] = minutes;
          });
          _setNativeDailyTimeLimit(settingKey, minutes);
        },
      ),
      StatisticsTab(
        onBackToHome: () {
          _fadeToTab(0);
        },
      ),
      SettingsTab(
        onBackToHome: () {
          _fadeToTab(0);
        },
        onOpenAccessibilitySettings: _requestAccessibilityAccess,
        onOpenUsageAccessSettings: _requestUsageAccess,
        onShareApp: () {
          _shareText(
            'Tempus helps me spend less time scrolling. Join me on Tempus: '
            'https://play.google.com/store/apps/details?id=com.prestige.tempus',
          );
        },
        onLeaveReview: () {
          _openWebsite(
            'https://play.google.com/store/apps/details?id=com.prestige.tempus',
          );
        },
        onOpenPrivacyPolicy: () {
          _openWebsite('https://dashing-profiterole-4c88c4.netlify.app/');
        },
        isAccessibilityAllowed: _isAccessibilityEnabled == true,
        isUsageAccessAllowed: _isUsageAccessEnabled == true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLoadedOnboardingState) {
      return const Scaffold(
        backgroundColor: appBackground,
        body: SizedBox.expand(),
      );
    }

    if (!_hasCompletedOnboarding && !_bypassAccessibilityGate) {
      final displayedStep = _effectiveOnboardingStep();
      final previousStep = _previousOnboardingStep(displayedStep);

      return OnboardingScreen(
        step: displayedStep,
        onBack: previousStep == null
            ? null
            : () {
                setState(() {
                  _allowOnboardingBackNavigation = true;
                  _onboardingStep = previousStep;
                });
              },
        onGetStarted: () {
          setState(() {
            _allowOnboardingBackNavigation = false;
            _onboardingStep = OnboardingStep.howPauseOnOpen;
          });
        },
        onContinueFromPauseDemo: () {
          setState(() {
            _allowOnboardingBackNavigation = false;
            _onboardingStep = OnboardingStep.howBlockDistractions;
          });
        },
        onContinueFromBlockDemo: () {
          setState(() {
            _allowOnboardingBackNavigation = false;
            _onboardingStep = OnboardingStep.enableAccessibility;
          });
        },
        onOpenAccessibilitySettings: _requestAccessibilityAccess,
        onContinueFromAccessibilitySuccess: () {
          setState(() {
            _allowOnboardingBackNavigation = false;
            _onboardingStep = OnboardingStep.trackDays;
          });
        },
        onContinueFromTracking: () {
          setState(() {
            _allowOnboardingBackNavigation = false;
            _onboardingStep = OnboardingStep.enableUsageAccess;
          });
        },
        onOpenUsageAccessSettings: () async {
          await _requestUsageAccess();
          if (!mounted) return;
          if (_isUsageAccessEnabled == true) {
            setState(() {
              _allowOnboardingBackNavigation = false;
              _onboardingStep = OnboardingStep.allDone;
            });
          }
        },
        onFinish: () {
          setState(() {
            _hasCompletedOnboarding = true;
          });
          _setOnboardingCompleted(true);
        },
      );
    }

    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: ColoredBox(
          color: appBackground,
          child: AnimatedOpacity(
            opacity: _pageOpacity,
            duration: _navFadeDuration,
            curve: Curves.easeOut,
            child: PageView(
              controller: _pageController,
              physics: _isFadingBetweenTabs
                  ? const NeverScrollableScrollPhysics()
                  : null,
              onPageChanged: (index) {
                if (_selectedIndex == index) return;
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _buildScreens(context),
            ),
          ),
        ),
      ),
      bottomNavigationBar: InstagramBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          _fadeToTab(index);
        },
      ),
    );
  }

  OnboardingStep _effectiveOnboardingStep() {
    if (_allowOnboardingBackNavigation) {
      return _onboardingStep;
    }
    if (_isAccessibilityEnabled == true && _isUsageAccessEnabled == true) {
      return OnboardingStep.allDone;
    }
    if (_isAccessibilityEnabled != true &&
        _onboardingStep.index > OnboardingStep.enableAccessibility.index) {
      return OnboardingStep.enableAccessibility;
    }
    if (_isAccessibilityEnabled == true &&
        _onboardingStep.index < OnboardingStep.trackDays.index) {
      return OnboardingStep.accessibilityGoodStuff;
    }
    if (_isAccessibilityEnabled == true &&
        _isUsageAccessEnabled != true &&
        _onboardingStep == OnboardingStep.allDone) {
      return OnboardingStep.enableUsageAccess;
    }
    return _onboardingStep;
  }

  OnboardingStep? _previousOnboardingStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.intro:
        return null;
      case OnboardingStep.howPauseOnOpen:
        return OnboardingStep.intro;
      case OnboardingStep.howBlockDistractions:
        return OnboardingStep.howPauseOnOpen;
      case OnboardingStep.enableAccessibility:
        return OnboardingStep.howBlockDistractions;
      case OnboardingStep.accessibilityGoodStuff:
        return OnboardingStep.enableAccessibility;
      case OnboardingStep.trackDays:
        return OnboardingStep.accessibilityGoodStuff;
      case OnboardingStep.enableUsageAccess:
        return OnboardingStep.trackDays;
      case OnboardingStep.allDone:
        return OnboardingStep.enableUsageAccess;
    }
  }
}

class _PermissionDisclosureSheet extends StatelessWidget {
  const _PermissionDisclosureSheet({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        child: Material(
          color: appBackground,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: appBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
                        width: 32,
                        height: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: appText,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: appMutedText,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: appBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Not Now'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Agree and Continue',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InstagramBottomNavBar extends StatelessWidget {
  const InstagramBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: appBackground,
        border: Border(top: BorderSide(color: appBorder, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SizedBox(
        height: 62,
        child: Material(
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BottomNavItem(
                assetPath: 'assets/icons/home.svg',
                label: 'Overview',
                isSelected: selectedIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _BottomNavItem(
                assetPath: 'assets/icons/block.svg',
                label: 'Block',
                isSelected: selectedIndex == 1,
                onTap: () => onTabSelected(1),
                iconSize: 31,
              ),
              _BottomNavItem(
                assetPath: 'assets/icons/statistics.svg',
                label: 'Stats',
                isSelected: selectedIndex == 2,
                onTap: () => onTabSelected(2),
              ),
              _BottomNavItem(
                assetPath: 'assets/icons/settings.svg',
                label: 'Settings',
                isSelected: selectedIndex == 3,
                onTap: () => onTabSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.assetPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconSize = 34,
  });

  final String assetPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: SizedBox.expand(
          child: Ink(
            color: isSelected ? brand.withValues(alpha: 0.10) : null,
            child: InkWell(
              onTap: onTap,
              splashColor: brand.withValues(alpha: 0.18),
              highlightColor: appText.withValues(alpha: 0.04),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      assetPath,
                      width: iconSize,
                      height: iconSize,
                      colorFilter: ColorFilter.mode(
                        isSelected ? brand : appMutedText,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? brand : appMutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
