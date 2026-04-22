import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';

class BlockScreen extends StatelessWidget {
  const BlockScreen({
    super.key,
    required this.selectedCategory,
    required this.expandedApps,
    required this.dailyTimeLimits,
    required this.blockSettings,
    required this.onSelectCategory,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
  });

  final String selectedCategory;
  final Set<String> expandedApps;
  final Map<String, int?> dailyTimeLimits;
  final Map<String, bool> blockSettings;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onToggleExpanded;
  final void Function(String settingKey, bool value) onToggleSetting;
  final void Function(String settingKey, int? minutes) onSelectTimeLimit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        Text(
          'Block',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
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
          const _OverviewCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'Website blocking controls will live here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD8DCE2),
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
            ),
          )
        else ...[
          _AppBlockCard(
            appName: 'Instagram',
            iconAssetPath: 'assets/icons/instagram.png',
            isExpanded: expandedApps.contains('Instagram'),
            items: [
              _BlockItemData.timeLimit(
                keyName: 'instagram_app',
                label: 'Daily Time Limit',
                minutes: dailyTimeLimits['instagram_app'] ?? 10,
                iconAssetPath: 'assets/icons/timer.svg',
                iconSize: 24,
              ),
              _BlockItemData.toggle(
                keyName: 'instagram_reels',
                label: 'Block Instagram Reels',
                value: blockSettings['instagram_reels'] ?? false,
              ),
              _BlockItemData.toggle(
                keyName: 'instagram_explore',
                label: 'Block Instagram Explore',
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
            iconAssetPath: 'assets/icons/youtube.png',
            isExpanded: expandedApps.contains('YouTube'),
            items: [
              _BlockItemData.timeLimit(
                keyName: 'youtube_app',
                label: 'Daily Time Limit',
                minutes: dailyTimeLimits['youtube_app'] ?? 15,
                iconAssetPath: 'assets/icons/timer.svg',
                iconSize: 24,
              ),
              _BlockItemData.toggle(
                keyName: 'youtube_shorts',
                label: 'Block YouTube Shorts',
                value: blockSettings['youtube_shorts'] ?? false,
              ),
              _BlockItemData.toggle(
                keyName: 'youtube_home_feed',
                label: 'Block YouTube Home Feed',
                value: blockSettings['youtube_home_feed'] ?? false,
              ),
            ],
            onToggleExpanded: () => onToggleExpanded('YouTube'),
            onToggleSetting: onToggleSetting,
            onSelectTimeLimit: onSelectTimeLimit,
          ),
          const SizedBox(height: 14),
          _AppBlockCard(
            appName: 'TikTok',
            iconAssetPath: 'assets/icons/tiktok.png',
            isExpanded: expandedApps.contains('TikTok'),
            items: [
              _BlockItemData.timeLimit(
                keyName: 'tiktok_app',
                label: 'Daily Time Limit',
                minutes: dailyTimeLimits['tiktok_app'] ?? 30,
                iconAssetPath: 'assets/icons/timer.svg',
                iconSize: 24,
              ),
              _BlockItemData.toggle(
                keyName: 'tiktok_for_you',
                label: 'Block TikTok For You',
                value: blockSettings['tiktok_for_you'] ?? false,
              ),
              _BlockItemData.toggle(
                keyName: 'tiktok_live',
                label: 'Block TikTok Live',
                value: blockSettings['tiktok_live'] ?? false,
              ),
            ],
            onToggleExpanded: () => onToggleExpanded('TikTok'),
            onToggleSetting: onToggleSetting,
            onSelectTimeLimit: onSelectTimeLimit,
          ),
          const SizedBox(height: 14),
          _AppBlockCard(
            appName: 'Snapchat',
            iconAssetPath: 'assets/icons/snapchat.png',
            isExpanded: expandedApps.contains('Snapchat'),
            items: [
              _BlockItemData.timeLimit(
                keyName: 'snapchat_app',
                label: 'Daily Time Limit',
                minutes: dailyTimeLimits['snapchat_app'] ?? 5,
                iconAssetPath: 'assets/icons/timer.svg',
                iconSize: 24,
              ),
              _BlockItemData.toggle(
                keyName: 'snapchat_spotlight',
                label: 'Block Snapchat Spotlight',
                value: blockSettings['snapchat_spotlight'] ?? false,
              ),
              _BlockItemData.toggle(
                keyName: 'snapchat_discover',
                label: 'Block Snapchat Discover',
                value: blockSettings['snapchat_discover'] ?? false,
              ),
            ],
            onToggleExpanded: () => onToggleExpanded('Snapchat'),
            onToggleSetting: onToggleSetting,
            onSelectTimeLimit: onSelectTimeLimit,
          ),
          const SizedBox(height: 14),
          _AppBlockCard(
            appName: 'Facebook',
            iconAssetPath: 'assets/icons/facebook.png',
            isExpanded: expandedApps.contains('Facebook'),
            items: [
              _BlockItemData.timeLimit(
                keyName: 'facebook_app',
                label: 'Daily Time Limit',
                minutes: dailyTimeLimits['facebook_app'] ?? 10,
                iconAssetPath: 'assets/icons/timer.svg',
                iconSize: 24,
              ),
              _BlockItemData.toggle(
                keyName: 'facebook_reels',
                label: 'Block Facebook Reels',
                value: blockSettings['facebook_reels'] ?? false,
              ),
              _BlockItemData.toggle(
                keyName: 'facebook_watch',
                label: 'Block Facebook Watch',
                value: blockSettings['facebook_watch'] ?? false,
              ),
            ],
            onToggleExpanded: () => onToggleExpanded('Facebook'),
            onToggleSetting: onToggleSetting,
            onSelectTimeLimit: onSelectTimeLimit,
          ),
        ],
      ],
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
                color: selected ? Colors.white : const Color(0xFF8E8E8E),
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
                color: selected ? Colors.white : Colors.transparent,
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
    required this.isExpanded,
    required this.items,
    required this.onToggleExpanded,
    required this.onToggleSetting,
    required this.onSelectTimeLimit,
  });

  final String appName;
  final String? iconAssetPath;
  final bool isExpanded;
  final List<_BlockItemData> items;
  final VoidCallback onToggleExpanded;
  final void Function(String settingKey, bool value) onToggleSetting;
  final void Function(String settingKey, int? minutes) onSelectTimeLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggleExpanded,
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
                      child: SizedBox.expand(
                        child: iconAssetPath != null
                            ? Image.asset(
                                iconAssetPath!,
                                fit: BoxFit.fill,
                              )
                            : Center(
                                child: Text(
                                  appName.substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
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
            ),
        ],
      ),
    );
  }
}

