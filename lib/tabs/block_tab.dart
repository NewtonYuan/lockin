import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';
import 'sticky_header.dart';

class BlockedWebsiteEntry {
  const BlockedWebsiteEntry({
    required this.domain,
    required this.blockedSince,
    this.isEnabled = true,
  });

  final String domain;
  final DateTime blockedSince;
  final bool isEnabled;
}

class CustomTrackedApp {
  const CustomTrackedApp({
    required this.appName,
    required this.packageName,
    this.iconBytes,
  });

  factory CustomTrackedApp.fromMap(Map<dynamic, dynamic> map) {
    return CustomTrackedApp(
      appName: map['appName'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      iconBytes: map['iconBytes'] as Uint8List?,
    );
  }

  final String appName;
  final String packageName;
  final Uint8List? iconBytes;

  String get settingKey => customTrackedAppSettingKey(packageName);

  Map<String, Object?> toMap() => {
    'appName': appName,
    'packageName': packageName,
    'iconBytes': iconBytes,
  };
}

class InstalledAppSelection {
  const InstalledAppSelection({
    required this.app,
    required this.minutes,
    required this.pauseOnOpen,
  });

  final CustomTrackedApp app;
  final int? minutes;
  final bool pauseOnOpen;
}

String customTrackedAppSettingKey(String packageName) {
  final normalized = packageName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
  return 'custom_app_$normalized';
}

String customTrackedAppPauseOnOpenSettingKey(String packageName) {
  final normalized = packageName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
  return 'custom_app_pause_on_open_$normalized';
}

class BlockScreen extends StatelessWidget {
  const BlockScreen({
    super.key,
    required this.onBackToHome,
    required this.selectedCategory,
    required this.expandedApps,
    required this.installedPackageNames,
    required this.customTrackedApps,
    required this.blockedWebsites,
    required this.dailyTimeLimits,
    required this.blockSettings,
    required this.onAddWebsite,
    required this.onDeleteWebsite,
    required this.onToggleWebsiteBlocked,
    required this.onRequestInstalledApps,
    required this.onAddCustomTrackedApp,
    required this.onDeleteCustomTrackedApp,
    required this.onSelectCategory,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
    required this.pauseDurationSeconds,
    required this.onPauseDurationChanged,
    required this.isPremium,
    required this.onOpenPremium,
    required this.isAccessibilityAllowed,
    required this.isOverlayPermissionAllowed,
    required this.onOpenAccessibilitySettings,
    required this.onOpenOverlayPermissionSettings,
  });

