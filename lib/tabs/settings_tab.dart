import 'package:flutter/material.dart';

import '../brand.dart';
import 'sticky_header.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.onBackToHome,
    required this.onOpenAccessibilitySettings,
    required this.onOpenUsageAccessSettings,
    required this.onRestartOnboarding,
    required this.isAccessibilityAllowed,
    required this.isUsageAccessAllowed,
  });

  final VoidCallback onBackToHome;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenUsageAccessSettings;
  final VoidCallback onRestartOnboarding;
  final bool isAccessibilityAllowed;
  final bool isUsageAccessAllowed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        StickyHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StickyTitleHeader(
              title: 'Settings',
              onBack: onBackToHome,
              centerTitle: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _SettingsGroup(
                title: 'Subscription',
                children: [
                  _SettingsRow(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Enter Code',
                    value: '',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: 'Permissions',
                children: [
                  _SettingsRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility',
                    value: isAccessibilityAllowed
                        ? 'Allowed'
                        : 'Denied',
                    onTap: onOpenAccessibilitySettings,
                  ),
                  _SettingsRow(
                    icon: Icons.query_stats_rounded,
                    title: 'Usage Access',
                    value: isUsageAccessAllowed ? 'Allowed' : 'Denied',
                    onTap: onOpenUsageAccessSettings,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                title: 'Onboarding',
                children: [
                  _SettingsRow(
                    icon: Icons.replay_rounded,
                    title: 'Run Onboarding Again',
                    value: '',
                    onTap: onRestartOnboarding,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _SettingsGroup(
                title: 'App',
                children: [
                  _SettingsRow(
                    icon: Icons.share_rounded,
                    title: 'Share with Friends',
                    value: '',
                  ),
                  _SettingsRow(
                    icon: Icons.rate_review_outlined,
                    title: 'Leave a Review',
                    value: '',
                  ),
                  _SettingsRow(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    value: '0.1.0',
                    showChevron: false,
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: appMutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Material(
          color: appSurface,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      color: appBorder,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  static const double _rowHeight = 56;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: brand.withValues(alpha: 0.14),
      highlightColor: appText.withValues(alpha: 0.04),
      child: SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: appMutedText, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null)
                trailing!
              else ...[
                SizedBox(
                  width: showChevron ? 88 : 104,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: appMutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (showChevron) ...[
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
