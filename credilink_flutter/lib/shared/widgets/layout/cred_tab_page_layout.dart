import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

/// Scrollable tab page with optional refresh and header/content slivers.
class CredTabPageLayout extends StatelessWidget {
  const CredTabPageLayout({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding = const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
    this.bottomPadding = CredTheme.spaceMd,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ...children,
              SizedBox(height: bottomPadding),
            ]),
          ),
        ),
      ],
    );

    if (onRefresh == null) return scrollView;

    return RefreshIndicator(onRefresh: onRefresh!, child: scrollView);
  }
}

/// Builds a tab page from a header widget and list of body slivers.
class CredTabPageLayoutBuilder extends StatelessWidget {
  const CredTabPageLayoutBuilder({
    super.key,
    required this.header,
    required this.slivers,
    this.onRefresh,
    this.padding = const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd),
  });

  final Widget header;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(child: header),
        ),
        ...slivers,
      ],
    );

    if (onRefresh == null) return scrollView;
    return RefreshIndicator(onRefresh: onRefresh!, child: scrollView);
  }
}