  final VoidCallback onBackToHome;
  final String selectedCategory;
  final Set<String> expandedApps;
  final Set<String>? installedPackageNames;
  final List<CustomTrackedApp> customTrackedApps;
  final List<BlockedWebsiteEntry> blockedWebsites;
  final Map<String, int?> dailyTimeLimits;
  final Map<String, bool> blockSettings;
  final bool Function(String value) onAddWebsite;
  final ValueChanged<BlockedWebsiteEntry> onDeleteWebsite;
  final void Function(BlockedWebsiteEntry entry, bool value)
  onToggleWebsiteBlocked;
  final Future<List<CustomTrackedApp>> Function() onRequestInstalledApps;
  final ValueChanged<InstalledAppSelection> onAddCustomTrackedApp;
  final ValueChanged<CustomTrackedApp> onDeleteCustomTrackedApp;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onToggleExpanded;
  final void Function(String settingKey, bool value) onToggleSetting;
  final void Function(String settingKey, int? minutes) onSelectTimeLimit;
  final int pauseDurationSeconds;
  final ValueChanged<int> onPauseDurationChanged;
  final bool isPremium;
  final VoidCallback onOpenPremium;
  final bool isAccessibilityAllowed;
  final bool isOverlayPermissionAllowed;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenOverlayPermissionSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StickyTitleHeader(
            title: 'Block',
            onBack: onBackToHome,
            centerTitle: false,
            trailing: IconButton(
              onPressed: () => _showBlockSettingsSheet(context),
              icon: SvgPicture.asset(
                'assets/icons/settings.svg',
                width: 27,
                height: 27,
                colorFilter: const ColorFilter.mode(appText, BlendMode.srcIn),
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CategoryTab(
                label: 'Apps',
                selected: selectedCategory == 'Apps',
                onTap: () => onSelectCategory('Apps'),
              ),
              const SizedBox(width: 32),
              _CategoryTab(
                label: 'Websites',
                selected: selectedCategory == 'Websites',
                onTap: () => onSelectCategory('Websites'),
              ),
            ],
          ),
        ),
        if (!isAccessibilityAllowed) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AccessibilityErrorBanner(
              onTap: onOpenAccessibilitySettings,
            ),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 14),
        Expanded(
          child: _CategoryPageView(
            selectedCategory: selectedCategory,
            onSelectCategory: onSelectCategory,
            appsChild: KeyedSubtree(
              key: const PageStorageKey('block_apps'),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildAppCategoryChildren(context),
                ),
              ),
            ),
            websitesChild: KeyedSubtree(
              key: const PageStorageKey('block_websites'),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _WebsiteBlockPanel(
                  blockedWebsites: blockedWebsites,
                  onAddWebsite: onAddWebsite,
                  onDeleteWebsite: onDeleteWebsite,
                  onToggleWebsiteBlocked: onToggleWebsiteBlocked,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppCategoryChildren(BuildContext context) {
    final children = <Widget>[
      const _AppSectionHeader(label: 'Built-In'),
      const SizedBox(height: 8),
      _AppBlockCard(
        appName: 'Instagram',
        iconAssetPath: 'assets/apps/instagram.svg',
        isInstalled: _isPackageInstalled('com.instagram.android'),
        isExpanded: expandedApps.contains('Instagram'),
        items: [
          _BlockItemData.timeLimit(
            keyName: 'instagram_app',
            label: 'Daily Time Limit',
            minutes: dailyTimeLimits['instagram_app'],
            iconAssetPath: 'assets/icons/timer.svg',
            iconSize: 24,
          ),
          _BlockItemData.toggle(
            keyName: 'instagram_pause_on_open',
            label: 'Pause on Open',
            value: blockSettings['instagram_pause_on_open'] ?? false,
            iconAssetPath: 'assets/icons/pause_on_open.svg',
            iconSize: 24,
          ),
          _BlockItemData.toggle(
            keyName: 'instagram_reels',
            label: 'Block Reels',
            value: blockSettings['instagram_reels'] ?? false,
          ),
          _BlockItemData.toggle(
            keyName: 'instagram_reels_dms',
            label: 'Allow Reels in DMs',
            value: blockSettings['instagram_reels_dms'] ?? false,
            iconAssetPath: 'assets/icons/instagram_reels_dm.svg',
            iconSize: 24,
            isSubItem: true,
            useCheckbox: true,
            isPremiumOnly: true,
          ),
          _BlockItemData.toggle(
            keyName: 'instagram_explore',
            label: 'Block Stories',
            value: blockSettings['instagram_explore'] ?? false,
          ),
          _BlockItemData.toggle(
            keyName: 'instagram_hide_explore_feed',
            label: 'Hide Explore Feed',
            value: blockSettings['instagram_hide_explore_feed'] ?? false,
            isPremiumOnly: true,
          ),
        ],
        onToggleExpanded: () => onToggleExpanded('Instagram'),
        onToggleSetting: onToggleSetting,
        onSelectTimeLimit: onSelectTimeLimit,
        isPremium: isPremium,
        onOpenPremium: onOpenPremium,
        showExplorePermissionBanner: isPremium && !isOverlayPermissionAllowed,
        onOpenExplorePermissionSettings: onOpenOverlayPermissionSettings,
      ),
      const SizedBox(height: 8),
      _AppBlockCard(
        appName: 'YouTube',
        iconAssetPath: 'assets/apps/youtube.svg',
        isInstalled: _isAnyPackageInstalled(
          exactPackageNames: ['com.google.android.youtube'],
          packagePrefixes: ['app.revanced.android.youtube'],
        ),
        isExpanded: expandedApps.contains('YouTube'),
        items: [
          _BlockItemData.timeLimit(
            keyName: 'youtube_app',
            label: 'Daily Time Limit',
            minutes: dailyTimeLimits['youtube_app'],
            iconAssetPath: 'assets/icons/timer.svg',
            iconSize: 24,
          ),
          _BlockItemData.toggle(
            keyName: 'youtube_pause_on_open',
            label: 'Pause on Open',
            value: blockSettings['youtube_pause_on_open'] ?? false,
            iconAssetPath: 'assets/icons/pause_on_open.svg',
            iconSize: 24,
          ),
          _BlockItemData.toggle(
            keyName: 'youtube_shorts',
            label: 'Block Shorts',
            value: blockSettings['youtube_shorts'] ?? false,
          ),
        ],
        onToggleExpanded: () => onToggleExpanded('YouTube'),
        onToggleSetting: onToggleSetting,
        onSelectTimeLimit: onSelectTimeLimit,
        isPremium: isPremium,
        onOpenPremium: onOpenPremium,
      ),
      const SizedBox(height: 8),
      _AppBlockCard(
        appName: 'Snapchat',
        iconAssetPath: 'assets/apps/snapchat.svg',
        isInstalled: _isPackageInstalled('com.snapchat.android'),
        isExpanded: expandedApps.contains('Snapchat'),
        items: [
          _BlockItemData.timeLimit(
            keyName: 'snapchat_app',
            label: 'Daily Time Limit',
            minutes: dailyTimeLimits['snapchat_app'],
            iconAssetPath: 'assets/icons/timer.svg',
            iconSize: 24,
          ),
          _BlockItemData.toggle(
            keyName: 'snapchat_pause_on_open',
            label: 'Pause on Open',
            value: blockSettings['snapchat_pause_on_open'] ?? false,
            iconAssetPath: 'assets/icons/pause_on_open.svg',
            iconSize: 24,
          ),
          _BlockItemData.toggle(
            keyName: 'snapchat_spotlight',
            label: 'Block Spotlight',
            value: blockSettings['snapchat_spotlight'] ?? false,
          ),
        ],
        onToggleExpanded: () => onToggleExpanded('Snapchat'),
        onToggleSetting: onToggleSetting,
        onSelectTimeLimit: onSelectTimeLimit,
        isPremium: isPremium,
        onOpenPremium: onOpenPremium,
      ),
    ];

    children.add(const SizedBox(height: 14));
    children.add(
      _AppSectionHeader(
        label: 'Additional',
        trailingText: isPremium ? null : '${customTrackedApps.length}/5',
        onTrailingTap: isPremium ? null : onOpenPremium,
      ),
    );

    for (final app in customTrackedApps) {
      children.add(const SizedBox(height: 8));
      children.add(
        _AdditionalTrackedAppCard(
          app: app,
          minutes: dailyTimeLimits[app.settingKey],
          pauseOnOpen:
              blockSettings[customTrackedAppPauseOnOpenSettingKey(
                app.packageName,
              )] ??
              false,
          isExpanded: expandedApps.contains(app.packageName),
          onToggleExpanded: () => onToggleExpanded(app.packageName),
          onSelectTimeLimit: (minutes) =>
              onSelectTimeLimit(app.settingKey, minutes),
          onTogglePauseOnOpen: (value) => onToggleSetting(
            customTrackedAppPauseOnOpenSettingKey(app.packageName),
            value,
          ),
          onRemoveApp: () => onDeleteCustomTrackedApp(app),
          onOpenPremium: onOpenPremium,
        ),
      );
    }

    children.add(const SizedBox(height: 8));
    children.add(_AddAppCard(onTap: () => _promptForInstalledApp(context)));
    return children;
  }

  Future<void> _showBlockSettingsSheet(BuildContext context) async {
    await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BlockSettingsSheet(
        pauseDurationSeconds: pauseDurationSeconds,
        onPauseDurationChanged: onPauseDurationChanged,
      ),
    );
  }

  Future<void> _promptForInstalledApp(BuildContext context) async {
    final existingPackages = <String>{
      'com.instagram.android',
      'com.snapchat.android',
      'com.google.android.youtube',
      ...customTrackedApps.map((app) => app.packageName),
    };
    final selectedApp = await showModalBottomSheet<InstalledAppSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InstalledAppPickerSheet(
        loadInstalledApps: () async {
          final installedApps = await onRequestInstalledApps();
          return installedApps.where((app) {
            if (existingPackages.contains(app.packageName)) {
              return false;
            }
            if (app.packageName.startsWith('app.revanced.android.youtube')) {
              return false;
            }
            return true;
          }).toList()..sort(
            (first, second) => first.appName.toLowerCase().compareTo(
              second.appName.toLowerCase(),
            ),
          );
        },
      ),
    );
    if (selectedApp == null) return;
    onAddCustomTrackedApp(selectedApp);
  }

