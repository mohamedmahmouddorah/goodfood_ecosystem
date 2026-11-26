import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../customer_order_management/data/models/order_model.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      OrderStatus.pending => ('Pending', AppColors.goldLight, Icons.schedule),
      OrderStatus.preparing => (
        'Preparing',
        AppColors.primaryGold,
        Icons.soup_kitchen_outlined,
      ),
      OrderStatus.ready => (
        'Ready',
        AppColors.activeGreen,
        Icons.check_circle_outline,
      ),
      OrderStatus.delivered => (
        'Delivered',
        AppColors.activeGreen,
        Icons.done_all,
      ),
      OrderStatus.canceled => (
        'Cancelled',
        AppColors.inactiveRed,
        Icons.cancel_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: AppText(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