class _BlockItemRow extends StatelessWidget {
  const _BlockItemRow({
    required this.item,
    required this.onToggleChanged,
    required this.onTimeLimitSelected,
  });

  static const List<int?> _timeLimitOptions = [
    5,
    10,
    15,
    30,
    60,
    120,
    180,
    240,
    360,
    null,
  ];

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
                Color(0xFFB7B7B7),
                BlendMode.srcIn,
            ),
          )
        : const Icon(Icons.block_outlined, color: Color(0xFFB7B7B7), size: 22);

    if (item.isTimeLimit) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showTimeLimitPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatMinutes(item.minutes),
                  style: const TextStyle(
                    color: Color(0xFFD8DCE2),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB7B7B7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: item.value ?? false,
            onChanged: onToggleChanged,
            activeColor: brand,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF4C4C4C),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimeLimitPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ..._timeLimitOptions.map(
                  (minutes) => Center(
                    child: SizedBox(
                      width: 220,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            Navigator.of(context).pop(minutes ?? -1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                _formatMinutes(minutes),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (minutes == item.minutes)
                                const Positioned(
                                  right: 0,
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: brand,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onTimeLimitSelected(selected == -1 ? null : selected);
    }
  }
}

String _formatMinutes(int? minutes) {
  if (minutes == null) {
    return 'None';
  }
  if (minutes < 60) {
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
  if (minutes == 60) {
    return '1 hour';
  }
  final hours = minutes ~/ 60;
  return hours == 1 ? '1 hour' : '$hours hours';
}

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
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
