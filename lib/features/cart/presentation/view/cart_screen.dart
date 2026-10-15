import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../menu/presentation/widgets/meal_image.dart';
import '../../../menu/presentation/widgets/menu_palette.dart';
import '../view_model/cart_cubit.dart';
import '../view_model/cart_state.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final veryNarrow = screenWidth < 120;
    final compact = screenWidth < 360;
    return Scaffold(
      backgroundColor: MenuPalette.bg,
      appBar: AppBar(
        backgroundColor: MenuPalette.bg,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !veryNarrow,
        leadingWidth: veryNarrow ? 28 : null,
        titleSpacing: veryNarrow ? 0 : null,
        leading: veryNarrow
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 32,
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
              )
            : null,
        title: Text(
          veryNarrow
              ? ''
              : compact
              ? 'Cart'
              : 'My Cart',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          BlocBuilder<CartCubit, CartState>(
            builder: (context, state) => state.items.isEmpty
                ? const SizedBox.shrink()
                : compact
                ? IconButton(
                    onPressed: context.read<CartCubit>().clear,
                    tooltip: 'Clear cart',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      size: 20,
                      color: MenuPalette.gold,
                    ),
                  )
                : TextButton(
                    onPressed: context.read<CartCubit>().clear,
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: MenuPalette.gold),
                    ),
                  ),
          ),
        ],
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return const _EmptyCart();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300) {
                return _itemsList(
                  context,
                  state,
                  footer: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                    child: _summary(state),
                  ),
                );
              }
              final isWide = constraints.maxWidth >= 760;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _itemsList(context, state),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _summary(state),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: _itemsList(context, state)),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: _summary(state),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _itemsList(BuildContext context, CartState state, {Widget? footer}) =>
      ListView.separated(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 300 ? 4 : 16,
        ),
        itemCount: state.items.length + (footer == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == state.items.length) return footer!;
          final item = state.items[index];
          return _CartItemTile(item: item);
        },
      );

  Widget _summary(CartState state) => LayoutBuilder(
    builder: (context, constraints) {
      final total = '\$${state.total.toStringAsFixed(2)}';
      if (constraints.maxWidth < 300) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MenuPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MenuPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state.itemCount} ${state.itemCount == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: MenuPalette.muted),
              ),
              const SizedBox(height: 4),
              if (constraints.maxWidth < 120) ...[
                const Text(
                  'Total',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      total,
                      style: const TextStyle(
                        color: MenuPalette.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            total,
                            style: const TextStyle(
                              color: MenuPalette.gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      }
      return _wideSummary(state, total);
    },
  );

  Widget _wideSummary(CartState state, String total) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MenuPalette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MenuPalette.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state.itemCount} ${state.itemCount == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: MenuPalette.muted),
              ),
              const SizedBox(height: 4),
              const Text(
                'Total',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
        Text(
          total,
          style: const TextStyle(
            color: MenuPalette.gold,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  void _removeFromCart(BuildContext context) {
    final cartCubit = context.read<CartCubit>();
    final removedItem = cartCubit.remove(item.meal.id);
    if (removedItem == null) return;

    showAppSnackBar(
      context,
      message: '${item.meal.name} removed from your cart.',
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        textColor: MenuPalette.gold,
        onPressed: () => cartCubit.restore(removedItem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MenuPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MenuPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 300) {
            return _compactLayout(context, constraints.maxWidth);
          }
          final compact = constraints.maxWidth < 420;
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MealImage(
                    url: item.meal.imageUrl,
                    width: compact ? 62 : 76,
                    height: compact ? 62 : 76,
                    cacheWidth: 200,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.meal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${item.meal.price.toStringAsFixed(2)} each',
                        style: const TextStyle(
                          color: MenuPalette.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: MenuPalette.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove ${item.meal.name}',
                      onPressed: () => _removeFromCart(context),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: MenuPalette.muted,
                        size: 20,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuantityButton(
                          icon: Icons.remove,
                          tooltip: 'Decrease quantity',
                          onPressed: () =>
                              context.read<CartCubit>().decrease(item.meal.id),
                          compact: compact,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 4 : 7,
                          ),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        _QuantityButton(
                          icon: Icons.add,
                          tooltip: 'Increase quantity',
                          onPressed: () =>
                              context.read<CartCubit>().increase(item.meal.id),
                          compact: compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _compactLayout(BuildContext context, double width) {
    final imageSize = width < 150 ? 40.0 : 52.0;
    return Padding(
      padding: EdgeInsets.all(width < 150 ? 4 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              tooltip: 'Remove ${item.meal.name}',
              onPressed: () => _removeFromCart(context),
              icon: const Icon(
                Icons.delete_outline,
                color: MenuPalette.muted,
                size: 18,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: MealImage(
              url: item.meal.imageUrl,
              width: imageSize,
              height: imageSize,
              cacheWidth: 120,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.meal.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${item.meal.price.toStringAsFixed(2)} each',
            textAlign: TextAlign.center,
            style: const TextStyle(color: MenuPalette.muted, fontSize: 12),
          ),
          Text(
            '\$${item.total.toStringAsFixed(2)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MenuPalette.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuantityButton(
                icon: Icons.remove,
                tooltip: 'Decrease quantity',
                onPressed: () =>
                    context.read<CartCubit>().decrease(item.meal.id),
                compact: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                tooltip: 'Increase quantity',
                onPressed: () =>
                    context.read<CartCubit>().increase(item.meal.id),
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 20,
              height: 26,
              child: Icon(icon, color: MenuPalette.gold, size: 16),
            ),
          ),
        ),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: MenuPalette.gold, size: 18),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 240;
      final veryNarrow = constraints.maxWidth < 120;
      return Center(
        child: Padding(
          padding: EdgeInsets.all(narrow ? 8 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: MenuPalette.muted,
                size: narrow ? 36 : 52,
              ),
              SizedBox(height: narrow ? 8 : 12),
              Text(
                'Your cart is empty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 14 : 18,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add a meal from the menu to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MenuPalette.muted),
              ),
              const SizedBox(height: 12),
              if (veryNarrow)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Browse menu',
                  icon: const Icon(
                    Icons.restaurant_menu,
                    color: MenuPalette.gold,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.restaurant_menu),
                  label: Text(narrow ? 'Browse' : 'Browse menu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MenuPalette.gold,
                    side: const BorderSide(color: MenuPalette.goldDark),
                    visualDensity: narrow
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