  bool _isPackageInstalled(String packageName) {
    return installedPackageNames?.contains(packageName) ?? true;
  }

  bool _isAnyPackageInstalled({
    required List<String> exactPackageNames,
    List<String> packagePrefixes = const [],
  }) {
    final installedPackages = installedPackageNames;
    if (installedPackages == null) return true;
    return installedPackages.any(
      (packageName) =>
          exactPackageNames.contains(packageName) ||
          packagePrefixes.any((prefix) => packageName.startsWith(prefix)),
    );
  }
}

class _BlockSettingsSheet extends StatefulWidget {
  const _BlockSettingsSheet({
    required this.pauseDurationSeconds,
    required this.onPauseDurationChanged,
  });

  final int pauseDurationSeconds;
  final ValueChanged<int> onPauseDurationChanged;

  @override
  State<_BlockSettingsSheet> createState() => _BlockSettingsSheetState();
}

class _BlockSettingsSheetState extends State<_BlockSettingsSheet> {
  late int _pauseDurationSeconds = widget.pauseDurationSeconds;

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                Text(
                  'Block Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: appSurface,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final selected = await _showPauseDurationPicker(
                        context,
                        initialSeconds: _pauseDurationSeconds,
                      );
                      if (!mounted || selected == null) return;
                      setState(() {
                        _pauseDurationSeconds = selected;
                      });
                      widget.onPauseDurationChanged(selected);
                    },
                    child: SizedBox(
                      height: 52,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pause duration',
                                style: TextStyle(
                                  color: appText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              _pauseDurationSeconds == 1
                                  ? '1 second'
                                  : '$_pauseDurationSeconds seconds',
                              style: const TextStyle(
                                color: appMutedText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: appMutedText,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<int?> _showPauseDurationPicker(
  BuildContext context, {
  required int initialSeconds,
}) async {
  final values = List<int>.generate(16, (index) => index);
  var selectedSeconds = initialSeconds.clamp(0, 15);
  final controller = FixedExtentScrollController(initialItem: selectedSeconds);

  final selected = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
              child: Material(
                color: appBackground,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                      Text(
                        'Pause duration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: appText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 180,
                        child: _DurationWheel(
                          controller: controller,
                          values: values,
                          labelBuilder: (value) =>
                              value == 1 ? '1 second' : '$value seconds',
                          onSelectedItemChanged: (value) {
                            setState(() {
                              selectedSeconds = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(
                                dialogContext,
                              ).pop(selectedSeconds),
                              child: const Text('Save'),
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
        },
      );
    },
  );

  controller.dispose();
  return selected;
}

class _AccessibilityErrorBanner extends StatelessWidget {
  const _AccessibilityErrorBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4F2),
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: brand.withValues(alpha: 0.10),
          highlightColor: appText.withValues(alpha: 0.03),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/error.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFC65A43),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Accessibility is off',
                    style: TextStyle(
                      color: Color(0xFFC65A43),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Fix',
                  style: TextStyle(
                    color: Color(0xFFC65A43),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC65A43),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPermissionErrorBanner extends StatelessWidget {
  const _OverlayPermissionErrorBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4F2),
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: brand.withValues(alpha: 0.10),
          highlightColor: appText.withValues(alpha: 0.03),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  Icons.layers_clear_rounded,
                  color: Color(0xFFC65A43),
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: Color(0xFFC65A43),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: 'Requires '),
                        TextSpan(
                          text: 'Display Over Apps',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' permissions'),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
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
      ),
    );
  }
}

class _CategoryPageView extends StatefulWidget {
  const _CategoryPageView({
    required this.selectedCategory,
    required this.onSelectCategory,
    required this.appsChild,
    required this.websitesChild,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;
  final Widget appsChild;
  final Widget websitesChild;

  @override
  State<_CategoryPageView> createState() => _CategoryPageViewState();
}

class _CategoryPageViewState extends State<_CategoryPageView> {
  late final PageController _pageController = PageController(
    initialPage: _categoryIndex(widget.selectedCategory),
  );

  @override
  void didUpdateWidget(covariant _CategoryPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory == widget.selectedCategory ||
        !_pageController.hasClients) {
      return;
    }
    final targetPage = _categoryIndex(widget.selectedCategory);
    final currentPage = (_pageController.page ?? _pageController.initialPage)
        .round();
    if (currentPage == targetPage) return;
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        final category = index == 0 ? 'Apps' : 'Websites';
        if (category != widget.selectedCategory) {
          widget.onSelectCategory(category);
        }
      },
      children: [widget.appsChild, widget.websitesChild],
    );
  }

  int _categoryIndex(String category) {
    switch (category) {
      case 'Websites':
        return 1;
      case 'Apps':
      default:
        return 0;
    }
  }
}

