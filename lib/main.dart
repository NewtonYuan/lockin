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
      title: 'Lockin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
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
  static const _accessibilityChannel = MethodChannel('lockin/accessibility');

  int _selectedIndex = 0;
  bool? _isAccessibilityEnabled;
  bool _bypassAccessibilityGate = false;
  String _blockCategory = 'Apps';
  final Set<String> _expandedApps = {'Instagram'};
  final Map<String, int?> _dailyTimeLimits = {
    'instagram_app': 10,
    'youtube_app': 15,
    'tiktok_app': 30,
    'snapchat_app': 5,
    'facebook_app': 10,
  };
  final Map<String, bool> _blockSettings = {
    'instagram_reels': true,
    'instagram_explore': true,
    'youtube_shorts': true,
    'youtube_home_feed': false,
    'tiktok_for_you': true,
    'tiktok_live': false,
    'snapchat_spotlight': true,
    'snapchat_discover': false,
    'facebook_reels': true,
    'facebook_watch': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccessibilityStatus();
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

  Widget _buildCurrentScreen(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return HomeOverview(
          onOpenAccessibilitySettings: _openAccessibilitySettings,
        );
      case 1:
        return BlockScreen(
          selectedCategory: _blockCategory,
          expandedApps: _expandedApps,
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
          },
          onSelectTimeLimit: (settingKey, minutes) {
            setState(() {
              _dailyTimeLimits[settingKey] = minutes;
            });
          },
        );
      case 2:
        return const StatisticsTab();
      case 3:
        return const SettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAccessibilityEnabled != true && !_bypassAccessibilityGate) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'To use Lockin, you must enable Accessibility.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Lockin will stay on this screen until Accessibility is enabled.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFD8DCE2),
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildCurrentScreen(context),
      ),
      bottomNavigationBar: InstagramBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
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
        color: Color(0xFF05080C),
        border: Border(top: BorderSide(color: Color(0xFF141820), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(18, 6, 18, bottomPadding + 4),
      child: Row(
        children: [
          _BottomNavItem(
            assetPath: 'assets/icons/home.svg',
            label: 'Home',
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
            label: 'Statistics',
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
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: SizedBox(
            height: 42,
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(
                  isSelected ? Colors.white : const Color(0xFF8A8D91),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
