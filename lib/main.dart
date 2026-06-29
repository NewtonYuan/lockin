import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'brand.dart';
import 'onboarding.dart';
import 'services/premium_service.dart';
import 'services/statistics_history_store.dart';
import 'tabs/block_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/statistics_tab.dart';
import 'widgets/days_tracker_calendar.dart';

void main() {
  runApp(const MyApp());
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
  static const _statisticsHistoryStore = StatisticsHistoryStore();
  static const _playRedeemUrl = 'https://play.google.com/redeem';

  int _selectedIndex = 0;
  late final PageController _pageController;
  late final PremiumService _premiumService;
  final GlobalKey<StatisticsTabState> _statisticsTabKey =
      GlobalKey<StatisticsTabState>();
  double _pageOpacity = 1;
  bool _isFadingBetweenTabs = false;
  bool? _isAccessibilityEnabled;
  bool? _isUsageAccessEnabled;
  bool _bypassAccessibilityGate = false;
  bool _skippedAccessibilityOnboarding = false;
  bool _skippedUsageAccessOnboarding = false;
  bool _hasCompletedOnboarding = false;
  bool _hasLoadedOnboardingState = false;
  bool _allowOnboardingBackNavigation = false;
  OnboardingStep _onboardingStep = OnboardingStep.intro;
  DateTime _trackerMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _appInstalledOn = DateTime.now();
  List<AppUsageSegment> _allAppUsageSegments = const [];
  StatisticsSnapshot? _statisticsSnapshot;
  bool _isStatisticsLoading = false;
  bool _statisticsNeedsRefresh = true;
  String? _lastPremiumErrorMessage;
  final Map<String, ScrollDayStatus> _scrollDayStatuses = {};
  Set<String>? _installedTrackedPackages;
  List<CustomTrackedApp> _installedApps = const [];
  List<CustomTrackedApp> _customTrackedApps = const [];
  final List<BlockedWebsiteEntry> _blockedWebsites = [];
  String _blockCategory = 'Apps';
  int _pauseDurationSeconds = 5;
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
    _premiumService = PremiumService();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _premiumService.addListener(_handlePremiumStateChanged);
    _premiumService.initialize();
    _refreshAccessibilityStatus();
    _refreshUsageAccessStatus();
    _loadOnboardingState();
    _loadSavedBlockConfig();
    _refreshInstalledTrackedPackages();
    _refreshHomeUsage();
    _loadAppInstallDate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeSharedWebsite();
    });
  }

  @override
  void dispose() {
    _premiumService.removeListener(_handlePremiumStateChanged);
    _premiumService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _handlePremiumStateChanged() {
    if (!mounted) return;
    final errorMessage = _premiumService.errorMessage;
    if (errorMessage != null && errorMessage != _lastPremiumErrorMessage) {
      _lastPremiumErrorMessage = errorMessage;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage)));
    } else if (errorMessage == null) {
      _lastPremiumErrorMessage = null;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAccessibilityStatus();
      _refreshUsageAccessStatus();
      _refreshInstalledTrackedPackages();
      _refreshHomeUsage();
      if (_selectedIndex == 2) {
        _loadStatisticsTabData();
      }
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
          _skippedAccessibilityOnboarding = false;
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

  Future<void> _requestAccessibilityAccessForOnboarding() async {
    if (_isAccessibilityEnabled == true) {
      await _openAccessibilitySettings();
      return;
    }

    final consented = await _showAccessibilityDisclosureDialog();
    if (!mounted) return;
    if (consented == true) {
      await _openAccessibilitySettings();
      return;
    }
    if (consented == null) {
      return;
    }

    setState(() {
      _allowOnboardingBackNavigation = false;
      _skippedAccessibilityOnboarding = true;
      _onboardingStep = OnboardingStep.trackDays;
    });
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

  Future<void> _requestUsageAccessForOnboarding() async {
    if (_isUsageAccessEnabled == true) {
      await _openUsageAccessSettings();
      return;
    }

    final consented = await _showUsageAccessDisclosureDialog();
    if (!mounted) return;
    if (consented == true) {
      await _openUsageAccessSettings();
      return;
    }
    if (consented == null) {
      return;
    }

    setState(() {
      _allowOnboardingBackNavigation = false;
      _skippedUsageAccessOnboarding = true;
      _onboardingStep = OnboardingStep.allDone;
    });
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
        if (_isUsageAccessEnabled == true) {
          _skippedUsageAccessOnboarding = false;
        }
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

  Future<void> _refreshHomeUsage() async {
    try {
      final allAppUsageStats = await _accessibilityChannel
          .invokeListMethod<dynamic>('getTodayAllAppUsageStats');
      final scrollHeuristicMetrics = await _accessibilityChannel
          .invokeMapMethod<String, dynamic>('getTodayScrollHeuristicMetrics');
      if (!mounted) return;
      final allAppUsageSegments = _allUsageSegmentsFromStats(allAppUsageStats);
      setState(() {
        _allAppUsageSegments = allAppUsageSegments;
      });
      _updateTodayScrollStatus(scrollHeuristicMetrics);
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _allAppUsageSegments = const [];
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _allAppUsageSegments = const [];
      });
    }
  }

  Future<void> _openPremiumSheet() async {
    await _premiumService.loadProducts();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedBuilder(
          animation: _premiumService,
          builder: (context, _) {
            return _PremiumSheet(
              premiumService: _premiumService,
            );
          },
        );
      },
    );
  }

  Future<void> _openRedeemCode() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RedeemCodeSheet(
          onOpenRedeem: () => _openWebsite(_playRedeemUrl),
        );
      },
    );
  }

  Future<void> _loadStatisticsTabData({bool force = false}) async {
    if (_isStatisticsLoading) return;
    if (!force && !_statisticsNeedsRefresh && _statisticsSnapshot != null) {
      return;
    }

    setState(() {
      _isStatisticsLoading = true;
    });

    try {
      final storedSnapshotFuture = _statisticsHistoryStore.loadSnapshot();
      final installedAppsFuture = _requestInstalledApps();
      final statisticsDataFuture = _accessibilityChannel
          .invokeMapMethod<String, dynamic>('getStatisticsData');

      final storedSnapshot = await storedSnapshotFuture;
      if (mounted && storedSnapshot != null && _statisticsSnapshot == null) {
        setState(() {
          _statisticsSnapshot = storedSnapshot;
        });
      }

      final installedApps = await installedAppsFuture;
      final statisticsData = await statisticsDataFuture;
      if (!mounted) return;

      final nativeStatisticsSnapshot = statisticsData == null
          ? null
          : StatisticsSnapshot.fromMap(statisticsData);
      final resolvedStatisticsSnapshot = nativeStatisticsSnapshot == null
          ? (storedSnapshot ?? _statisticsSnapshot)
          : await _statisticsHistoryStore.mergeAndSave(nativeStatisticsSnapshot);
      if (!mounted) return;

      setState(() {
        _installedApps = installedApps;
        _statisticsSnapshot = resolvedStatisticsSnapshot;
        _statisticsNeedsRefresh = false;
        _isStatisticsLoading = false;
      });
    } on PlatformException {
      final storedSnapshot = await _statisticsHistoryStore.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _statisticsSnapshot = storedSnapshot ?? _statisticsSnapshot;
        _isStatisticsLoading = false;
      });
    } on MissingPluginException {
      final storedSnapshot = await _statisticsHistoryStore.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _statisticsSnapshot = storedSnapshot ?? _statisticsSnapshot;
        _isStatisticsLoading = false;
      });
    }
  }

  Future<void> _openStatisticsForUsageSegment(AppUsageSegment segment) async {
    if (segment.packageName.trim().isEmpty || segment.packageName == 'other') {
      return;
    }
    await _fadeToTab(2);
    await _loadStatisticsTabData();
    while (mounted && _isStatisticsLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (!mounted || _selectedIndex != 2) return;
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted || _selectedIndex != 2) return;
      final didOpen = _statisticsTabKey.currentState?.openAppForPackageName(
        segment.packageName,
      );
      if (didOpen == true) {
        return;
      }
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
      final rawPauseDurationSeconds = savedConfig['pauseDurationSeconds'];

      setState(() {
        if (rawPauseDurationSeconds is int && rawPauseDurationSeconds > 0) {
          _pauseDurationSeconds = rawPauseDurationSeconds;
        }
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
      _refreshHomeUsage();
      _statisticsNeedsRefresh = true;
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

  Future<void> _setNativePauseDurationSeconds(int seconds) async {
    try {
      await _accessibilityChannel.invokeMethod<void>(
        'setPauseDurationSeconds',
        {'seconds': seconds},
      );
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
      final installedApps = await _accessibilityChannel
          .invokeListMethod<dynamic>('getInstalledTrackedApps');
      if (!mounted || installedApps == null) return;
      final trackedApps = installedApps
          .whereType<Map>()
          .map(CustomTrackedApp.fromMap)
          .where(
            (entry) => entry.appName.isNotEmpty && entry.packageName.isNotEmpty,
          )
          .toList();
      setState(() {
        _installedTrackedPackages = trackedApps
            .map((entry) => entry.packageName)
            .toSet();
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

  List<AppUsageSegment> _allUsageSegmentsFromStats(List<dynamic>? usageStats) {
    if (usageStats == null) return const [];

    final segments = usageStats
        .whereType<Map>()
        .map((rawStat) {
          final appName = rawStat['appName'] as String?;
          final packageName = rawStat['packageName'] as String?;
          final minutes = rawStat['minutes'] as int?;
          if (packageName == null || minutes == null || minutes <= 0) {
            return null;
          }
          return AppUsageSegment(
            appName: (appName == null || appName.isEmpty)
                ? packageName
                : appName,
            packageName: packageName,
            minutes: minutes,
            color: _colorForPackageName(packageName),
          );
        })
        .whereType<AppUsageSegment>()
        .toList();

    final totalMinutes = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.minutes,
    );
    if (totalMinutes <= 0) return segments;

    final majorSegments = <AppUsageSegment>[];
    var otherMinutes = 0;
    for (final segment in segments) {
      final share = segment.minutes / totalMinutes;
      if (share < 0.05) {
        otherMinutes += segment.minutes;
      } else {
        majorSegments.add(segment);
      }
    }

    if (otherMinutes > 0) {
      majorSegments.add(
        AppUsageSegment(
          appName: 'Other',
          packageName: 'other',
          minutes: otherMinutes,
          color: appSurfaceStrong,
        ),
      );
    }

    return majorSegments;
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
    if (index == 2) {
      _statisticsTabKey.currentState?.resetToBase();
      _loadStatisticsTabData();
    }
    if (index == _selectedIndex || _isFadingBetweenTabs) {
      return;
    }

    setState(() {
      _isFadingBetweenTabs = true;
      _selectedIndex = index;
      _pageOpacity = 0;
    });

    if (index == 2) {
      _loadStatisticsTabData();
    }

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
        usageSegments: _allAppUsageSegments,
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
        onOpenRestrictedApps: () {
          _selectTab(
            1,
            update: () {
              _expandedApps.removeAll({'Instagram', 'YouTube'});
            },
          );
        },
        onOpenUsageAppStatistics: (segment) {
          _openStatisticsForUsageSegment(segment);
        },
        onShareApp: () {
          _shareText(_shareAppMessage());
        },
        isAccessibilityAllowed: _isAccessibilityEnabled == true,
        isUsageAccessAllowed: _isUsageAccessEnabled == true,
        onOpenAccessibilitySettings: _requestAccessibilityAccess,
        onOpenUsageAccessSettings: _requestUsageAccess,
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
          if (!_premiumService.isPremium && _customTrackedApps.length >= 5) {
            _openPremiumSheet();
            return;
          }
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
          _refreshHomeUsage();
          _statisticsNeedsRefresh = true;
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
          _refreshHomeUsage();
          _statisticsNeedsRefresh = true;
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
        pauseDurationSeconds: _pauseDurationSeconds,
        onPauseDurationChanged: (seconds) {
          setState(() {
            _pauseDurationSeconds = seconds;
          });
          _setNativePauseDurationSeconds(seconds);
        },
        isPremium: _premiumService.isPremium,
        onOpenPremium: _openPremiumSheet,
        isAccessibilityAllowed: _isAccessibilityEnabled == true,
        onOpenAccessibilitySettings: _requestAccessibilityAccess,
      ),
      StatisticsTab(
        key: _statisticsTabKey,
        onBackToHome: () {
          _fadeToTab(0);
        },
        onRefresh: () => _loadStatisticsTabData(force: true),
        statistics: _statisticsSnapshot,
        installedApps: _installedApps,
        isLoading: _isStatisticsLoading,
        isPremium: _premiumService.isPremium,
        onOpenPremium: _openPremiumSheet,
        isUsageAccessAllowed: _isUsageAccessEnabled == true,
        onOpenUsageAccessSettings: _requestUsageAccess,
      ),
      SettingsTab(
        onBackToHome: () {
          _fadeToTab(0);
        },
        premiumStatusLabel: _premiumService.statusLabel,
        onOpenPremiumStatus: _openPremiumSheet,
        onEnterCode: _openRedeemCode,
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
        onSendFeedback: () {
          _openWebsite(
            'mailto:prestigesoftwarelabs@gmail.com?subject=Tempus%20Issue%20Report',
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
        onOpenAccessibilitySettings: _requestAccessibilityAccessForOnboarding,
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
          await _requestUsageAccessForOnboarding();
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
        !_skippedAccessibilityOnboarding &&
        _onboardingStep.index > OnboardingStep.enableAccessibility.index) {
      return OnboardingStep.enableAccessibility;
    }
    if (_isAccessibilityEnabled == true &&
        _onboardingStep.index < OnboardingStep.trackDays.index) {
      return OnboardingStep.accessibilityGoodStuff;
    }
    if (_isAccessibilityEnabled == true &&
        _isUsageAccessEnabled != true &&
        !_skippedUsageAccessOnboarding &&
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

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet({
    required this.premiumService,
  });

  final PremiumService premiumService;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    ProductDetails? monthlyProduct;
    ProductDetails? yearlyProduct;
    for (final product in premiumService.products) {
      final label = premiumService.labelForProduct(product);
      if (label == '1 MONTH') {
        monthlyProduct = product;
      } else if (label == '1 YEAR') {
        yearlyProduct = product;
      }
    }
    final yearlySavePercent =
        monthlyProduct != null &&
            yearlyProduct != null &&
            monthlyProduct.rawPrice > 0
        ? 30
        : null;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: appBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/crown.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          premiumGold,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tempus Premium',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: premiumGold,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (premiumService.isPremium) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Premium',
                        style: TextStyle(
                          color: Color(0xFF2F7D44),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'A few dollars to save hours every day.\n',
                      ),
                      TextSpan(
                        text: 'Your call.',
                        style: TextStyle(color: brand),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appMutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: appSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PremiumFeatureLine(label: 'Allow Reels from DMs'),
                      SizedBox(height: 8),
                      _PremiumFeatureLine(
                        label: 'Unlimited App Guards',
                      ),
                      SizedBox(height: 8),
                      _PremiumFeatureLine(
                        label: 'Advanced Statistics',
                      ),
                      SizedBox(height: 8),
                      _PremiumFeatureLine(
                        label: 'Unlocked premium features',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!premiumService.isStoreAvailable)
                const Text(
                  'Google Play billing is unavailable on this device right now.',
                  style: TextStyle(
                    color: appMutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (premiumService.isLoadingProducts &&
                  premiumService.products.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: brand,
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < premiumService.products.length; i++) ...[
                      Expanded(
                        child: _PremiumPlanButton(
                          title: premiumService.labelForProduct(
                            premiumService.products[i],
                          ),
                          price: premiumService.products[i].price,
                          badgeText:
                              premiumService.labelForProduct(
                                        premiumService.products[i],
                                      ) ==
                                      '1 YEAR' &&
                                  yearlySavePercent != null &&
                                  yearlySavePercent > 0
                              ? 'Save $yearlySavePercent%'
                              : null,
                          isLoading: premiumService.isPurchasePendingFor(
                            premiumService.products[i],
                          ),
                          onTap: () => premiumService.buy(
                            premiumService.products[i],
                          ),
                        ),
                      ),
                      if (i != premiumService.products.length - 1)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumFeatureLine extends StatelessWidget {
  const _PremiumFeatureLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: brand, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: appText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumPlanButton extends StatelessWidget {
  const _PremiumPlanButton({
    required this.title,
    required this.price,
    this.badgeText,
    required this.isLoading,
    required this.onTap,
  });

  final String title;
  final String price;
  final String? badgeText;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBanner = badgeText != null;
    final priceLabel = switch (title) {
      '1 MONTH' => '\$2.99 /month',
      '1 YEAR' => '\$24.99 /year',
      _ => price,
    };
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: Radius.circular(hasBanner ? 0 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: appText.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: appSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: Radius.circular(hasBanner ? 0 : 12),
                ),
                side: const BorderSide(color: premiumGold, width: 1.2),
              ),
              child: InkWell(
                onTap: isLoading ? null : onTap,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: Radius.circular(hasBanner ? 0 : 12),
                ),
                splashColor: brand.withValues(alpha: 0.18),
                highlightColor: appText.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: brand,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/crown.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              premiumGold,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Premium',
                            style: TextStyle(
                              color: premiumGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: brand,
                          ),
                        )
                      else
                        Text(
                          priceLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: appText,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF3E9B55),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Text(
                badgeText!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RedeemCodeSheet extends StatelessWidget {
  const _RedeemCodeSheet({required this.onOpenRedeem});

  final VoidCallback onOpenRedeem;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: appBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Redeem Code',
                style: TextStyle(
                  color: appText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Promo codes are redeemed through Google Play and applied to the current Play account.',
                style: TextStyle(
                  color: appMutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onOpenRedeem,
                  style: FilledButton.styleFrom(
                    backgroundColor: brand,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Open Google Play Redeem'),
                ),
              ),
            ],
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
