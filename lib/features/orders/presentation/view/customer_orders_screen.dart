import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
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
import 'customer_order_details_screen.dart';

/// Pass customer-scoped IDs from the session, or inject an existing data stream.
/// No IDs means no orders; this screen never queries all restaurant orders.
class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({
    super.key,
    this.orderIds = const [],
    this.loadOrders,
    this.onOrderTap,
    this.onNotificationsTap,
    this.watchCustomerId,
    this.cancelOrder,
    this.onRateMeal,
  });

  final List<String> orderIds;
  final OrdersLoader? loadOrders;
  final ValueChanged<OrderModel>? onOrderTap;
  final VoidCallback? onNotificationsTap;
  final Stream<String?> Function()? watchCustomerId;
  final Future<void> Function(String, {String? reason})? cancelOrder;

  /// Open the rating screen with the Firestore order ID and saved meal ID.
  final void Function(String orderId, String mealId)? onRateMeal;

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
      child: Builder(
        builder: (context) => _OrdersView(
          onOrderTap:
              onOrderTap ??
              (order) {
                final cubit = context.read<OrdersCubit>();
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: CustomerOrderDetailsScreen(
                        orderId: order.docId,
                        onRateMeal: onRateMeal,
                      ),
                    ),
                  ),
                );
              },
          onNotificationsTap: onNotificationsTap,
          watchCustomerId: watchCustomerId,
          cancelOrder: cancelOrder,
        ),
      ),
    );
  }
}

class _OrdersView extends StatefulWidget {
  const _OrdersView({
    this.onOrderTap,
    this.onNotificationsTap,
    this.watchCustomerId,
    this.cancelOrder,
  });

  final ValueChanged<OrderModel>? onOrderTap;
  final VoidCallback? onNotificationsTap;
  final Stream<String?> Function()? watchCustomerId;
  final Future<void> Function(String, {String? reason})? cancelOrder;

  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  late Stream<String?>? _customerIds = widget.watchCustomerId?.call();
  final _submitted = <String>{};
  bool _confirming = false;

