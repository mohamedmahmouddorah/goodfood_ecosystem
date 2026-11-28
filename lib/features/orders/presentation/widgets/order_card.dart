import 'package:goodfood_ecosystem/core/widgets/app_trash_button.dart';
import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/presentation/widgets/meal_image.dart';
import 'order_cancellation_reason.dart';
import 'order_status_badge.dart';
import 'orders_palette.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap, this.onCancel});
  final OrderModel order;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final count = order.meals.fold<int>(0, (sum, meal) => sum + meal.quantity);
    final date = order.createdAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final timestamp =
        '${localizations.formatMediumDate(date)} - '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
    return Material(
      color: OrdersPalette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: OrdersPalette.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 290;
              final identity = Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppText(
                    order.dispId.isEmpty
                        ? 'Order'
                        : order.dispId.startsWith('#')
                        ? order.dispId
                        : '#${order.dispId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppText(
                    'Table ${order.tableNo}',
                    style: const TextStyle(
                      color: OrdersPalette.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    identity,
                    const SizedBox(height: 10),
                    OrderStatusBadge(status: order.status),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 8),
                        OrderStatusBadge(status: order.status),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (order.acceptedByChefName != null) ...[
                    Wrap(
                      spacing: 6,
                      children: [
                        const AppText(
                          'Assigned chef',
                          style: TextStyle(
                            color: OrdersPalette.gold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          order.acceptedByChefName!,
                          style: const TextStyle(
                            color: OrdersPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: OrdersPalette.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (compact && order.meals.isNotEmpty) ...[
                    _thumbnails(),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      if (!compact && order.meals.isNotEmpty) ...[
                        _thumbnails(),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: AppText(
                          '$count ${count == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            color: OrdersPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '\$${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          color: OrdersPalette.muted,
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                  if (order.status == OrderStatus.canceled) ...[
                    const SizedBox(height: 12),
                    OrderCancellationReason(reason: order.cancellationReason),
                  ],
                  if (onCancel != null)
                    AppTrashButton(label: 'Cancel Order', onPressed: onCancel!),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _thumbnails() {
    final meals = order.meals.take(3).toList();
    return SizedBox(
      width: 40 + (meals.length - 1) * 32,
      height: 42,
      child: Stack(
        children: [
          for (var index = 0; index < meals.length; index++)
            PositionedDirectional(
              start: index * 32,
              top: 0,
              child: Tooltip(
                message: meals[index].mealName,
                child: Container(
                  width: 40,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: OrdersPalette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MealImage(
                    url: meals[index].mealImage,
                    width: 40,
                    height: 42,
                    cacheWidth: 120,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
