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
  });

  final String domain;
  final DateTime blockedSince;
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
    required this.onRequestInstalledApps,
    required this.onAddCustomTrackedApp,
    required this.onDeleteCustomTrackedApp,
    required this.onSelectCategory,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
  });

  final VoidCallback onBackToHome;
  final String selectedCategory;
  final Set<String> expandedApps;
  final Set<String>? installedPackageNames;
  final List<CustomTrackedApp> customTrackedApps;
  final List<BlockedWebsiteEntry> blockedWebsites;
  final Map<String, int?> dailyTimeLimits;
  final Map<String, bool> blockSettings;
  final ValueChanged<String> onAddWebsite;
  final ValueChanged<BlockedWebsiteEntry> onDeleteWebsite;
  final Future<List<CustomTrackedApp>> Function() onRequestInstalledApps;
  final ValueChanged<InstalledAppSelection> onAddCustomTrackedApp;
  final ValueChanged<CustomTrackedApp> onDeleteCustomTrackedApp;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onToggleExpanded;
  final void Function(String settingKey, bool value) onToggleSetting;
  final void Function(String settingKey, int? minutes) onSelectTimeLimit;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        StickyHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StickyTitleHeader(
              title: 'Block',
              onBack: onBackToHome,
              centerTitle: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
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
              const SizedBox(height: 14),
              if (selectedCategory == 'Websites')
                _WebsiteBlockPanel(
                  blockedWebsites: blockedWebsites,
                  onAddWebsite: onAddWebsite,
                  onDeleteWebsite: onDeleteWebsite,
                )
              else ..._buildAppCategoryChildren(context),
            ]),
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
        isInstalled: _isPackageInstalled(
          'com.instagram.android',
        ),
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
          ),
          _BlockItemData.toggle(
            keyName: 'instagram_explore',
            label: 'Block Stories',
            value: blockSettings['instagram_explore'] ?? false,
          ),
        ],
        onToggleExpanded: () => onToggleExpanded('Instagram'),
        onToggleSetting: onToggleSetting,
        onSelectTimeLimit: onSelectTimeLimit,
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
      ),
    ];

    children.add(const SizedBox(height: 14));
    children.add(const _AppSectionHeader(label: 'Additional'));

    for (final app in customTrackedApps) {
      children.add(const SizedBox(height: 8));
      children.add(
        _AdditionalTrackedAppCard(
          app: app,
          minutes: dailyTimeLimits[app.settingKey],
          pauseOnOpen: blockSettings[customTrackedAppPauseOnOpenSettingKey(app.packageName)] ?? false,
          isExpanded: expandedApps.contains(app.packageName),
          onToggleExpanded: () => onToggleExpanded(app.packageName),
          onSelectTimeLimit: (minutes) =>
              onSelectTimeLimit(app.settingKey, minutes),
          onTogglePauseOnOpen: (value) => onToggleSetting(
            customTrackedAppPauseOnOpenSettingKey(app.packageName),
            value,
          ),
          onRemoveApp: () => onDeleteCustomTrackedApp(app),
        ),
      );
    }

    children.add(const SizedBox(height: 8));
    children.add(
      _AddAppCard(
        onTap: () => _promptForInstalledApp(context),
      ),
    );
    return children;
  }

  Future<void> _promptForInstalledApp(BuildContext context) async {
    final existingPackages = <String>{
      'com.instagram.android',
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
          }).toList()
            ..sort((first, second) => first.appName.toLowerCase().compareTo(
                  second.appName.toLowerCase(),
                ));
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

class _AppSectionHeader extends StatelessWidget {
  const _AppSectionHeader({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
          child: Divider(
            color: appBorder,
            height: 1,
            thickness: 1,
          ),
        ),
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
  });

  final CustomTrackedApp app;
  final int? minutes;
  final bool pauseOnOpen;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int?> onSelectTimeLimit;
  final ValueChanged<bool> onTogglePauseOnOpen;
  final VoidCallback onRemoveApp;

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
    );
  }
}

class _AddAppCard extends StatelessWidget {
  const _AddAppCard({
    required this.onTap,
  });

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
  const _InstalledAppPickerSheet({
    required this.loadInstalledApps,
  });

  final Future<List<CustomTrackedApp>> Function() loadInstalledApps;

