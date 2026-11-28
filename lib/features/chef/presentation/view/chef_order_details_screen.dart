import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/presentation/widgets/meal_image.dart';
import '../../../orders/presentation/widgets/order_status_badge.dart';
import '../../../orders/presentation/widgets/orders_palette.dart';
import '../view_model/chef_orders_cubit.dart';
import '../view_model/chef_orders_state.dart';

class ChefOrderDetailsScreen extends StatelessWidget {
  const ChefOrderDetailsScreen({
    super.key,
    required this.orderId,
    this.historyOnly = false,
  });

  final String orderId;
  final bool historyOnly;

  OrderModel? _findOrder(ChefOrdersState state) {
    final queues = state.queues;
    if (queues == null) return null;

    // The two Firestore queries can update at different times.
    final lists = historyOnly
        ? [queues.history]
        : [queues.active, queues.ready, queues.incoming];
    for (final orders in lists) {
      for (final order in orders) {
        if (order.docId == orderId) return order;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OrdersPalette.background,
    appBar: AppBar(
      backgroundColor: OrdersPalette.background,
      foregroundColor: Colors.white,
      title: const AppText('Order Details'),
    ),
    body: SafeArea(
      child: BlocConsumer<ChefOrdersCubit, ChefOrdersState>(
        listenWhen: (previous, current) =>
            previous.noticeId != current.noticeId && current.notice != null,
        listener: (context, state) {
          if (ModalRoute.of(context)?.isCurrent == false) return;
          showAppSnackBar(
            context,
            message: state.noticeMessage!,
            kind: switch (state.notice) {
              ChefNotice.accepted || ChefNotice.ready => FeedbackKind.success,
              ChefNotice.conflict => FeedbackKind.warning,
              _ => FeedbackKind.error,
            },
          );
        },
        builder: (context, state) {
          if (state.status == ChefOrdersStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: OrdersPalette.gold),
            );
          }
          if (state.status == ChefOrdersStatus.error) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: AppText(
                  'Could not load kitchen orders. Check your connection and Firestore permissions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OrdersPalette.muted),
                ),
              ),
            );
          }
          final order = _findOrder(state);
          if (order == null ||
              (!historyOnly && order.status == OrderStatus.canceled)) {
            return const Center(
              child: AppText(
                'This order is no longer available.',
                style: TextStyle(color: OrdersPalette.muted),
              ),
            );
          }

          final cubit = context.read<ChefOrdersCubit>();
          final canAccept =
              order.status == OrderStatus.pending && order.isUnassigned;
          final canMarkReady =
              order.status == OrderStatus.preparing &&
              order.acceptedByChefId == state.queues!.chef.uid;
          final busy = state.busyIds.contains(orderId);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 84),
                children: [
                  _summary(context, order, cubit.source.assignmentName(order)),
                  const SizedBox(height: 12),
                  _meals(order),
                  if (!historyOnly && (canAccept || canMarkReady)) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OrdersPalette.gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: busy
                          ? null
                          : () {
                              if (canAccept) {
                                cubit.accept(orderId);
                              } else {
                                cubit.markReady(orderId);
                              }
                            },
                      child: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : AppText(canAccept ? 'Accept Order' : 'Mark Ready'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _summary(BuildContext context, OrderModel order, String? chefName) {
    final localizations = MaterialLocalizations.of(context);
    final created = order.createdAt.toLocal();
    final date = localizations.formatFullDate(created);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(created));
    final displayId = order.dispId.isEmpty ? order.docId : order.dispId;
    final customerName = order.clientName?.trim();

    return Card(
      color: OrdersPalette.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  displayId.startsWith('#') ? displayId : '#$displayId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                AppText(
                  'Table ${order.tableNo}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '${context.tr('Guests')} ${order.noOfGuests}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$date · $time',
              style: const TextStyle(color: OrdersPalette.muted),
            ),
            if (customerName != null && customerName.isNotEmpty)
              _person('Customer', customerName),
            if (chefName != null && chefName.trim().isNotEmpty)
              _person('Assigned chef', chefName),
          ],
        ),
      ),
    );
  }

  Widget _person(String label, String name) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      children: [
        AppText(label, style: const TextStyle(color: OrdersPalette.gold)),
        Text(name, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );

  Widget _meals(OrderModel order) => Card(
    color: OrdersPalette.surface,
    child: Column(
      children: [
        for (final meal in order.meals)
          ListTile(
            leading: meal.mealImage.trim().isEmpty
                ? null
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MealImage(
                      url: meal.mealImage,
                      width: 48,
                      height: 48,
                    ),
                  ),
            title: Text(
              meal.mealName,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Text(
              '×${meal.quantity}',
              style: const TextStyle(color: OrdersPalette.gold),
            ),
          ),
      ],
    ),
  );
}
