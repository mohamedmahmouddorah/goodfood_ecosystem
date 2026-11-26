import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view/customer_orders_screen.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/widgets/order_card.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final width in [320.0, 390.0, 760.0]) {
      testWidgets(
        'reference layout $language at $width supports photos and larger text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final order = OrderModel(
            dispId: 'GF-123456',
            tableNo: 5,
            noOfGuests: 2,
            meals: [
              for (var index = 0; index < 3; index++)
                OrderItemModel(
                  mealId: '$index',
                  mealName: 'Meal $index',
                  mealImage: '',
                  quantity: 1,
                  unitPrice: 10,
                ),
            ],
            subtotal: 30,
            serviceCharge: 0,
            total: 30,
            createdAt: DateTime(2026, 11, 17, 12, 45),
            status: OrderStatus.preparing,
          );
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: GoodFoodLocalizations.supportedLocales,
              localizationsDelegates: const [
                GoodFoodLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: CustomerOrdersScreen(
                loadOrders: () => Stream.value([order]),
                onOrderTap: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(OrderCard), findsOneWidget);
          expect(find.byType(Tooltip), findsAtLeastNWidgets(3));
          await tester.scrollUntilVisible(
            find.text('\$30.00'),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.text(language == 'ar' ? '3 أصناف' : '3 items'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