  @override
  void didUpdateWidget(covariant _OrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watchCustomerId != widget.watchCustomerId) {
      _customerIds = widget.watchCustomerId?.call();
    }
  }

  Future<void> _confirmCancellation(OrderModel order) async {
    final cancel = widget.cancelOrder;
    if (_confirming || _submitted.contains(order.docId) || cancel == null) {
      return;
    }
    _confirming = true;
    try {
      final canceled = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: OrdersPalette.surface,
        showDragHandle: false,
        useSafeArea: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _CancellationSheet(
          orderTitle: _orderTitle(order),
          onCancel: (reason) => cancel(order.docId, reason: reason),
        ),
      );
      if (canceled != true || !mounted) return;
      setState(() => _submitted.add(order.docId));
      showAppSnackBar(
        context,
        message: 'Order cancelled successfully',
        kind: FeedbackKind.success,
      );
    } finally {
      _confirming = false;
    }
  }

  String _orderTitle(OrderModel order) {
    final title = order.dispId;
    if (title.isEmpty) return 'Order';
    return title.startsWith('#') ? title : '#$title';
  }

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
                    child: StreamBuilder<String?>(
                      stream: _customerIds,
                      builder: (context, identity) =>
                          BlocBuilder<OrdersCubit, OrdersState>(
                            builder: (context, state) {
                              final orders = state is OrdersLoadedState
                                  ? state.visibleOrders
                                  : <OrderModel>[];
                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      padding: EdgeInsets.all(wide ? 32 : 20),
                                      itemCount:
                                          1 +
                                          (orders.isEmpty ? 1 : orders.length),
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return _header(context, state);
                                        }
                                        if (state is OrdersInitialState ||
                                            state is OrdersLoadingState) {
                                          return const Padding(
                                            padding: EdgeInsets.all(48),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primaryGold,
                                                semanticsLabel:
                                                    'Loading orders',
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
                                              onPressed: context
                                                  .read<OrdersCubit>()
                                                  .load,
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
                                            message:
                                                state.tab == OrdersTab.active
                                                ? 'Your current orders will appear here.'
                                                : 'Delivered and cancelled orders will appear here.',
                                          );
                                        }
                                        final order = orders[index - 1];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: OrderCard(
                                            order: order,
                                            onTap: widget.onOrderTap == null
                                                ? null
                                                : () =>
                                                      widget.onOrderTap!(order),
                                            onCancel:
                                                _customerIds != null &&
                                                    widget.cancelOrder !=
                                                        null &&
                                                    identity.connectionState !=
                                                        ConnectionState
                                                            .waiting &&
                                                    identity.data != null &&
                                                    order.customerId ==
                                                        identity.data &&
                                                    order.status ==
                                                        OrderStatus.pending &&
                                                    order.isUnassigned &&
                                                    !_submitted.contains(
                                                      order.docId,
                                                    )
                                                ? () => _confirmCancellation(
                                                    order,
                                                  )
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
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
                            fontSize: MediaQuery.sizeOf(context).width >= 800
                                ? 34
                                : 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.7,
                          ),
                        ),
                        AppText(
                          'RESTAURANT',
                          style: TextStyle(
                            color: OrdersPalette.gold,
                            fontSize: MediaQuery.sizeOf(context).width >= 800
                                ? 13
                                : 9,
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
                  widget.onNotificationsTap == null
                      ? 'Notifications unavailable'
                      : 'Notifications',
                ),
                onPressed: widget.onNotificationsTap,
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
            style: TextStyle(
              color: OrdersPalette.muted,
              fontSize: MediaQuery.sizeOf(context).width >= 800 ? 18 : 14,
            ),
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

class _CancellationSheet extends StatefulWidget {
  const _CancellationSheet({required this.orderTitle, required this.onCancel});

  final String orderTitle;
  final Future<void> Function(String reason) onCancel;

  @override
  State<_CancellationSheet> createState() => _CancellationSheetState();
}

class _CancellationSheetState extends State<_CancellationSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  FeedbackKind _errorKind = FeedbackKind.error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _errorKind = FeedbackKind.error;
    });
    try {
      await widget.onCancel(_reason.text.trim());
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on OrderCancellationException catch (error) {
      _error = error.message;
      _errorKind = FeedbackKind.warning;
    } on FirebaseException catch (error) {
      _error = switch (error.code) {
        'permission-denied' ||
        'unauthenticated' => 'You do not have permission to cancel this order.',
        'unavailable' ||
        'deadline-exceeded' => 'Check your connection and try again.',
        'aborted' => 'The order changed. Check its status and try again.',
        _ => 'Unable to cancel this order. Please try again.',
      };
    } catch (_) {
      _error = 'Unable to cancel this order. Please try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inactiveRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.inactiveRed,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppText(
                  'Cancel Order?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                const AppText(
                  'Are you sure you want to cancel this order? This action cannot be undone.',
                  style: TextStyle(color: OrdersPalette.muted),
                ),
                const SizedBox(height: 12),
                AppText(
                  widget.orderTitle,
                  style: const TextStyle(color: OrdersPalette.gold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reason,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText: context.tr('Reason for cancellation (Optional)'),
                    hintText: context.tr('Tell us why you want to cancel...'),
                    labelStyle: const TextStyle(color: OrdersPalette.muted),
                    hintStyle: const TextStyle(color: OrdersPalette.muted),
                    counterStyle: const TextStyle(color: OrdersPalette.muted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  AppInlineFeedback(_error!, kind: _errorKind),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textWhite,
                    side: const BorderSide(color: OrdersPalette.muted),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const AppText('Keep Order'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inactiveRed,
                    foregroundColor: AppColors.textWhite,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : _cancel,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppText('Yes, Cancel Order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