  @override
  State<_InstalledAppPickerSheet> createState() => _InstalledAppPickerSheetState();
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
  Widget build(BuildContext context) {
    if (_selectedApp != null) {
      return _buildDetailPage(context, _selectedApp!);
    }

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
            child: Padding(
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

                        final installedApps = snapshot.data ?? const <CustomTrackedApp>[];
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
                                      message: 'No additional installed apps available.',
                                    )
                                  : ListView.separated(
                                      itemCount: filteredApps.length,
                                      separatorBuilder: (_, _) => const Divider(
                                        height: 1,
                                        color: appBorder,
                                      ),
                                      itemBuilder: (context, index) {
                                        final app = filteredApps[index];
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedApp = app;
                                              _selectedMinutes = null;
                                              _selectedPauseOnOpen = false;
                                            });
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
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
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
                                                                        .substring(0, 1)
                                                                        .toUpperCase(),
                                                                style: const TextStyle(
                                                                  color: appText,
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.w700,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPage(BuildContext context, CustomTrackedApp app) {
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
            child: Padding(
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
                        onPressed: () {
                          setState(() {
                            _selectedApp = null;
                          });
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: appText,
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
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
                                    activeColor: brand,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _WebsiteBlockPanel extends StatelessWidget {
  const _WebsiteBlockPanel({
    required this.blockedWebsites,
    required this.onAddWebsite,
    required this.onDeleteWebsite,
  });

  final List<BlockedWebsiteEntry> blockedWebsites;
  final ValueChanged<String> onAddWebsite;
  final ValueChanged<BlockedWebsiteEntry> onDeleteWebsite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WebsiteEntryCard(
          onAddWebsite: onAddWebsite,
        ),
        const SizedBox(height: 14),
        _BlockedWebsitesCard(
          blockedWebsites: blockedWebsites,
          onDeleteWebsite: onDeleteWebsite,
        ),
      ],
    );
  }
}

class _WebsiteEntryCard extends StatefulWidget {
  const _WebsiteEntryCard({
    required this.onAddWebsite,
  });

  final ValueChanged<String> onAddWebsite;

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
    widget.onAddWebsite(value);
    _controller.clear();
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
            const Icon(
              Icons.language_rounded,
              color: appMutedText,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: appBorder,
                      width: 1,
                    ),
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
              icon: const Icon(
                Icons.add_rounded,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedWebsitesCard extends StatelessWidget {
  const _BlockedWebsitesCard({
    required this.blockedWebsites,
    required this.onDeleteWebsite,
  });

  final List<BlockedWebsiteEntry> blockedWebsites;
  final ValueChanged<BlockedWebsiteEntry> onDeleteWebsite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blocked Websites',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: appText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (blockedWebsites.isEmpty)
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
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
              )
            else
              for (var index = 0; index < blockedWebsites.length; index++) ...[
                _BlockedWebsiteRow(
                  entry: blockedWebsites[index],
                  onDelete: () => onDeleteWebsite(blockedWebsites[index]),
                ),
                if (index < blockedWebsites.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: appBorder,
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _BlockedWebsiteRow extends StatelessWidget {
  const _BlockedWebsiteRow({
    required this.entry,
    required this.onDelete,
  });

  final BlockedWebsiteEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: appSurfaceStrong,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.public_rounded,
              color: appMutedText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.domain,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatBlockedSince(entry.blockedSince),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: appMutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: SvgPicture.asset(
              'assets/icons/delete_forever.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                appMutedText,
                BlendMode.srcIn,
              ),
            ),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

String _formatBlockedSince(DateTime blockedSince) {
  const monthNames = [
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
  return 'Since ${monthNames[blockedSince.month - 1]} ${blockedSince.day}, ${blockedSince.year}';
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
    final isDirectTimeLimitApp =
        items.length == 1 && items.first.isTimeLimit;

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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
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
                        children: items
                            .map(
                              (item) => _BlockItemRow(
                                item: item,
                                onToggleChanged: (value) =>
                                    onToggleSetting(item.keyName, value),
                                onTimeLimitSelected: (minutes) =>
                                    onSelectTimeLimit(item.keyName, minutes),
                                onActionPressed: onActionPressed,
                              ),
                            )
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
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
  const _InstalledAppsMessageState({
    required this.message,
  });

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
  const _BlockAppIcon({
    this.assetPath,
    this.iconBytes,
  }) : assert(assetPath != null || iconBytes != null);

  final String? assetPath;
  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    if (iconBytes != null) {
      return Image.memory(
        iconBytes!,
        fit: BoxFit.fill,
      );
    }
    final resolvedAssetPath = assetPath!;
    if (resolvedAssetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        resolvedAssetPath,
        fit: BoxFit.fill,
      );
    }
    return Image.asset(
      resolvedAssetPath,
      fit: BoxFit.fill,
    );
  }
}

class _BlockItemRow extends StatelessWidget {
  const _BlockItemRow({
    required this.item,
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
    final labelStyle = TextStyle(
      color: appText,
      fontSize: isSubItem ? 14 : 15,
      fontWeight: isSubItem ? FontWeight.w500 : FontWeight.w500,
    );
    final leading = item.iconAssetPath != null
        ? SvgPicture.asset(
            item.iconAssetPath!,
            width: isSubItem ? item.iconSize - 4 : item.iconSize - 2,
            height: isSubItem ? item.iconSize - 4 : item.iconSize - 2,
            colorFilter: const ColorFilter.mode(
              appMutedText,
              BlendMode.srcIn,
            ),
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
                padding: EdgeInsets.symmetric(horizontal: toggleHorizontalPadding),
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
                    Expanded(
                      child: Text(
                        item.label,
                        style: labelStyle,
                      ),
                    ),
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
          onTap: () => onToggleChanged(!(item.value ?? false)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowMinHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: toggleHorizontalPadding),
              child: Row(
                children: [
                  SizedBox(width: leadingInset),
                  leading,
                  SizedBox(width: leadingGap),
                  Expanded(
                    child: Text(
                      item.label,
                      style: labelStyle,
                    ),
                  ),
                  Switch(
                    value: item.value ?? false,
                    onChanged: onToggleChanged,
                    activeColor: brand,
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
              top: BorderSide(
                color: appBorder,
              ),
              bottom: BorderSide(
                color: appBorder,
              ),
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
  final resolvedInitialMinutes =
      initialMinutes != null && initialMinutes > 0 ? initialMinutes : 0;
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
  final parts = <String>[
    hours == 1 ? '1 hr' : '$hours hrs',
  ];
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
}