class _AppSectionHeader extends StatelessWidget {
  const _AppSectionHeader({
    required this.label,
    this.trailingText,
    this.onTrailingTap,
  });

  final String label;
  final String? trailingText;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style:
              Theme.of(context).textTheme.labelLarge?.copyWith(
                color: appMutedText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ) ??
              const TextStyle(
                color: appMutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: appBorder, height: 1, thickness: 1),
        ),
        if (trailingText != null) ...[
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            splashColor: brand.withValues(alpha: 0.14),
            highlightColor: appText.withValues(alpha: 0.03),
            onTap: onTrailingTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                trailingText!,
                style:
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: appMutedText,
                      fontWeight: FontWeight.w800,
                    ) ??
                    const TextStyle(
                      color: appMutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AdditionalTrackedAppCard extends StatelessWidget {
  const _AdditionalTrackedAppCard({
    required this.app,
    required this.minutes,
    required this.pauseOnOpen,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onSelectTimeLimit,
    required this.onTogglePauseOnOpen,
    required this.onRemoveApp,
    required this.onOpenPremium,
  });

  final CustomTrackedApp app;
  final int? minutes;
  final bool pauseOnOpen;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int?> onSelectTimeLimit;
  final ValueChanged<bool> onTogglePauseOnOpen;
  final VoidCallback onRemoveApp;
  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    return _AppBlockCard(
      appName: app.appName,
      iconBytes: app.iconBytes,
      isInstalled: true,
      isExpanded: isExpanded,
      items: [
        _BlockItemData.timeLimit(
          keyName: app.settingKey,
          label: 'Daily Time Limit',
          minutes: minutes,
          iconAssetPath: 'assets/icons/timer.svg',
          iconSize: 24,
        ),
        _BlockItemData.toggle(
          keyName: customTrackedAppPauseOnOpenSettingKey(app.packageName),
          label: 'Pause on Open',
          value: pauseOnOpen,
          iconAssetPath: 'assets/icons/pause_on_open.svg',
          iconSize: 24,
        ),
        const _BlockItemData.action(
          keyName: '__remove_app__',
          label: 'Remove App',
          iconAssetPath: 'assets/icons/delete_forever.svg',
          iconSize: 24,
        ),
      ],
      onToggleExpanded: onToggleExpanded,
      onToggleSetting: (settingKey, value) => onTogglePauseOnOpen(value),
      onSelectTimeLimit: (_, minutes) => onSelectTimeLimit(minutes),
      onActionPressed: (_) => onRemoveApp(),
      isPremium: true,
      onOpenPremium: onOpenPremium,
    );
  }
}

class _AddAppCard extends StatelessWidget {
  const _AddAppCard({required this.onTap});

