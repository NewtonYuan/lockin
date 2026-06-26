import 'package:flutter/material.dart';
import '../brand.dart';
import 'sticky_header.dart';

class StatisticsTab extends StatelessWidget {
  const StatisticsTab({
    super.key,
    required this.onBackToHome,
  });

  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    return _PlaceholderTab(
      title: 'Statistics',
      onBack: onBackToHome,
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        StickyHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StickyTitleHeader(
              title: title,
              onBack: onBack,
              centerTitle: false,
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/maintenance_cuate.png',
                    width: 260,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Under Development...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: appText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
