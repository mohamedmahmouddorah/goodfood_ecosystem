import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'features/customer_order_management/data/models/order_item_model.dart';
import 'features/customer_order_management/data/models/order_model.dart';
import 'features/orders/presentation/view/customer_orders_screen.dart';

/// Isolated UI preview: no Firebase initialization, reads, or writes.
/// Run: `flutter run -t lib/main_orders_preview.dart -d DEVICE_ID`
void main() {
  if (!kDebugMode) {
    throw UnsupportedError(
      'The orders preview is available in debug mode only.',
    );
  }
  runApp(const OrdersPreviewApp());
}

class OrdersPreviewApp extends StatelessWidget {
  const OrdersPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arimo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGold,
          brightness: Brightness.dark,
        ),
      ),
      home: Column(
        children: [
          Material(
            color: AppColors.primaryGold,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    'UI PREVIEW · Sample data only · No Firebase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.addChefText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomerOrdersScreen(
              loadOrders: () => Stream.value(_previewOrders()),
            ),
          ),
        ],
      ),
    );
  }
}

List<OrderModel> _previewOrders() {
  final now = DateTime.now();
  return [
    for (final (index, status) in OrderStatus.values.indexed)
      OrderModel(
        dispId: 'SAMPLE-${index + 1}',
        tableNo: index + 1,
        noOfGuests: 2,
        meals: [
          OrderItemModel(
            mealId: 'preview-meal',
            mealName: 'Sample meal',
            mealImage: '',
            quantity: 2,
            unitPrice: 12,
          ),
        ],
        status: status,
        subtotal: 24,
        serviceCharge: 0,
        total: 24,
        createdAt: now.subtract(Duration(hours: index)),
      ),
  ];
}
