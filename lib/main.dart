import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';
import 'tabs/block_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/statistics_tab.dart';

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

const _trackedUsageApps = [
  _TrackedUsageApp(
    appName: 'Instagram',
    packageNames: ['com.instagram.android'],
    color: Color(0xFFE4405F),
  ),
  _TrackedUsageApp(
    appName: 'YouTube',
    packageNames: ['com.google.android.youtube'],
    packagePrefixes: ['app.revanced.android.youtube'],
    color: Color(0xFFFF0000),
  ),
  _TrackedUsageApp(
    appName: 'TikTok',
    packageNames: ['com.zhiliaoapp.musically'],
    color: Color(0xFF111111),
  ),
  _TrackedUsageApp(
    appName: 'Snapchat',
    packageNames: ['com.snapchat.android'],
    color: Color(0xFFF7D64A),
  ),
  _TrackedUsageApp(
    appName: 'Facebook',
    packageNames: ['com.facebook.katana'],
    color: Color(0xFF1877F2),
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _accessibilityChannel = MethodChannel('lockin/accessibility');

  int _selectedIndex = 0;
  int _screenFadeKey = 0;
  bool? _isAccessibilityEnabled;
  bool? _isUsageAccessEnabled;
  bool _bypassAccessibilityGate = false;
  DateTime _trackerMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _appInstalledOn = DateTime.now();
  List<AppUsageSegment> _usageSegments = const [];
  Set<String>? _installedTrackedPackages;
  String _blockCategory = 'Apps';
  final Set<String> _expandedApps = {};
  final Map<String, int?> _dailyTimeLimits = {
    'instagram_app': null,
    'youtube_app': null,
    'tiktok_app': null,
    'snapchat_app': null,
    'facebook_app': null,
  };
  final Map<String, bool> _blockSettings = {
    'instagram_reels': false,
    'instagram_explore': false,
    'youtube_shorts': false,
    'youtube_home_feed': false,
    'tiktok_for_you': false,
    'tiktok_live': false,
    'snapchat_spotlight': false,
    'snapchat_discover': false,
    'facebook_reels': false,
    'facebook_watch': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccessibilityStatus();
    _refreshUsageAccessStatus();
    _loadSavedBlockConfig();
    _refreshInstalledTrackedPackages();
    _refreshUsageStats();
    _loadAppInstallDate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAccessibilityStatus();
      _refreshUsageAccessStatus();
      _refreshInstalledTrackedPackages();
      _refreshUsageStats();
    }
  }

  Future<void> _refreshAccessibilityStatus() async {
    try {
      final enabled = await _accessibilityChannel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      if (!mounted) return;
      setState(() {
        _isAccessibilityEnabled = enabled ?? false;
        if (_isAccessibilityEnabled == true) {
          _bypassAccessibilityGate = false;
        }
      });
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

  Future<void> _openUsageAccessSettings() async {
    try {
      await _accessibilityChannel.invokeMethod<void>(
        'openUsageAccessSettings',
      );
    } on PlatformException {
      // Android-only setup. Other platforms can still render the app shell.
    } on MissingPluginException {
      // Android-only setup. Other platforms can still render the app shell.
    }
  }

  Future<void> _refreshUsageAccessStatus() async {
    try {
      final enabled = await _accessibilityChannel.invokeMethod<bool>(
        'isUsageAccessEnabled',
      );
      if (!mounted) return;
      setState(() {
        _isUsageAccessEnabled = enabled ?? false;
      });
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
      if (!mounted || usageStats == null) return;
      setState(() {
        _usageSegments = _usageSegmentsFromStats(usageStats);
      });
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
      final savedConfig = await _accessibilityChannel.invokeMapMethod<String, dynamic>(
        'getSavedBlockConfig',
      );
      if (!mounted || savedConfig == null) return;

      final rawDailyTimeLimits =
          savedConfig['dailyTimeLimits'] as Map<dynamic, dynamic>?;
      final rawBlockSettings =
          savedConfig['blockSettings'] as Map<dynamic, dynamic>?;

      setState(() {
        if (rawDailyTimeLimits != null) {
          for (final entry in rawDailyTimeLimits.entries) {
            final key = entry.key;
            if (key is String && _dailyTimeLimits.containsKey(key)) {
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
      });
    } on PlatformException {
      // Android-only persistence. Other platforms use in-memory defaults.
    } on MissingPluginException {
      // Android-only persistence. Other platforms use in-memory defaults.
    }
  }

  Future<void> _setNativeDailyTimeLimit(String settingKey, int? minutes) async {
    try {
      await _accessibilityChannel.invokeMethod<void>(
        'setDailyTimeLimit',
        {
          'settingKey': settingKey,
          'minutes': minutes,
        },
      );
    } on PlatformException {
      // Android-only enforcement. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only enforcement. Other platforms keep local UI state only.
    }
  }

  Future<void> _setNativeBlockSetting(String settingKey, bool value) async {
    try {
      await _accessibilityChannel.invokeMethod<void>(
        'setBlockSetting',
        {
          'settingKey': settingKey,
          'value': value,
        },
      );
    } on PlatformException {
      // Android-only enforcement. Other platforms keep local UI state only.
    } on MissingPluginException {
      // Android-only enforcement. Other platforms keep local UI state only.
    }
  }

  Future<void> _refreshInstalledTrackedPackages() async {
    try {
      final installedPackages =
          await _accessibilityChannel.invokeListMethod<String>(
        'getInstalledTrackedPackages',
      );
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
      final totalMinutes = app.packageNames.fold<int>(
        0,
        (sum, packageName) => sum + (minutesByPackage[packageName] ?? 0),
      ) +
          minutesByPackage.entries.fold<int>(
            0,
            (sum, entry) => app.packagePrefixes.any(
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
    return segments;
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
      _screenFadeKey++;
    });
  }

  List<Widget> _buildScreens(BuildContext context) {
    return [
      HomeOverview(
        trackerMonth: _trackerMonth,
        usageSegments: _usageSegments,
        blockSettings: _blockSettings,
        dailyTimeLimits: _dailyTimeLimits,
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
          _selectTab(0);
        },
        selectedCategory: _blockCategory,
        expandedApps: _expandedApps,
        installedPackageNames: _installedTrackedPackages,
        dailyTimeLimits: _dailyTimeLimits,
        blockSettings: _blockSettings,
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
          _selectTab(0);
        },
      ),
      SettingsTab(
        onBackToHome: () {
          _selectTab(0);
        },
        onOpenAccessibilitySettings: _openAccessibilitySettings,
        onOpenUsageAccessSettings: _openUsageAccessSettings,
        isAccessibilityAllowed: _isAccessibilityEnabled == true,
        isUsageAccessAllowed: _isUsageAccessEnabled == true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isAccessibilityEnabled != true && !_bypassAccessibilityGate) {
      return Scaffold(
        backgroundColor: appBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'To use Tempus, you must enable Accessibility.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tempus will stay on this screen until Accessibility is enabled.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appMutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _openAccessibilitySettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Open Accessibility Settings'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refreshAccessibilityStatus,
                  child: const Text('Check again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _bypassAccessibilityGate = true;
                    });
                  },
                  child: const Text('Bypass for Chrome testing'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: ColoredBox(
          color: appBackground,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_screenFadeKey),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: child,
              );
            },
            child: IndexedStack(
              index: _selectedIndex,
              children: _buildScreens(context),
            ),
          ),
        ),
      ),
      bottomNavigationBar: InstagramBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          _selectTab(index);
        },
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
