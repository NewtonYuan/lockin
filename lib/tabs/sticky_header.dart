import 'package:flutter/material.dart';

import '../brand.dart';

class StickyHeaderSliver extends StatelessWidget {
  const StickyHeaderSliver({
    super.key,
    required this.child,
    this.height = 64,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        height: height,
        child: child,
      ),
    );
  }
}

class StickyTitleHeader extends StatelessWidget {
  static const double _leadingSlotWidth = 28;
  static const double _leadingTitleGap = 10;

  const StickyTitleHeader({
    super.key,
    required this.title,
    this.onBack,
    this.leading,
    this.trailing,
    this.centerTitle = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
      color: appText,
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: _leadingSlotWidth,
                height: 40,
                child: IconButton(
                  onPressed: onBack,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: appText,
                    size: 20,
                  ),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: _leadingSlotWidth,
                    minHeight: 40,
                  ),
                ),
              ),
            ),
          if (centerTitle) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
            if (leading != null)
              IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final titlePainter = TextPainter(
                      text: TextSpan(text: title, style: titleStyle),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout(maxWidth: constraints.maxWidth);

                    return Transform.translate(
                      offset: Offset(-(titlePainter.width / 2) - 30, 0),
                      child: leading,
                    );
                  },
                ),
              ),
          ] else
            Row(
              children: [
                if (onBack != null) ...[
                  const SizedBox(width: _leadingSlotWidth),
                  const SizedBox(width: _leadingTitleGap),
                ],
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.left,
                    style: titleStyle,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          if (centerTitle && trailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyHeaderDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isStuck = shrinkOffset > 0 || overlapsContent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: appBackground,
        border: isStuck
            ? const Border(
                bottom: BorderSide(color: brand, width: 1),
              )
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
