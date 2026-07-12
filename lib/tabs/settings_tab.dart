import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';
import 'sticky_header.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.onBackToHome,
    required this.premiumStatusLabel,
    required this.onOpenPremiumStatus,
    required this.onEnterCode,
    required this.onOpenAccessibilitySettings,
    required this.onOpenOverlayPermissionSettings,
    required this.onOpenUsageAccessSettings,
    required this.onShareApp,
    required this.onLeaveReview,
    required this.onSendFeedback,
    required this.onOpenPrivacyPolicy,
    required this.isAccessibilityAllowed,
    required this.isOverlayPermissionAllowed,
    required this.isUsageAccessAllowed,
  });

  final VoidCallback onBackToHome;
  final String premiumStatusLabel;
  final VoidCallback onOpenPremiumStatus;
  final VoidCallback onEnterCode;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenOverlayPermissionSettings;
  final VoidCallback onOpenUsageAccessSettings;
  final VoidCallback onShareApp;
  final VoidCallback onLeaveReview;
  final VoidCallback onSendFeedback;
  final VoidCallback onOpenPrivacyPolicy;
  final bool isAccessibilityAllowed;
  final bool isOverlayPermissionAllowed;
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
              _SettingsGroup(
                title: 'Account',
                children: [
                  _SettingsRow(
                    icon: Icons.account_circle_outlined,
                    title: 'Status',
                    value: premiumStatusLabel,
                    showPremiumCrown: premiumStatusLabel == 'Premium',
                    onTap: onOpenPremiumStatus,
                  ),
                  _SettingsRow(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Enter Code',
                    value: '',
                    onTap: onEnterCode,
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
                    value: isAccessibilityAllowed ? 'Allowed' : 'Denied',
                    onTap: onOpenAccessibilitySettings,
                  ),
                  _SettingsRow(
                    icon: Icons.picture_in_picture_alt_rounded,
                    title: 'Display Over Apps',
                    value: isOverlayPermissionAllowed ? 'Allowed' : 'Denied',
                    onTap: onOpenOverlayPermissionSettings,
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
                title: 'App',
                children: [
                  _SettingsRow(
                    icon: Icons.share_rounded,
                    title: 'Share with Friends',
                    value: '',
                    onTap: onShareApp,
                  ),
                  _SettingsRow(
                    icon: Icons.rate_review_outlined,
                    title: 'Leave a Review',
                    value: '',
                    onTap: onLeaveReview,
                  ),
                  _SettingsRow(
                    icon: Icons.mail_outline_rounded,
                    title: 'Report an Issue',
                    value: '',
                    onTap: onSendFeedback,
                  ),
                  _SettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    value: '',
                    onTap: onOpenPrivacyPolicy,
                  ),
                  const _SettingsRow(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    value: '0.4.1',
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
  const _SettingsGroup({required this.title, required this.children});

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
              fontSize: 12,
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
    this.showPremiumCrown = false,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool showPremiumCrown;
  final VoidCallback? onTap;
  final bool showChevron;
  static const double _minRowHeight = 56;

  @override
  Widget build(BuildContext context) {
    final hasTrailingValue = value.isNotEmpty || showPremiumCrown;

    return InkWell(
      onTap: onTap,
      splashColor: brand.withValues(alpha: 0.14),
      highlightColor: appText.withValues(alpha: 0.04),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minRowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: appMutedText, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasTrailingValue)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showPremiumCrown) ...[
                          SvgPicture.asset(
                            'assets/icons/crown.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                              premiumGold,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: appMutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  if (showChevron) ...[
                    if (hasTrailingValue) const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: appMutedText,
                      size: 20,
                    ),
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
