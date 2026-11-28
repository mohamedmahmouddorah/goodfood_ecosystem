import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/goodfood_localizations.dart';
import '../../../customer_order_management/data/models/order_item_model.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/presentation/widgets/meal_image.dart';
import '../view_models/orders_cubit.dart';
import '../view_models/orders_state.dart';
import '../widgets/order_cancellation_reason.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/orders_palette.dart';

class CustomerOrderDetailsScreen extends StatelessWidget {
  const CustomerOrderDetailsScreen({
    super.key,
    required this.orderId,
    this.onRateMeal,
  });

  final String orderId;
  final void Function(String orderId, String mealId)? onRateMeal;

  @override
  Widget build(BuildContext context) => BlocBuilder<OrdersCubit, OrdersState>(
    builder: (context, state) {
      final order = state is OrdersLoadedState
          ? state.orders.where((order) => order.docId == orderId).firstOrNull
          : null;
      return Scaffold(
        backgroundColor: OrdersPalette.background,
        appBar: AppBar(
          backgroundColor: OrdersPalette.background,
          foregroundColor: AppColors.textWhite,
          title: const AppText('Order Details'),
        ),
        body: SafeArea(child: _orderBody(state, order)),
      );
    },
  );

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
            if (order.status == OrderStatus.canceled) ...[
              const SizedBox(height: 12),
              _card(
                child: OrderCancellationReason(
                  reason: order.cancellationReason,
                ),
              ),
            ],
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
            if (order.status == OrderStatus.delivered && onRateMeal != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: OrdersPalette.gold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => onRateMeal!(order.docId, ''),
                  icon: const Icon(Icons.star_rounded),
                  label: const AppText('Rate this order'),
                ),
              ),
            ],
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

  List<Widget> _mealCards(OrderModel order) => [
    for (final meal in order.meals)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _mealCard(meal, showRate: false, onRate: null),
      ),
  ];

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