  static const double _rowMinHeight = 52;
  static const double _iconBoxSize = 28;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);

    return Material(
      color: appSurface,
      borderRadius: borderRadius,
      child: Ink(
        decoration: BoxDecoration(borderRadius: borderRadius),
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: brand.withValues(alpha: 0.18),
          highlightColor: appText.withValues(alpha: 0.04),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: _iconBoxSize,
                    height: _iconBoxSize,
                    decoration: BoxDecoration(
                      color: appSurfaceStrong,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: brand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Add App',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: appMutedText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstalledAppPickerSheet extends StatefulWidget {
  const _InstalledAppPickerSheet({required this.loadInstalledApps});

  final Future<List<CustomTrackedApp>> Function() loadInstalledApps;

  @override
  State<_InstalledAppPickerSheet> createState() =>
      _InstalledAppPickerSheetState();
}

class _InstalledAppPickerSheetState extends State<_InstalledAppPickerSheet> {
  static const _loadDelay = Duration(milliseconds: 260);
  static const _pickerRowMinHeight = 52.0;
  static const _pickerIconBoxSize = 28.0;

  String _query = '';
  Future<List<CustomTrackedApp>>? _installedAppsFuture;
  CustomTrackedApp? _selectedApp;
  int? _selectedMinutes;
  bool _selectedPauseOnOpen = false;
  late final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(_loadDelay, () {
        if (!mounted) return;
        setState(() {
          _installedAppsFuture = widget.loadInstalledApps();
        });
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          top: 24,
        ),
        child: Material(
          color: appBackground,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 520,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildListPage(context), _buildDetailPage(context)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
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
          Text(
            'Select an Installed App',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appText,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CustomTrackedApp>>(
              future: _installedAppsFuture,
              builder: (context, snapshot) {
                if (_installedAppsFuture == null ||
                    snapshot.connectionState != ConnectionState.done) {
                  return const _InstalledAppsLoadingState();
                }
                if (snapshot.hasError) {
                  return const _InstalledAppsMessageState(
                    message: 'Could not load installed apps.',
                  );
                }

                final installedApps =
                    snapshot.data ?? const <CustomTrackedApp>[];
                final filteredApps = installedApps.where((app) {
                  final normalizedQuery = _query.trim().toLowerCase();
                  if (normalizedQuery.isEmpty) return true;
                  return app.appName.toLowerCase().contains(normalizedQuery) ||
                      app.packageName.toLowerCase().contains(normalizedQuery);
                }).toList();

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search apps',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: appSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: installedApps.isEmpty
                          ? const _InstalledAppsMessageState(
                              message:
                                  'No additional installed apps available.',
                            )
                          : ListView.separated(
                              itemCount: filteredApps.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1, color: appBorder),
                              itemBuilder: (context, index) {
                                final app = filteredApps[index];
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedApp = app;
                                      _selectedMinutes = null;
                                      _selectedPauseOnOpen = false;
                                    });
                                    _pageController.animateToPage(
                                      1,
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    );
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: _pickerRowMinHeight,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: _pickerIconBoxSize,
                                            height: _pickerIconBoxSize,
                                            decoration: BoxDecoration(
                                              color: appSurfaceStrong,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: app.iconBytes != null
                                                  ? Image.memory(
                                                      app.iconBytes!,
                                                      fit: BoxFit.fill,
                                                    )
                                                  : Center(
                                                      child: Text(
                                                        app.appName.isEmpty
                                                            ? '?'
                                                            : app.appName
                                                                  .substring(
                                                                    0,
                                                                    1,
                                                                  )
                                                                  .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: appText,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              app.appName,
                                              style: const TextStyle(
                                                color: appText,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: appMutedText,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPage(BuildContext context) {
    final app = _selectedApp;
    if (app == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
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
              IconButton(
                onPressed: () async {
                  await _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                  if (!mounted) return;
                  setState(() {
                    _selectedApp = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded, color: appText),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  app.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: appSurface,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showDailyTimeLimitPicker(
                    context,
                    initialMinutes: _selectedMinutes,
                    onTimeLimitSelected: (minutes) {
                      setState(() {
                        _selectedMinutes = minutes;
                      });
                    },
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/timer.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              appMutedText,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Daily Time Limit',
                              style: TextStyle(
                                color: appText,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            _formatMinutes(_selectedMinutes),
                            style: const TextStyle(
                              color: appMutedText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: appMutedText,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _selectedPauseOnOpen = !_selectedPauseOnOpen;
                    });
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/pause_on_open.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              appMutedText,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Pause on Open',
                              style: TextStyle(
                                color: appText,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Switch(
                            value: _selectedPauseOnOpen,
                            onChanged: (value) {
                              setState(() {
                                _selectedPauseOnOpen = value;
                              });
                            },
                            activeThumbColor: brand,
                            inactiveThumbColor: appBackground,
                            inactiveTrackColor: appBorder,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  InstalledAppSelection(
                    app: app,
                    minutes: _selectedMinutes,
                    pauseOnOpen: _selectedPauseOnOpen,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteBlockPanel extends StatelessWidget {
  const _WebsiteBlockPanel({
    required this.blockedWebsites,
    required this.onAddWebsite,
    required this.onDeleteWebsite,
    required this.onToggleWebsiteBlocked,
  });

  final List<BlockedWebsiteEntry> blockedWebsites;
  final bool Function(String value) onAddWebsite;
  final ValueChanged<BlockedWebsiteEntry> onDeleteWebsite;
  final void Function(BlockedWebsiteEntry entry, bool value)
  onToggleWebsiteBlocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WebsiteEntryCard(onAddWebsite: onAddWebsite),
        if (blockedWebsites.isEmpty) ...[
          const SizedBox(height: 14),
          Material(
            color: appSurface,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
                child: Column(
                  children: [
                    SvgPicture.asset(
                      'assets/images/through_the_park_empty.svg',
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No blocked websites yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appMutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 14),
          for (var index = 0; index < blockedWebsites.length; index++) ...[
            _BlockedWebsiteRow(
              entry: blockedWebsites[index],
              onDelete: () => onDeleteWebsite(blockedWebsites[index]),
              onToggleBlocked: (value) =>
                  onToggleWebsiteBlocked(blockedWebsites[index], value),
            ),
            if (index < blockedWebsites.length - 1) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _WebsiteEntryCard extends StatefulWidget {
  const _WebsiteEntryCard({required this.onAddWebsite});

  final bool Function(String value) onAddWebsite;

  @override
  State<_WebsiteEntryCard> createState() => _WebsiteEntryCardState();
}

class _WebsiteEntryCardState extends State<_WebsiteEntryCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitWebsite() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    final didAdd = widget.onAddWebsite(value);
    if (didAdd) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.language_rounded, color: appMutedText, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: appBorder, width: 1),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submitWebsite(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Enter website URL',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appMutedText,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _submitWebsite,
              style: IconButton.styleFrom(
                backgroundColor: brand,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedWebsiteRow extends StatefulWidget {
  const _BlockedWebsiteRow({
    required this.entry,
    required this.onDelete,
    required this.onToggleBlocked,
  });

  final BlockedWebsiteEntry entry;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleBlocked;

  @override
  State<_BlockedWebsiteRow> createState() => _BlockedWebsiteRowState();
}

class _BlockedWebsiteRowState extends State<_BlockedWebsiteRow> {
  static const double _iconSize = 28;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final borderRadius = BorderRadius.circular(8);

    return Material(
      color: appSurface,
      borderRadius: borderRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ink(
            decoration: BoxDecoration(borderRadius: borderRadius),
            child: InkWell(
              borderRadius: borderRadius,
              splashColor: brand.withValues(alpha: 0.18),
              highlightColor: appText.withValues(alpha: 0.04),
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: _iconSize,
                        height: _iconSize,
                        decoration: BoxDecoration(
                          color: appSurfaceStrong,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _WebsiteFavicon(domain: entry.domain),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: appText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: appText,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BlockItemRow(
                          item: _BlockItemData.toggle(
                            keyName: '__block_website__',
                            label: 'Block Website',
                            value: entry.isEnabled,
                            iconAssetPath: 'assets/icons/block.svg',
                            iconSize: 24,
                          ),
                          isPremium: true,
                          onOpenPremium: () {},
                          onToggleChanged: widget.onToggleBlocked,
                          onTimeLimitSelected: (_) {},
                        ),
                        _BlockItemRow(
                          item: const _BlockItemData.action(
                            keyName: '__remove_website__',
                            label: 'Remove website',
                            iconAssetPath: 'assets/icons/delete_forever.svg',
                            iconSize: 24,
                          ),
                          isPremium: true,
                          onOpenPremium: () {},
                          onToggleChanged: (_) {},
                          onTimeLimitSelected: (_) {},
                          onActionPressed: (_) => widget.onDelete(),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteFavicon extends StatelessWidget {
  const _WebsiteFavicon({required this.domain});

  static const double _iconSize = 28;

  final String domain;

  String get _faviconUrl =>
      'https://www.google.com/s2/favicons?sz=64&domain_url=${Uri.encodeComponent('https://$domain')}';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _faviconUrl,
        width: _iconSize,
        height: _iconSize,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const _WebsiteFaviconFallback();
        },
        errorBuilder: (context, error, stackTrace) {
          return const _WebsiteFaviconFallback();
        },
      ),
    );
  }
}

class _WebsiteFaviconFallback extends StatelessWidget {
  const _WebsiteFaviconFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.public_rounded, color: appMutedText, size: 20),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? appText : appMutedText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 76,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? brand : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBlockCard extends StatelessWidget {
  const _AppBlockCard({
    required this.appName,
    this.iconAssetPath,
    this.iconBytes,
    required this.isInstalled,
    required this.isExpanded,
    required this.items,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
    required this.isPremium,
    required this.onOpenPremium,
    this.showExplorePermissionBanner = false,
    this.onOpenExplorePermissionSettings,
    this.onActionPressed,
  });

  final String appName;
  final String? iconAssetPath;
  final Uint8List? iconBytes;
  final bool isInstalled;
  final bool isExpanded;
  final List<_BlockItemData> items;
  final VoidCallback onToggleExpanded;
  final void Function(String settingKey, bool value) onToggleSetting;
  final void Function(String settingKey, int? minutes) onSelectTimeLimit;
  final bool isPremium;
  final VoidCallback onOpenPremium;
  final bool showExplorePermissionBanner;
  final VoidCallback? onOpenExplorePermissionSettings;
  final ValueChanged<String>? onActionPressed;

  static const double _headerMinHeight = 52;
  static const double _appIconSize = 28;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final titleColor = isInstalled ? appText : appMutedText;
    final iconOpacity = isInstalled ? 1.0 : 0.35;
    final canExpand = isInstalled;
    final shouldShowItems = isInstalled && isExpanded;
    final isDirectTimeLimitApp = items.length == 1 && items.first.isTimeLimit;

    if (isDirectTimeLimitApp) {
      return _SingleTimeLimitAppButton(
        appName: appName,
        iconAssetPath: iconAssetPath,
        iconBytes: iconBytes,
        isInstalled: isInstalled,
        minutes: items.first.minutes,
        onTap: isInstalled
            ? () => showDailyTimeLimitPicker(
                context,
                initialMinutes: items.first.minutes,
                onTimeLimitSelected: (minutes) =>
                    onSelectTimeLimit(items.first.keyName, minutes),
              )
            : null,
      );
    }

    return Material(
      color: appSurface,
      borderRadius: borderRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ink(
            decoration: BoxDecoration(borderRadius: borderRadius),
            child: InkWell(
              borderRadius: borderRadius,
              splashColor: brand.withValues(alpha: 0.18),
              highlightColor: appText.withValues(alpha: 0.04),
              onTap: canExpand ? onToggleExpanded : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _headerMinHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: _appIconSize,
                        height: _appIconSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Opacity(
                            opacity: iconOpacity,
                            child: SizedBox.expand(
                              child: iconAssetPath != null || iconBytes != null
                                  ? _BlockAppIcon(
                                      assetPath: iconAssetPath,
                                      iconBytes: iconBytes,
                                    )
                                  : Center(
                                      child: Text(
                                        appName.substring(0, 1),
                                        style: TextStyle(
                                          color: titleColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!isInstalled) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(Not Installed)',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: appMutedText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isInstalled)
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: appText,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: shouldShowItems
                  ? Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildItemChildren(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemChildren() {
    final children = <Widget>[];
    for (final item in items) {
      children.add(
        _BlockItemRow(
          item: item,
          isPremium: isPremium,
          onOpenPremium: onOpenPremium,
          onToggleChanged: (value) => onToggleSetting(item.keyName, value),
          onTimeLimitSelected: (minutes) =>
              onSelectTimeLimit(item.keyName, minutes),
          onActionPressed: onActionPressed,
        ),
      );
      if (_shouldShowExplorePermissionBannerFor(item)) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: _OverlayPermissionErrorBanner(
              onTap: onOpenExplorePermissionSettings!,
            ),
          ),
        );
      }
    }
    return children;
  }

  bool _shouldShowExplorePermissionBannerFor(_BlockItemData item) {
    return item.keyName == 'instagram_hide_explore_feed' &&
        showExplorePermissionBanner &&
        onOpenExplorePermissionSettings != null;
  }
}

class _InstalledAppsLoadingState extends StatelessWidget {
  const _InstalledAppsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(height: 24),
          CircularProgressIndicator(color: brand),
          SizedBox(height: 16),
          Text(
            'Loading installed apps...',
            style: TextStyle(
              color: appMutedText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              color: brand,
              backgroundColor: appSurfaceStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstalledAppsMessageState extends StatelessWidget {
  const _InstalledAppsMessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: appMutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SingleTimeLimitAppButton extends StatelessWidget {
  const _SingleTimeLimitAppButton({
    required this.appName,
    required this.iconAssetPath,
    required this.iconBytes,
    required this.isInstalled,
    required this.minutes,
    required this.onTap,
  });

  final String appName;
  final String? iconAssetPath;
  final Uint8List? iconBytes;
  final bool isInstalled;
  final int? minutes;
  final VoidCallback? onTap;

  static const double _rowMinHeight = 52;
  static const double _appIconSize = 28;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final titleColor = isInstalled ? appText : appMutedText;
    final iconOpacity = isInstalled ? 1.0 : 0.35;

    return Material(
      color: appSurface,
      borderRadius: borderRadius,
      child: Ink(
        decoration: BoxDecoration(borderRadius: borderRadius),
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: brand.withValues(alpha: 0.18),
          highlightColor: appText.withValues(alpha: 0.04),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: _appIconSize,
                    height: _appIconSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Opacity(
                        opacity: iconOpacity,
                        child: SizedBox.expand(
                          child: iconAssetPath != null || iconBytes != null
                              ? _BlockAppIcon(
                                  assetPath: iconAssetPath,
                                  iconBytes: iconBytes,
                                )
                              : Center(
                                  child: Text(
                                    appName.substring(0, 1),
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isInstalled) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(Not Installed)',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: appMutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isInstalled) ...[
                    Text(
                      _formatMinutes(minutes),
                      style: const TextStyle(
                        color: appMutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: appMutedText,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockAppIcon extends StatelessWidget {
  const _BlockAppIcon({this.assetPath, this.iconBytes})
    : assert(assetPath != null || iconBytes != null);

  final String? assetPath;
  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    if (iconBytes != null) {
      return Image.memory(iconBytes!, fit: BoxFit.fill);
    }
    final resolvedAssetPath = assetPath!;
    if (resolvedAssetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(resolvedAssetPath, fit: BoxFit.fill);
    }
    return Image.asset(resolvedAssetPath, fit: BoxFit.fill);
  }
}

class _BlockItemRow extends StatelessWidget {
  const _BlockItemRow({
    required this.item,
    required this.isPremium,
    required this.onOpenPremium,
    required this.onToggleChanged,
    required this.onTimeLimitSelected,
    this.onActionPressed,
  });
  static const double _rowMinHeight = 52;
  static const double _subItemMinHeight = 42;
  static const List<int> _hourValues = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
  ];
  static const List<int> _minuteIntervals = [0, 15, 30, 45];

  final _BlockItemData item;
  final bool isPremium;
  final VoidCallback onOpenPremium;
  final ValueChanged<bool> onToggleChanged;
  final ValueChanged<int?> onTimeLimitSelected;
  final ValueChanged<String>? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final isSubItem = item.isSubItem;
    final rowMinHeight = isSubItem ? _subItemMinHeight : _rowMinHeight;
    final horizontalPadding = isSubItem ? 14.0 : 16.0;
    final toggleHorizontalPadding = isSubItem ? 12.0 : 14.0;
    final leadingGap = isSubItem ? 8.0 : 10.0;
    final leadingInset = isSubItem ? 26.0 : 0.0;
    final isLockedPremium = item.isPremiumOnly && !isPremium;
    final lockedColor = appText.withValues(alpha: 0.42);
    final labelStyle = TextStyle(
      color: isLockedPremium ? lockedColor : appText,
      fontSize: 15,
      fontWeight: isSubItem ? FontWeight.w500 : FontWeight.w500,
    );
    final leading = item.iconAssetPath != null
        ? SvgPicture.asset(
            item.iconAssetPath!,
            width: isSubItem ? item.iconSize - 4 : item.iconSize - 2,
            height: isSubItem ? item.iconSize - 4 : item.iconSize - 2,
            colorFilter: const ColorFilter.mode(appMutedText, BlendMode.srcIn),
          )
        : const Icon(Icons.block_outlined, color: appMutedText, size: 22);

    if (item.isAction) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            splashColor: brand.withValues(alpha: 0.14),
            highlightColor: appText.withValues(alpha: 0.03),
            onTap: () => onActionPressed?.call(item.keyName),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: rowMinHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: toggleHorizontalPadding,
                ),
                child: Row(
                  children: [
                    SizedBox(width: leadingInset),
                    leading,
                    SizedBox(width: leadingGap),
                    Expanded(
                      child: Text(
                        item.label,
                        style: labelStyle.copyWith(color: appMutedText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (item.isTimeLimit) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            splashColor: brand.withValues(alpha: 0.14),
            highlightColor: appText.withValues(alpha: 0.03),
            onTap: () => _showTimeLimitPicker(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: rowMinHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    SizedBox(width: leadingInset),
                    leading,
                    SizedBox(width: leadingGap),
                    Expanded(child: Text(item.label, style: labelStyle)),
                    Text(
                      _formatMinutes(item.minutes),
                      style: const TextStyle(
                        color: appMutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: appMutedText,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: brand.withValues(alpha: 0.14),
          highlightColor: appText.withValues(alpha: 0.03),
          onTap: isLockedPremium
              ? onOpenPremium
              : () => onToggleChanged(!(item.value ?? false)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowMinHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: toggleHorizontalPadding,
              ),
              child: Row(
                children: [
                  SizedBox(width: leadingInset),
                  leading,
                  SizedBox(width: leadingGap),
                  Expanded(child: Text(item.label, style: labelStyle)),
                  if (isLockedPremium)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/diamond.svg',
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            lockedColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    )
                  else if (item.useCheckbox)
                    Transform.scale(
                      scale: 1.0,
                      child: Checkbox(
                        value: item.value ?? false,
                        onChanged: (value) => onToggleChanged(value ?? false),
                        activeColor: brand,
                        checkColor: appBackground,
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return brand;
                          }
                          return appBackground;
                        }),
                        side: WidgetStateBorderSide.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const BorderSide(color: brand, width: 1.5);
                          }
                          return const BorderSide(
                            color: appMutedText,
                            width: 1.8,
                          );
                        }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    Switch(
                      value: item.value ?? false,
                      onChanged: onToggleChanged,
                      activeThumbColor: brand,
                      inactiveThumbColor: appBackground,
                      inactiveTrackColor: appBorder,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTimeLimitPicker(BuildContext context) async {
    await showDailyTimeLimitPicker(
      context,
      initialMinutes: item.minutes,
      onTimeLimitSelected: onTimeLimitSelected,
    );
  }
}

class _DurationWheel extends StatelessWidget {
  const _DurationWheel({
    required this.controller,
    required this.values,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  static const double _itemExtent = 38;

  final FixedExtentScrollController controller;
  final List<int> values;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appBorder),
      ),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: _itemExtent,
        selectionOverlay: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: appBorder),
              bottom: BorderSide(color: appBorder),
            ),
          ),
        ),
        onSelectedItemChanged: (index) => onSelectedItemChanged(values[index]),
        children: List.generate(
          values.length,
          (index) => Center(
            child: Text(
              labelBuilder(values[index]),
              style: const TextStyle(
                color: appText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int _nearestMinuteInterval(int minute) {
  return _BlockItemRow._minuteIntervals.reduce(
    (best, current) =>
        (minute - current).abs() < (minute - best).abs() ? current : best,
  );
}

Future<void> showDailyTimeLimitPicker(
  BuildContext context, {
  required int? initialMinutes,
  required ValueChanged<int?> onTimeLimitSelected,
}) async {
  final resolvedInitialMinutes = initialMinutes != null && initialMinutes > 0
      ? initialMinutes
      : 0;
  var selectedHour = (resolvedInitialMinutes ~/ 60).clamp(0, 23);
  var selectedMinute = _nearestMinuteInterval(resolvedInitialMinutes % 60);
  final hourController = FixedExtentScrollController(
    initialItem: _BlockItemRow._hourValues.indexOf(selectedHour),
  );
  final minuteController = FixedExtentScrollController(
    initialItem: _BlockItemRow._minuteIntervals.indexOf(selectedMinute),
  );

  final selected = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: appBackground,
            surfaceTintColor: Colors.transparent,
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: const Column(
              children: [
                Text(
                  'Set Daily Limit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 148,
                  child: Row(
                    children: [
                      Expanded(
                        child: _DurationWheel(
                          controller: hourController,
                          values: _BlockItemRow._hourValues,
                          labelBuilder: _formatHourOption,
                          onSelectedItemChanged: (value) {
                            setState(() {
                              selectedHour = value;
                            });
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: appMutedText,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _DurationWheel(
                          controller: minuteController,
                          values: _BlockItemRow._minuteIntervals,
                          labelBuilder: _formatMinuteOption,
                          onSelectedItemChanged: (value) {
                            setState(() {
                              selectedMinute = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(child: Divider(color: appBorder)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: appMutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: appBorder)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(0),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        icon: SvgPicture.asset(
                          'assets/icons/no_limit.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            appMutedText,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: const Text('Unlimited'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(-1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        icon: SvgPicture.asset(
                          'assets/icons/block.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            appMutedText,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: const Text('Block'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(color: appBorder),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop((selectedHour * 60) + selectedMinute),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  hourController.dispose();
  minuteController.dispose();

  if (selected != null) {
    onTimeLimitSelected(selected == 0 ? null : selected);
  }
}

String _formatMinutes(int? minutes) {
  if (minutes == null) {
    return 'No Limit';
  }
  if (minutes == -10) {
    return '10 secs';
  }
  if (minutes < 0) {
    return 'Blocked';
  }
  if (minutes < 60) {
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
  if (minutes == 60) {
    return '1 hour';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  final parts = <String>[hours == 1 ? '1 hr' : '$hours hrs'];
  if (remainingMinutes > 0) {
    parts.add(remainingMinutes == 1 ? '1 min' : '$remainingMinutes mins');
  }
  return parts.join(', ');
}

String _formatHourOption(int hours) => hours == 1 ? '1 hr' : '$hours hrs';

String _formatMinuteOption(int minutes) =>
    minutes == 1 ? '1 min' : '$minutes mins';

class _BlockItemData {
  const _BlockItemData.toggle({
    required this.keyName,
    required this.label,
    required this.value,
    this.iconAssetPath,
    this.iconSize = 22,
    this.isSubItem = false,
    this.useCheckbox = false,
    this.isPremiumOnly = false,
  }) : minutes = null,
       isAction = false,
       isTimeLimit = false;

  const _BlockItemData.timeLimit({
    required this.keyName,
    required this.label,
    required this.minutes,
    this.iconAssetPath,
    this.iconSize = 22,
  }) : value = null,
       useCheckbox = false,
       isPremiumOnly = false,
       isSubItem = false,
       isAction = false,
       isTimeLimit = true;

  const _BlockItemData.action({
    required this.keyName,
    required this.label,
    this.iconAssetPath,
    this.iconSize = 22,
  }) : value = null,
       minutes = null,
       useCheckbox = false,
       isPremiumOnly = false,
       isSubItem = false,
       isAction = true,
       isTimeLimit = false;

  final String keyName;
  final String label;
  final bool? value;
  final int? minutes;
  final String? iconAssetPath;
  final double iconSize;
  final bool isTimeLimit;
  final bool isSubItem;
  final bool isAction;
  final bool useCheckbox;
  final bool isPremiumOnly;
}
