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

class BlockScreen extends StatelessWidget {
  const BlockScreen({
    super.key,
    required this.onBackToHome,
    required this.selectedCategory,
    required this.expandedApps,
    required this.installedPackageNames,
    required this.blockedWebsites,
    required this.dailyTimeLimits,
    required this.blockSettings,
    required this.onAddWebsite,
    required this.onDeleteWebsite,
    required this.onSelectCategory,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
  });

  final VoidCallback onBackToHome;
  final String selectedCategory;
  final Set<String> expandedApps;
  final Set<String>? installedPackageNames;
  final List<BlockedWebsiteEntry> blockedWebsites;
  final Map<String, int?> dailyTimeLimits;
  final Map<String, bool> blockSettings;
  final ValueChanged<String> onAddWebsite;
  final ValueChanged<BlockedWebsiteEntry> onDeleteWebsite;
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
              const SizedBox(height: 18),
              if (selectedCategory == 'Websites')
                _WebsiteBlockPanel(
                  blockedWebsites: blockedWebsites,
                  onAddWebsite: onAddWebsite,
                  onDeleteWebsite: onDeleteWebsite,
                )
              else ...[
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
                      keyName: 'instagram_reels',
                      label: 'Block Reels',
                      value: blockSettings['instagram_reels'] ?? false,
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
                const SizedBox(height: 14),
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
                      keyName: 'youtube_shorts',
                      label: 'Block Shorts',
                      value: blockSettings['youtube_shorts'] ?? false,
                    ),
                  ],
                  onToggleExpanded: () => onToggleExpanded('YouTube'),
                  onToggleSetting: onToggleSetting,
                  onSelectTimeLimit: onSelectTimeLimit,
                ),
                const SizedBox(height: 14),
                _AppBlockCard(
                  appName: 'TikTok',
                  iconAssetPath: 'assets/apps/tiktok.svg',
                  isInstalled: _isPackageInstalled(
                    'com.zhiliaoapp.musically',
                  ),
                  isExpanded: expandedApps.contains('TikTok'),
                  items: [
                    _BlockItemData.timeLimit(
                      keyName: 'tiktok_app',
                      label: 'Daily Time Limit',
                      minutes: dailyTimeLimits['tiktok_app'],
                      iconAssetPath: 'assets/icons/timer.svg',
                      iconSize: 24,
                    ),
                  ],
                  onToggleExpanded: () => onToggleExpanded('TikTok'),
                  onToggleSetting: onToggleSetting,
                  onSelectTimeLimit: onSelectTimeLimit,
                ),
                const SizedBox(height: 14),
                _AppBlockCard(
                  appName: 'Snapchat',
                  iconAssetPath: 'assets/apps/snapchat.svg',
                  isInstalled: _isPackageInstalled(
                    'com.snapchat.android',
                  ),
                  isExpanded: expandedApps.contains('Snapchat'),
                  items: [
                    _BlockItemData.timeLimit(
                      keyName: 'snapchat_app',
                      label: 'Daily Time Limit',
                      minutes: dailyTimeLimits['snapchat_app'],
                      iconAssetPath: 'assets/icons/timer.svg',
                      iconSize: 24,
                    ),
                  ],
                  onToggleExpanded: () => onToggleExpanded('Snapchat'),
                  onToggleSetting: onToggleSetting,
                  onSelectTimeLimit: onSelectTimeLimit,
                ),
                const SizedBox(height: 14),
                _AppBlockCard(
                  appName: 'Facebook',
                  iconAssetPath: 'assets/apps/facebook.jpg',
                  isInstalled: _isPackageInstalled(
                    'com.facebook.katana',
                  ),
                  isExpanded: expandedApps.contains('Facebook'),
                  items: [
                    _BlockItemData.timeLimit(
                      keyName: 'facebook_app',
                      label: 'Daily Time Limit',
                      minutes: dailyTimeLimits['facebook_app'],
                      iconAssetPath: 'assets/icons/timer.svg',
                      iconSize: 24,
                    ),
                  ],
                  onToggleExpanded: () => onToggleExpanded('Facebook'),
                  onToggleSetting: onToggleSetting,
                  onSelectTimeLimit: onSelectTimeLimit,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
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
    required this.isInstalled,
    required this.isExpanded,
    required this.items,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
  });

  final String appName;
  final String? iconAssetPath;
  final bool isInstalled;
  final bool isExpanded;
  final List<_BlockItemData> items;
  final VoidCallback onToggleExpanded;
  final void Function(String settingKey, bool value) onToggleSetting;
  final void Function(String settingKey, int? minutes) onSelectTimeLimit;

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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Opacity(
                          opacity: iconOpacity,
                          child: SizedBox.expand(
                            child: iconAssetPath != null
                                ? _BlockAppIcon(
                                    assetPath: iconAssetPath!,
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

class _SingleTimeLimitAppButton extends StatelessWidget {
  const _SingleTimeLimitAppButton({
    required this.appName,
    required this.iconAssetPath,
    required this.isInstalled,
    required this.minutes,
    required this.onTap,
  });

  final String appName;
  final String? iconAssetPath;
  final bool isInstalled;
  final int? minutes;
  final VoidCallback? onTap;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Opacity(
                      opacity: iconOpacity,
                      child: SizedBox.expand(
                        child: iconAssetPath != null
                            ? _BlockAppIcon(assetPath: iconAssetPath!)
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
    );
  }
}

class _BlockAppIcon extends StatelessWidget {
  const _BlockAppIcon({
    required this.assetPath,
  });

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        fit: BoxFit.fill,
      );
    }
    return Image.asset(
      assetPath,
      fit: BoxFit.fill,
    );
  }
}

class _BlockItemRow extends StatelessWidget {
  const _BlockItemRow({
    required this.item,
    required this.onToggleChanged,
    required this.onTimeLimitSelected,
  });
  static const double _rowMinHeight = 52;
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

  @override
  Widget build(BuildContext context) {
    final leading = item.iconAssetPath != null
        ? SvgPicture.asset(
            item.iconAssetPath!,
            width: item.iconSize - 2,
            height: item.iconSize - 2,
            colorFilter: const ColorFilter.mode(
              appMutedText,
              BlendMode.srcIn,
            ),
          )
        : const Icon(Icons.block_outlined, color: appMutedText, size: 22);

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
              constraints: const BoxConstraints(minHeight: _rowMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
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
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
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
        itemExtent: 44,
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
                fontSize: 22,
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
                  height: 180,
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
                            fontSize: 28,
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
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(-10),
                    child: const Text('10 Seconds'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(0),
                    child: const Text('No Limit'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(-1),
                    child: const Text('Block Completely'),
                  ),
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
  }) : minutes = null,
       isTimeLimit = false;

  const _BlockItemData.timeLimit({
    required this.keyName,
    required this.label,
    required this.minutes,
    this.iconAssetPath,
    this.iconSize = 22,
  }) : value = null,
       isTimeLimit = true;

  final String keyName;
  final String label;
  final bool? value;
  final int? minutes;
  final String? iconAssetPath;
  final double iconSize;
  final bool isTimeLimit;
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appBorder),
      ),
      child: child,
    );
  }
}
