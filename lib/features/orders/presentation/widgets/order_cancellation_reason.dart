import 'package:flutter/material.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import 'orders_palette.dart';

class OrderCancellationReason extends StatelessWidget {
  const OrderCancellationReason({super.key, required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final savedReason = reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Cancellation Reason',
          style: TextStyle(color: OrdersPalette.muted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          savedReason != null && savedReason.trim().isNotEmpty
              ? savedReason
              : context.tr('No reason provided'),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
