import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/cart_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';

import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../orders/presentation/navigation/customer_orders_navigation.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../view_model/menu_cubit.dart';
import '../view_model/menu_state.dart';
import '../widgets/category_chips.dart';
import '../widgets/meal_card.dart';
import '../widgets/menu_message.dart';
import '../widgets/menu_palette.dart';
import 'meal_details_screen.dart';
import 'menu_management_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.repository, required this.repo});

  final MenuRepository repository;
  final CartRepo repo;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MenuCubit(repository)..load()),
        BlocProvider(create: (_) => CartCubit(repo: repo)..loadCartData()),
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
      listener: (context, state) {
        if (state is AddToCartFailState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16.0),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppColors.errorIconBackground,
                      ),
                      child: Icon(
                        Icons.error,
                        size: 20,
                        color: AppColors.errorIcon,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppText(
                      state.msg,
                      style: AppFonts.mainTitle.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.errorBackground,
              behavior: SnackBarBehavior.floating,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: AppColors.errorBorder),
              ),
            ),
          );
        }
        if (state is AddToCartSuccessState) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 24,
                        color: AppColors.addChefBtn,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Added to cart',
                            style: AppFonts.mainTitle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            '${state.item.mealName} added successfully!',
                            style: AppFonts.mainTitle.copyWith(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1C2522),
                behavior: SnackBarBehavior.floating,
                elevation: 8,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                duration: const Duration(seconds: 3),
                dismissDirection: DismissDirection.horizontal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.goldLight.withValues(alpha: 0.35),
                  ),
                ),
              ),
            );
        }
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
                onProfileTap: () => _showCustomerDetails(context),
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
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 18),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Our menu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              AppText(
                                'Made fresh, served with care.',
                                style: TextStyle(
                                  color: MenuPalette.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                            hintText: context.tr('Search meals'),
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
                              horizontal: 16,
                              vertical: 14,
                            ),
                            isDense: true,
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _searchController,
                                  builder: (_, value, _) => value.text.isEmpty
                                      ? const SizedBox.shrink()
                                      : IconButton(
                                          tooltip: context.tr('Clear search'),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            context.read<MenuCubit>().search(
                                              '',
                                            );
                                          },
                                        ),
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
                if (state.isRefreshing && state.meals.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      color: MenuPalette.gold,
                      minHeight: 2,
                      backgroundColor: MenuPalette.border,
                    ),
                  ),
                if (state.isFromCache ||
                    (state.error != null && state.meals.isNotEmpty))
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
                              title: AppText(
                                state.error ??
                                    'Showing saved menu while checking for updates.',
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: IconButton(
                                onPressed: context.read<MenuCubit>().load,
                                tooltip: context.tr('Refresh menu'),
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
                      child: CircularProgressIndicator(color: MenuPalette.gold),
                    ),
                  )
                else if (state.status == MenuStatus.failure)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MenuMessage(
                      icon: Icons.wifi_off_outlined,
                      message: state.error ?? 'Could not load meals.',
                      actionLabel: 'Try again',
                      onAction: context.read<MenuCubit>().load,
                    ),
                  )
                else if (state.meals.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MenuMessage(
                      icon: Icons.restaurant_menu,
                      message: state.query.isNotEmpty || state.category != null
                          ? 'No meals match your search.'
                          : state.isFromCache
                          ? 'No saved products. Connect to the internet to download the menu.'
                          : 'No products have been added to the menu yet.',
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
                          (contentWidth - (columnCount - 1) * 14) / columnCount;
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
                              onAdd: () {
                                context.read<CartCubit>().addToCart(meal);
                              },
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
        bottomNavigationBar: AppBottomNavigationBar(
          items: const [
            AppNavigationItem(label: 'Home', icon: Icons.home_outlined),
            AppNavigationItem(
              label: 'Menu',
              icon: Icons.restaurant_menu_outlined,
            ),
            AppNavigationItem(
              label: 'Orders',
              icon: Icons.receipt_long_outlined,
            ),
            AppNavigationItem(label: 'Account', icon: Icons.person_outline),
          ],
          selectedIndex: 1,
          onDestinationSelected: (index) {
            if (index == 0) Navigator.of(context).pushNamed('/welcome');
            if (index == 2) openCustomerOrders(context);
            if (index == 3) _showCustomerDetails(context);
          },
          backgroundColor: MenuPalette.bg,
          indicatorColor: MenuPalette.surface,
          selectedColor: MenuPalette.gold,
          unselectedColor: MenuPalette.muted,
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
          onAdd: () {
            context.read<CartCubit>().addToCart(meal);
          },
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

  void _showCustomerDetails(BuildContext context) {
    final customer = context.read<CustomerOrderCubit?>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: MenuPalette.surface,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Your Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (customer?.name?.isNotEmpty == true)
                Text(
                  customer!.name!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              if (customer?.tableNo != null)
                AppText(
                  'Table ${customer!.tableNo}',
                  style: const TextStyle(color: MenuPalette.gold, fontSize: 16),
                ),
              if (customer?.tableNo == null)
                const AppText(
                  'No customer details yet.',
                  style: TextStyle(color: MenuPalette.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.onProfileTap, required this.onAdminTap});
  final VoidCallback onProfileTap;
  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Row(
        children: [
          const Icon(
            Icons.restaurant_rounded,
            color: MenuPalette.gold,
            size: 25,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GoodFood',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppText(
                  'RESTAURANT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MenuPalette.gold,
                    fontSize: 9,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (constraints.maxWidth >= 340)
            IconButton(
              onPressed: null,
              tooltip: context.tr('Notifications unavailable'),
              icon: const Icon(Icons.notifications_none_rounded, size: 21),
              constraints: const BoxConstraints.tightFor(width: 36, height: 40),
              padding: EdgeInsets.zero,
            ),
          const _CartButton(),
          const SizedBox(width: 6),
          const LanguageToggle(),
          IconButton(
            onPressed: onProfileTap,
            tooltip: context.tr('Account'),
            icon: const Icon(
              Icons.person_outline_rounded,
              color: MenuPalette.muted,
              size: 21,
            ),
            constraints: const BoxConstraints.tightFor(width: 32, height: 40),
            padding: EdgeInsets.zero,
          ),
        ],
      );
    },
  );
}

class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: context.read<CartCubit>()),
                    BlocProvider.value(
                      value: context.read<CustomerOrderCubit>(),
                    ),
                  ],
                  child: CartView(repository: context.read<MenuCubit>().repo),
                ),
              ),
            );
          },
          tooltip: context.tr('Cart'),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 40),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.shopping_cart_outlined,
            color: MenuPalette.gold,
          ),
        ),
        PositionedDirectional(
          end: 0,
          top: 0,
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              final numOfItems = state.cartItems.fold<int>(
                0,
                (sum, item) => sum + item.quantity,
              );

              if (numOfItems == 0) return const SizedBox.shrink();
              return Container(
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: MenuPalette.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  numOfItems > 99 ? '99+' : '$numOfItems',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
