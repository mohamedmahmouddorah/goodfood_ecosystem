import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/navigation/customer_orders_navigation.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view/customer_orders_screen.dart';
import 'package:goodfood_ecosystem/main_orders_preview.dart';

void main() {
  for (final id in <String?>[null, '', 'session-confirmed-document']) {
    testWidgets('orders route receives only the confirmed ID: $id', (
      tester,
    ) async {
      Object? received;
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/orders': (context) {
              received = ModalRoute.of(context)!.settings.arguments;
              return CustomerOrdersScreen(
                // The empty route must work without Firebase initialization.
                // Inject a stream for the non-empty case to avoid network access.
                orderIds: received! as List<String>,
                loadOrders: id == null || id.isEmpty
                    ? null
                    : () => Stream.value([]),
              );
            },
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    openCustomerOrders(context, confirmedOrderId: id),
                child: const Text('Open orders'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open orders'));
      await tester.pumpAndSettle();
      expect(received, id == null || id.isEmpty ? <String>[] : [id]);
      expect(find.text('No active orders'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open orders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('isolated preview labels sample data and renders both tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const OrdersPreviewApp());
    await tester.pumpAndSettle();
    expect(
      find.text('UI PREVIEW · Sample data only · No Firebase'),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsOneWidget);
    await tester.tap(find.text('Order History'));
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
