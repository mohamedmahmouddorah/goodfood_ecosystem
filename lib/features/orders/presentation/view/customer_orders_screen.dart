import 'package:goodfood_ecosystem/core/firebase/firebase_environment.dart';
import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../data/repositories/customer_orders_repository.dart';
import '../view_models/orders_cubit.dart';
import '../view_models/orders_state.dart';
import '../widgets/order_card.dart';
import '../widgets/orders_palette.dart';

/// Pass customer-scoped IDs from the session, or inject an existing data stream.
/// No IDs means no orders; this screen never queries all restaurant orders.
class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({
    super.key,
    this.orderIds = const [],
    this.loadOrders,
    this.onOrderTap,
    this.onNotificationsTap,
  });

  final List<String> orderIds;
  final OrdersLoader? loadOrders;
  final ValueChanged<OrderModel>? onOrderTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersCubit(
        loadOrders:
            loadOrders ??
            () {
              if (orderIds.isEmpty) return Stream.value(<OrderModel>[]);
              return CustomerOrdersRepository(
                FirebaseEnvironment.store,
              ).watchOrders(orderIds);
            },
      )..load(),
      child: _OrdersView(
        onOrderTap: onOrderTap,
        onNotificationsTap: onNotificationsTap,
      ),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView({this.onOrderTap, this.onNotificationsTap});

  final ValueChanged<OrderModel>? onOrderTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final navigationItems = const [
      AppNavigationItem(label: 'Home', icon: Icons.home_outlined),
      AppNavigationItem(label: 'Menu', icon: Icons.restaurant_menu_outlined),
      AppNavigationItem(label: 'Orders', icon: Icons.receipt_long_outlined),
    ];

    void navigate(int index) {
      switch (index) {
        case 0:
          Navigator.of(context).pushNamed('/customer_details');
          break;
        case 1:
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          break;
      }
    }

    return Scaffold(
      backgroundColor: OrdersPalette.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              OrdersPalette.headerGlow,
              Color(0xFF18150F),
              OrdersPalette.background,
            ],
            stops: [0, .45, 1],
          ),
        ),
        child: SafeArea(
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              if (wide)
                AppNavigationRail(
                  items: navigationItems,
                  selectedIndex: 2,
                  onDestinationSelected: navigate,
                  backgroundColor: OrdersPalette.background,
                  indicatorColor: OrdersPalette.surface,
                  selectedColor: OrdersPalette.gold,
                  unselectedColor: OrdersPalette.muted,
                  width: 260,
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: BlocBuilder<OrdersCubit, OrdersState>(
                      builder: (context, state) {
                        final orders = state is OrdersLoadedState
                            ? state.visibleOrders
                            : <OrderModel>[];
                        return ListView.builder(
                          padding: EdgeInsets.all(wide ? 32 : 20),
                          itemCount: 1 + (orders.isEmpty ? 1 : orders.length),
                          itemBuilder: (context, index) {
                            if (index == 0) return _header(context, state);
                            if (state is OrdersInitialState ||
                                state is OrdersLoadingState) {
                              return const Padding(
                                padding: EdgeInsets.all(48),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryGold,
                                    semanticsLabel: 'Loading orders',
                                  ),
                                ),
                              );
                            }
                            if (state is OrdersErrorState) {
                              return _OrdersMessage(
                                icon: Icons.cloud_off_outlined,
                                title: 'Unable to load orders',
                                message: state.message,
                                action: OutlinedButton.icon(
                                  onPressed: context.read<OrdersCubit>().load,
                                  icon: const Icon(Icons.refresh),
                                  label: const AppText('Try again'),
                                ),
                              );
                            }
                            if (orders.isEmpty) {
                              return _OrdersMessage(
                                icon: state.tab == OrdersTab.active
                                    ? Icons.receipt_long_outlined
                                    : Icons.history,
                                title: state.tab == OrdersTab.active
                                    ? 'No active orders'
                                    : 'No order history yet',
                                message: state.tab == OrdersTab.active
                                    ? 'Your current orders will appear here.'
                                    : 'Delivered and cancelled orders will appear here.',
                              );
                            }
                            final order = orders[index - 1];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: OrderCard(
                                order: order,
                                onTap: onOrderTap == null
                                    ? null
                                    : () => onOrderTap!(order),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : AppBottomNavigationBar(
              items: navigationItems,
              selectedIndex: 2,
              onDestinationSelected: navigate,
              backgroundColor: OrdersPalette.background,
              indicatorColor: OrdersPalette.surface,
              selectedColor: OrdersPalette.gold,
              height: 64,
              maxWidth: 1500,
            ),
    );
  }

  Widget _header(BuildContext context, OrdersState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                const BackButton(color: AppColors.textWhite),
              Icon(
                Icons.restaurant_rounded,
                color: AppColors.primaryGold,
                size: MediaQuery.sizeOf(context).width >= 800 ? 38 : 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GoodFood',
                          style: TextStyle(
                            color: OrdersPalette.gold,
                            fontSize: MediaQuery.sizeOf(context).width >= 800 ? 34 : 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.7,
                          ),
                        ),
                        AppText(
                          'RESTAURANT',
                          style: TextStyle(
                            color: OrdersPalette.gold,
                            fontSize: MediaQuery.sizeOf(context).width >= 800 ? 13 : 9,
                            letterSpacing: 2.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const LanguageToggle(),
              IconButton(
                tooltip: context.tr(
                  onNotificationsTap == null
                      ? 'Notifications unavailable'
                      : 'Notifications',
                ),
                onPressed: onNotificationsTap,
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: 28),
           AppText(
            'Your orders',
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: MediaQuery.sizeOf(context).width >= 800 ? 42 : 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
           AppText(
            'Track and review your restaurant orders',
            style: TextStyle(color: OrdersPalette.muted, fontSize: MediaQuery.sizeOf(context).width >= 800 ? 18 : 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF111213),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: OrdersPalette.border),
            ),
            child: Row(
              children: [
                for (final tab in OrdersTab.values)
                  Expanded(
                    child: Semantics(
                      selected: state.tab == tab,
                      button: true,
                      child: Material(
                        color: state.tab == tab
                            ? OrdersPalette.gold
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () =>
                              context.read<OrdersCubit>().selectTab(tab),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AppText(
                                tab == OrdersTab.active
                                    ? 'Active Orders'
                                    : 'Order History',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: state.tab == tab
                                      ? Colors.black
                                      : OrdersPalette.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersMessage extends StatelessWidget {
  const _OrdersMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.primaryGold),
          const SizedBox(height: 20),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
