import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const brand = Color(0xFF00688F);

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

  static const _tabs = ['Home', 'Reels', 'Messages', 'Search', 'Profile'];

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

  String get _setupMessage {
    final accessibilityEnabled = _isAccessibilityEnabled == true;

    if (accessibilityEnabled) {
      return 'Instagram guard is enabled.';
    }
    return 'Enable Lockin in Accessibility settings so it can detect Instagram opening.';
  }

  @override
  Widget build(BuildContext context) {
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
                _tabs[_selectedIndex],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _setupMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFD8DCE2),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
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
              TextButton(
                onPressed: _refreshAccessibilityStatus,
                child: const Text('Refresh status'),
              ),
            ],
          ),
        ),
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
      padding: EdgeInsets.fromLTRB(18, 10, 18, bottomPadding + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _BottomNavItem(
                icon: Icons.smart_display_outlined,
                selectedIcon: Icons.smart_display,
                label: 'Reels',
                isSelected: selectedIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              _BottomNavItem(
                icon: Icons.near_me_outlined,
                selectedIcon: Icons.near_me,
                label: 'Messages',
                hasBadge: true,
                isSelected: selectedIndex == 2,
                onTap: () => onTabSelected(2),
              ),
              _BottomNavItem(
                icon: Icons.search,
                selectedIcon: Icons.search,
                label: 'Search',
                isSelected: selectedIndex == 3,
                onTap: () => onTabSelected(3),
              ),
              _ProfileNavItem(
                isSelected: selectedIndex == 4,
                onTap: () => onTabSelected(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hasBadge = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool hasBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 54,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: Colors.white,
                size: 33,
              ),
              if (hasBadge)
                Positioned(
                  right: 7,
                  top: 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  const _ProfileNavItem({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Profile',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 54,
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 3 : 2.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
