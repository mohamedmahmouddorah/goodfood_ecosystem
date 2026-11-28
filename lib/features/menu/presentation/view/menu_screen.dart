import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/cart_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';

import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../view_model/menu_cubit.dart';
import '../view_model/menu_state.dart';
import '../widgets/category_chips.dart';
import '../widgets/meal_card.dart';
import '../widgets/menu_message.dart';
import '../widgets/menu_palette.dart';
import '../../../customer_order_management/presentation/view/customer_details_view.dart';
import 'meal_details_screen.dart';
import '../../../orders/presentation/navigation/customer_orders_navigation.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      listener: (context, state) {
        if (state is AddToCartFailState) {
          showAppSnackBar(
            context,
            message: state.msg,
            kind: FeedbackKind.error,
          );
        } else if (state is AddToCartSuccessState) {
          showAppSnackBar(
            context,
            message: '${state.item.mealName} added successfully!',
            kind: FeedbackKind.success,
          );
        }
      },
      child: Scaffold(
        backgroundColor: MenuPalette.bg,
        body: LayoutBuilder(
          builder: (context, layout) {
            final useSideNavigation = layout.maxWidth >= 1000;
            final menuContent = BlocBuilder<MenuCubit, MenuState>(
              builder: (context, state) => CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            layout.maxWidth >= 1400 ? 48 : 28,
                            layout.maxWidth >= 1400 ? 40 : 28,
                            layout.maxWidth >= 1400 ? 48 : 28,
                            22,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'Our menu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                        MediaQuery.sizeOf(context).width >= 800
                                        ? 36
                                        : 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                AppText(
                                  'Made fresh, served with care.',
                                  style: TextStyle(
                                    color: MenuPalette.muted,
                                    fontSize:
                                        MediaQuery.sizeOf(context).width >= 800
                                        ? 18
                                        : 14,
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
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            layout.maxWidth >= 1400 ? 48 : 28,
                            8,
                            layout.maxWidth >= 1400 ? 48 : 28,
                            20,
                          ),
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
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical:
                                    MediaQuery.sizeOf(context).width >= 800
                                    ? 19
                                    : 14,
                              ),
                              isDense: false,
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
                            constraints: const BoxConstraints(maxWidth: 1600),
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
                        child: CircularProgressIndicator(
                          color: MenuPalette.gold,
                        ),
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
                        message:
                            state.query.isNotEmpty || state.category != null
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
                        final maxGridWidth = 1600.0;
                        final sideInset = width > maxGridWidth + 32
                            ? (width - maxGridWidth) / 2
                            : 16.0;
                        final contentWidth = width - sideInset * 2;
                        final columnCount = contentWidth < 320
                            ? 1
                            : contentWidth < 1100
                            ? 2
                            : contentWidth < 1550
                            ? 3
                            : 4;
                        final cardWidth =
                            (contentWidth -
                                (columnCount - 1) *
                                    (contentWidth >= 800 ? 22 : 14)) /
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
                                  mainAxisSpacing: contentWidth >= 800
                                      ? 24
                                      : 14,
                                  crossAxisSpacing: contentWidth >= 800
                                      ? 22
                                      : 14,
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
              ),
            );
            final sideNavigation = AppNavigationRail(
              items: _navigationItems(),
              selectedIndex: 1,
              onDestinationSelected: (index) =>
                  _handleNavigation(context, index),
              backgroundColor: MenuPalette.bg,
              indicatorColor: MenuPalette.surface,
              selectedColor: MenuPalette.gold,
              unselectedColor: MenuPalette.muted,
              width: 240,
            );
            final toolbarHeight = useSideNavigation ? 104.0 : 64.0;
            final menuAppBar = SizedBox(
              height: toolbarHeight,
              child: AppBar(
                backgroundColor: MenuPalette.bg,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                toolbarHeight: toolbarHeight,
                titleSpacing: useSideNavigation ? 28 : 16,
                title: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: _MenuHeader(onAdminTap: () => _openAdmin(context)),
                  ),
                ),
              ),
            );

            if (useSideNavigation) {
              return SafeArea(
                child: Row(
                  textDirection: Directionality.of(context),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sideNavigation,
                    Expanded(
                      child: Column(
                        children: [
                          menuAppBar,
                          Expanded(child: menuContent),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              child: Column(
                children: [
                  menuAppBar,
                  Expanded(child: menuContent),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width >= 1000
            ? null
            : AppBottomNavigationBar(
                items: [
                  ..._navigationItems(),
                  const AppNavigationItem(
                    label: 'Account',
                    icon: Icons.person_outline,
                  ),
                ],
                selectedIndex: 1,
                onDestinationSelected: (index) =>
                    _handleNavigation(context, index),
                backgroundColor: MenuPalette.bg,
                indicatorColor: MenuPalette.surface,
                selectedColor: MenuPalette.gold,
                unselectedColor: MenuPalette.muted,
              ),
      ),
    );
  }

  List<AppNavigationItem> _navigationItems() => const [
    AppNavigationItem(label: 'Home', icon: Icons.home_outlined),
    AppNavigationItem(label: 'Menu', icon: Icons.restaurant_menu_outlined),
    AppNavigationItem(label: 'Orders', icon: Icons.receipt_long_outlined),
  ];

  void _handleNavigation(BuildContext context, int index) {
    if (index == 0) {
      final customerCubit = context.read<CustomerOrderCubit?>();
      if (customerCubit == null) {
        Navigator.of(context).pushNamed('/welcome');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: customerCubit,
            child: const CustomerDetailsView(editMode: true),
          ),
        ),
      );
    }
    if (index == 2) openCustomerOrders(context);
    if (index == 3) _showCustomerDetails(context);
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
  const _MenuHeader({required this.onAdminTap});
  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 240) {
          return const Row(
            children: [
              Expanded(
                child: Text(
                  'Menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              _CartButton(),
            ],
          );
        }

        final large = constraints.maxWidth >= 800;
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
            Expanded(
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
                  AppText(
                    'RESTAURANT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MenuPalette.gold,
                      fontSize: large ? 17 : 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const LanguageToggle(),
            const _CartButton(),
          ],
        );
      },
    );
  }
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
          tooltip: 'Cart',
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints.tightFor(
            width: MediaQuery.sizeOf(context).width >= 800 ? 48 : 36,
            height: MediaQuery.sizeOf(context).width >= 800 ? 48 : 40,
          ),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.shopping_cart_outlined,
            color: MenuPalette.gold,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              final numOfItems = state.cartItems.fold<int>(
                0,
                (sum, item) => sum + item.quantity,
              );

              return Text('$numOfItems', style: AppFonts.smallGoldTiltle);
            },
          ),
        ),
      ],
    );
  }
}
