import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/product.dart';
import 'inventory_status_badge.dart';

class CredProductAction {
  const CredProductAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Simple catalog product card (image, name, price, stock badge).
class CredProductCard extends StatelessWidget {
  const CredProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.actions = const [],
    this.showCategory = true,
    this.compact = false,
  });

  final Product product;
  final VoidCallback? onTap;
  final List<CredProductAction> actions;
  final bool showCategory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final out = product.isOutOfStock;
    final radius = BorderRadius.circular(CredTheme.radiusCard);

    return Material(
      color: CredTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: CredTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: out ? null : onTap,
        borderRadius: radius,
        child: Opacity(
          opacity: out ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: CredTheme.primary.withValues(alpha: 0.06),
                      child: _ProductImage(url: product.imageUrl),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: InventoryStatusBadge(product: product, compact: true),
                    ),
                    if (actions.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: PopupMenuButton<int>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          padding: EdgeInsets.zero,
                          onSelected: (i) => actions[i].onSelected(),
                          itemBuilder: (_) => [
                            for (var i = 0; i < actions.length; i++)
                              PopupMenuItem(
                                value: i,
                                child: Row(
                                  children: [
                                    Icon(actions[i].icon, size: 18),
                                    const SizedBox(width: 8),
                                    Text(actions[i].label),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  CredTheme.spaceSm,
                  CredTheme.spaceXs,
                  CredTheme.spaceSm,
                  CredTheme.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: CredTheme.titleText,
                        height: 1.2,
                      ),
                    ),
                    if (showCategory && product.category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: CredTheme.bodyMuted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyFormatter.format(product.sellingPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: CredTheme.titleText,
                            ),
                          ),
                        ),
                        Text(
                          '${product.stockQuantity}',
                          style: const TextStyle(fontSize: 11, color: CredTheme.subtitleText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CredProductGrid extends StatelessWidget {
  const CredProductGrid({
    super.key,
    required this.products,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.crossAxisCount,
    this.maxCrossAxisExtent = 168,
    this.childAspectRatio,
    this.mainAxisExtent = 184,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<Product> products;
  final Widget Function(BuildContext context, Product product, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  /// When set, forces a fixed column count. Prefer [maxCrossAxisExtent] on wide layouts.
  final int? crossAxisCount;
  /// Target card width; columns grow as the viewport widens (desktop-friendly).
  final double maxCrossAxisExtent;
  /// If set, used instead of [mainAxisExtent]. Prefer extent so cards stay compact.
  final double? childAspectRatio;
  final double mainAxisExtent;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Responsive by default: cards keep ~[maxCrossAxisExtent] width instead of
  /// stretching across a fixed 2-column phone layout on desktop.
  static SliverGridDelegate gridDelegate({
    int? crossAxisCount,
    double maxCrossAxisExtent = 168,
    double? childAspectRatio,
    double mainAxisExtent = 184,
  }) {
    if (crossAxisCount != null) {
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: CredTheme.spaceSm,
        crossAxisSpacing: CredTheme.spaceSm,
        childAspectRatio: childAspectRatio ?? 1,
        mainAxisExtent: childAspectRatio == null ? mainAxisExtent : null,
      );
    }
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxCrossAxisExtent,
      mainAxisSpacing: CredTheme.spaceSm,
      crossAxisSpacing: CredTheme.spaceSm,
      childAspectRatio: childAspectRatio ?? 1,
      mainAxisExtent: childAspectRatio == null ? mainAxisExtent : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      itemCount: products.length,
      gridDelegate: gridDelegate(
        crossAxisCount: crossAxisCount,
        maxCrossAxisExtent: maxCrossAxisExtent,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      ),
      itemBuilder: (context, i) => itemBuilder(context, products[i], i),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty && (url!.startsWith('http://') || url!.startsWith('https://'))) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _Placeholder(),
      );
    }
    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.inventory_2_outlined, color: CredTheme.primary.withValues(alpha: 0.45), size: 36),
    );
  }
}
