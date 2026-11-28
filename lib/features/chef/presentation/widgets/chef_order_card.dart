import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/goodfood_localizations.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../orders/presentation/widgets/order_status_badge.dart';
import '../../../orders/presentation/widgets/orders_palette.dart';

class ChefOrderCard extends StatelessWidget {
  const ChefOrderCard({
    super.key,
    required this.order,
    this.assignedChefName,
    this.onTap,
    this.onAccept,
    this.onReady,
    this.busy = false,
    this.historySummary = false,
  });
  final OrderModel order;
  final String? assignedChefName;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReady;
  final bool busy;
  final bool historySummary;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final created = order.createdAt.toLocal();
    final count = order.meals.fold<int>(0, (sum, item) => sum + item.quantity);
    final id = order.dispId;
    final displayId = id.isEmpty
        ? order.docId
        : id.startsWith('#')
        ? id
        : '#$id';
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
          padding: EdgeInsets.all(historySummary ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    displayId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  AppText(
                    'Table ${order.tableNo}',
                    style: const TextStyle(color: OrdersPalette.muted),
                  ),
                  Text(
                    '${localizations.formatMediumDate(created)} · '
                    '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(created))}',
                    style: const TextStyle(
                      color: OrdersPalette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (!historySummary && assignedChefName != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    const AppText(
                      'Assigned chef',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      assignedChefName!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: OrdersPalette.border),
              ),
              if (!historySummary)
                for (final item in order.meals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.mealName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '×${item.quantity}',
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  AppText(
                    '$count ${count == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: OrdersPalette.muted),
                  ),
                  if (historySummary)
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: OrdersPalette.muted,
                      size: 20,
                    )
                  else if (onAccept != null || onReady != null)
                    FilledButton(
                      onPressed: busy ? null : onAccept ?? onReady,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : AppText(
                              onAccept != null ? 'Accept Order' : 'Mark Ready',
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
