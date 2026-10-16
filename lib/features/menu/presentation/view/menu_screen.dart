import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../cart/presentation/view/cart_screen.dart';
import '../../../cart/data/services/cart_local_storage.dart';
import '../../../cart/presentation/view_model/cart_cubit.dart';
import '../../../cart/presentation/view_model/cart_state.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../view_model/menu_cubit.dart';
import '../view_model/menu_state.dart';
import '../widgets/category_chips.dart';
import '../widgets/meal_card.dart';
import '../widgets/menu_palette.dart';
import 'meal_details_screen.dart';
import 'menu_management_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.repository});

  final MenuRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MenuCubit(repository)..load()),
        BlocProvider(
          create: (_) => CartCubit(storage: SqliteCartLocalStorage()),
        ),
      ],
      child: _MenuView(repository: repository),
    );
  }
}

class _MenuView extends StatefulWidget {
  const _MenuView({required this.repository});

  final MenuRepository repository;

  @override
  State<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<_MenuView> {
  final _searchController = TextEditingController();
  final _cartNotificationMessage = ValueNotifier<String>('');
  Timer? _cartNotificationTimer;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _cartNotificationController;

  @override
  void dispose() {
    _searchController.dispose();
    _cartNotificationTimer?.cancel();
    _cartNotificationMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      listenWhen: (previous, current) =>
          previous.storageError != current.storageError &&
          current.storageError != null,
      listener: (context, state) {
        showAppSnackBar(context, message: state.storageError!);
      },
      child: BlocListener<MenuCubit, MenuState>(
        listenWhen: (_, current) => current.status == MenuStatus.success,
        listener: (context, _) {
          context.read<CartCubit>().syncAvailableMeals(
            context.read<MenuCubit>().availableMeals,
          );
        },
        child: Scaffold(
          backgroundColor: MenuPalette.bg,
          appBar: AppBar(
            backgroundColor: MenuPalette.bg,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _MenuHeader(
                  onCartTap: () => _openCart(context),
                  onAdminTap: () => _openAdmin(context),
                ),
              ),
            ),
          ),
          body: BlocBuilder<MenuCubit, MenuState>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: TextField(
                            controller: _searchController,
                            onChanged: context.read<MenuCubit>().search,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search meals',
                              hintStyle: const TextStyle(
                                color: MenuPalette.muted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: MenuPalette.muted,
                              ),
                              filled: true,
                              fillColor: MenuPalette.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: MenuPalette.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: MenuPalette.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: MenuPalette.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CategoryChips(
                      selected: state.category,
                      onSelected: context.read<MenuCubit>().selectCategory,
                    ),
                  ),
                  if (state.isFromCache)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Material(
                              color: MenuPalette.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.wifi_off_outlined,
                                  color: MenuPalette.gold,
                                ),
                                title: const Text(
                                  'Showing saved products. Connect to the internet to download updates.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                trailing: IconButton(
                                  onPressed: context.read<MenuCubit>().load,
                                  tooltip: 'Refresh menu',
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: MenuPalette.gold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (state.status == MenuStatus.loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MenuPalette.gold,
                        ),
                      ),
                    )
                  else if (state.status == MenuStatus.failure)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MenuMessage(
                        icon: Icons.wifi_off_outlined,
                        message: state.error ?? 'Could not load meals.',
                        actionLabel: 'Try again',
                        onAction: context.read<MenuCubit>().load,
                      ),
                    )
                  else if (state.meals.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MenuMessage(
                        icon: Icons.restaurant_menu,
                        message: state.isFromCache
                            ? 'No saved products. Connect to the internet to download the menu.'
                            : state.query.isEmpty
                            ? 'No products have been added to the menu yet.'
                            : 'No meals match your search.',
                      ),
                    )
                  else ...[
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final sideInset = width > 1132
                            ? (width - 1100) / 2
                            : 16.0;
                        final contentWidth = width - sideInset * 2;
                        final columnCount = contentWidth < 320
                            ? 1
                            : contentWidth < 700
                            ? 2
                            : contentWidth < 1050
                            ? 3
                            : 4;
                        final cardWidth =
                            (contentWidth - (columnCount - 1) * 14) /
                            columnCount;
                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1).clamp(1.0, 2.0);
                        final aspectRatio =
                            (cardWidth < 120
                                ? 0.68
                                : cardWidth < 190
                                ? 0.74
                                : 0.82) /
                            textScale;

                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            sideInset,
                            0,
                            sideInset,
                            16,
                          ),
                          sliver: SliverGrid.builder(
                            itemCount: state.meals.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnCount,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: aspectRatio,
                                ),
                            itemBuilder: (context, index) {
                              final meal = state.meals[index];
                              return MealCard(
                                meal: meal,
                                onTap: () => _openMeal(context, meal),
                                onAdd: () => _addToCart(context, meal),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          bottomNavigationBar: const _MenuBottomNavigation(),
        ),
      ),
    );
  }

  void _openMeal(BuildContext context, MealModel meal) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => MealDetailsScreen(
          meal: meal,
          onAdd: () => _addToCart(context, meal),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openAdmin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MenuManagementScreen(repository: widget.repository),
      ),
    );
  }

  void _openCart(BuildContext context) {
    _cartNotificationTimer?.cancel();
    _cartNotificationController = null;
    clearAppSnackBars(context);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => BlocProvider.value(
          value: context.read<CartCubit>(),
          child: const CartScreen(),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _addToCart(BuildContext context, MealModel meal) {
    context.read<CartCubit>().add(meal);
    _cartNotificationMessage.value = '${meal.name} added to your cart.';

    if (_cartNotificationController == null) {
      _cartNotificationController = showAppSnackBar(
        context,
        message: _cartNotificationMessage.value,
        messageListenable: _cartNotificationMessage,
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'View cart',
          textColor: MenuPalette.gold,
          onPressed: () => _openCart(context),
        ),
      );
      final controller = _cartNotificationController;
      controller!.closed.whenComplete(() {
        if (identical(_cartNotificationController, controller)) {
          _cartNotificationController = null;
          _cartNotificationTimer?.cancel();
        }
      });
    }

    _cartNotificationTimer?.cancel();
    _cartNotificationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _cartNotificationController?.close();
    });
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.onCartTap, required this.onAdminTap});

  final VoidCallback onCartTap;
  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 240) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              _cartButton(compact: true),
              _adminButton(),
            ],
          );
        }
        return Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MenuPalette.gold, width: 1.2),
              ),
              child: const Icon(
                Icons.person_outline,
                color: MenuPalette.gold,
                size: 23,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GoodFood',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'RESTAURANT',
                    style: TextStyle(
                      color: MenuPalette.gold,
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            _cartButton(compact: true),
            _adminButton(),
          ],
        );
      },
    );
  }

  Widget _adminButton() => IconButton(
    onPressed: onAdminTap,
    tooltip: 'Admin menu',
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 36, height: 40),
    padding: EdgeInsets.zero,
    icon: const Icon(
      Icons.admin_panel_settings_outlined,
      color: MenuPalette.gold,
    ),
  );

  Widget _cartButton({required bool compact}) =>
      BlocBuilder<CartCubit, CartState>(
        builder: (context, state) => Badge(
          isLabelVisible: state.itemCount > 0,
          label: Text('${state.itemCount}'),
          backgroundColor: MenuPalette.success,
          child: IconButton(
            onPressed: onCartTap,
            tooltip: 'Open cart',
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: compact ? 36 : 40,
              height: 40,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.shopping_bag_outlined,
              color: MenuPalette.gold,
            ),
          ),
        ),
      );
}

class _MenuBottomNavigation extends StatelessWidget {
  const _MenuBottomNavigation();

  static const _items = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.receipt_long_outlined, label: 'Orders'),
    (icon: Icons.restaurant_menu_outlined, label: 'Menu'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          color: MenuPalette.bg,
          border: Border(top: BorderSide(color: MenuPalette.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = constraints.maxWidth >= 360;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  children: [
                    for (var index = 0; index < _items.length; index++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: index == 2,
                          label: _items[index].label,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _items[index].icon,
                                size: 20,
                                color: index == 2
                                    ? MenuPalette.gold
                                    : MenuPalette.muted,
                              ),
                              if (showLabels) ...[
                                const SizedBox(height: 3),
                                Text(
                                  _items[index].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: index == 2
                                        ? MenuPalette.gold
                                        : MenuPalette.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MenuMessage extends StatelessWidget {
  const _MenuMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: MenuPalette.muted, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MenuPalette.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: MenuPalette.gold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
