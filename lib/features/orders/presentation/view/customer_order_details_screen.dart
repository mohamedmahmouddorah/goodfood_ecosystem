import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/goodfood_localizations.dart';
import '../../../customer_order_management/data/models/order_item_model.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/presentation/widgets/meal_image.dart';
import '../../data/repositories/customer_orders_repository.dart';
import '../view_models/orders_cubit.dart';
import '../view_models/orders_state.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/orders_palette.dart';

class CustomerOrderDetailsScreen extends StatefulWidget {
  const CustomerOrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.customerIds,
    required this.cancelOrder,
    this.onRateMeal,
  });

  final String orderId;
  final Stream<String?>? customerIds;
  final Future<void> Function(String, {String? reason})? cancelOrder;
  final void Function(String orderId, String mealId)? onRateMeal;

  @override
  State<CustomerOrderDetailsScreen> createState() =>
      _CustomerOrderDetailsScreenState();
}

class _CustomerOrderDetailsScreenState
    extends State<CustomerOrderDetailsScreen> {
  bool _confirming = false;
  bool _submitted = false;

  Future<void> _confirmCancellation(OrderModel order) async {
    final cancel = widget.cancelOrder;
    if (_confirming || _submitted || cancel == null) return;
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
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Order cancelled successfully.')),
      );
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: widget.customerIds,
      builder: (context, identity) => BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          final order = state is OrdersLoadedState
              ? state.orders
                    .where((order) => order.docId == widget.orderId)
                    .firstOrNull
              : null;
          final uid = identity.data;
          return Scaffold(
            backgroundColor: OrdersPalette.background,
            appBar: AppBar(
              backgroundColor: OrdersPalette.background,
              foregroundColor: AppColors.textWhite,
              title: const AppText('Order Details'),
              actions: [
                if (order != null &&
                    !_submitted &&
                    widget.cancelOrder != null &&
                    uid != null &&
                    order.customerId == uid &&
                    order.status == OrderStatus.pending &&
                    order.isUnassigned)
                  IconButton(
                    tooltip: context.tr('Cancel Order'),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.inactiveRed,
                      size: 24,
                    ),
                    onPressed: () => _confirmCancellation(order),
                  ),
              ],
            ),
            body: SafeArea(child: _orderBody(state, order)),
          );
        },
      ),
    );
  }

  Widget _orderBody(OrdersState state, OrderModel? order) {
    if (state is OrdersErrorState) {
      return Center(child: AppText(state.message));
    }
    if (state is! OrdersLoadedState) {
      return const Center(child: CircularProgressIndicator());
    }
    if (order == null) {
      return const Center(child: AppText('This order is unavailable.'));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _orderInfo(order),
            const SizedBox(height: 16),
            const AppText(
              'Order Items',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            ..._mealCards(order),
          ],
        ),
      ),
    );
  }

  String _orderTitle(OrderModel order) {
    final title = order.dispId;
    if (title.isEmpty) return 'Order';
    return title.startsWith('#') ? title : '#$title';
  }

  Widget _orderInfo(OrderModel order) {
    return _card(
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppText(
            _orderTitle(order),
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppText(
            'Table ${order.tableNo}',
            style: const TextStyle(color: OrdersPalette.muted),
          ),
          OrderStatusBadge(status: order.status),
        ],
      ),
    );
  }

  List<Widget> _mealCards(OrderModel order) {
    final canRate =
        order.status == OrderStatus.ready ||
        order.status == OrderStatus.delivered;
    final rate = widget.onRateMeal;
    final mealIdsWithAction = <String>{};
    final cards = <Widget>[];
    for (final meal in order.meals) {
      // A saved meal ID has one rating action even if it occurs on multiple lines.
      final showRate = canRate && mealIdsWithAction.add(meal.mealId);
      cards.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _mealCard(
            meal,
            showRate: showRate,
            onRate: rate == null || order.docId.isEmpty || meal.mealId.isEmpty
                ? null
                : () => rate(order.docId, meal.mealId),
          ),
        ),
      );
    }
    return cards;
  }

  Widget _mealCard(
    OrderItemModel meal, {
    required bool showRate,
    required VoidCallback? onRate,
  }) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 56,
              child: MealImage(url: meal.mealImage, cacheWidth: 120),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealName,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  'Qty: ${meal.quantity}',
                  style: const TextStyle(color: OrdersPalette.muted),
                ),
                if (showRate) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrdersPalette.gold,
                    ),
                    onPressed: onRate,
                    child: const AppText('Rate Meal'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Card(
    margin: EdgeInsets.zero,
    color: OrdersPalette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: OrdersPalette.border),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
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
    });
    try {
      await widget.onCancel(_reason.text.trim());
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on OrderCancellationException catch (error) {
      _error = error.message;
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
                  maxLines: 4,
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
                  AppText(
                    _error!,
                    style: const TextStyle(color: AppColors.inactiveRed),
                  ),
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
