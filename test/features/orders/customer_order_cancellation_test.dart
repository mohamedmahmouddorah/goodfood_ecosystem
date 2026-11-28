import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/widgets/order_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/orders/data/repositories/customer_orders_repository.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view/customer_orders_screen.dart';

import 'customer_identity_integration_test.dart'
    show IdentityAuth, IdentityUser;
import 'customer_orders_test.dart' as fixtures;

void main() {
  test('repository checks the current owner, status and assignment', () async {
    final store = FakeFirebaseFirestore();
    final auth = IdentityAuth(IdentityUser('customer'));
    addTearDown(auth.changes.close);
    final repository = CustomerOrdersRepository(store);
    final ref = store.collection('orders').doc('order');
    final original = {
      'customerId': 'customer',
      'status': 'pending',
      'total': 22,
    };
    final rejected = throwsA(isA<OrderCancellationException>());

    for (final data in [
      {...original, 'customerId': 'other'},
      {...original, 'customerId': null},
      {...original, 'status': 'preparing'},
      {...original, 'acceptedByChefId': 'chef'},
      {...original, 'acceptedByChefName': 'Chef'},
      {...original, 'acceptedAt': Timestamp.fromMillisecondsSinceEpoch(1)},
      {...original, 'readyAt': Timestamp.fromMillisecondsSinceEpoch(1)},
    ]) {
      await ref.set(data);
      await expectLater(repository.cancelOrder(ref.id, auth), rejected);
      expect((await ref.get()).data(), data);
    }

    await ref.set(original);
    await repository.cancelOrder(ref.id, auth, reason: '   ');
    expect((await ref.get()).data(), {...original, 'status': 'canceled'});
    await expectLater(repository.cancelOrder(ref.id, auth), rejected);
    await ref.set(original);
    await expectLater(
      repository.cancelOrder(ref.id, auth, reason: 'x' * 201),
      rejected,
    );
    await repository.cancelOrder(ref.id, auth, reason: '  Changed my plans.  ');
    expect((await ref.get()).data(), {
      ...original,
      'status': 'canceled',
      'cancellationReason': 'Changed my plans.',
    });
  });

  testWidgets(
    'details hides cancellation on live assignment and status changes',
    (tester) async {
      final orders = StreamController<List<OrderModel>>();
      final auth = IdentityAuth(IdentityUser('customer'));
      addTearDown(orders.close);
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrdersScreen(
            loadOrders: () => orders.stream,
            watchCustomerId: () =>
                auth.authStateChanges().map((user) => user?.uid),
            cancelOrder: (_, {reason}) async => fail('Unexpected cancellation'),
          ),
        ),
      );
      final pending = fixtures.order('GF-TEST', OrderStatus.pending, 1);
      OrderModel update({
        OrderStatus status = OrderStatus.pending,
        String? customerId = 'customer',
        Map<String, Object> assignment = const {},
      }) => OrderModel.fromMap({
        ...pending.toMap(),
        'status': status.name,
        'customerId': customerId,
        if (status != OrderStatus.canceled)
          'cancellationReason': 'Stale reason from an older record.',
        ...assignment,
      }, pending.meals)..docId = pending.docId;
      orders.add([update()]);
      await tester.pumpAndSettle();
      final cancel = find.byTooltip('Cancel Order');
      expect(cancel, findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      final button = find
          .ancestor(of: cancel, matching: find.byType(IconButton))
          .first;
      expect(tester.getSize(button), const Size(48, 48));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded)).color,
        const Color(0xFFEF4444),
      );
      expect(
        tester.getCenter(cancel).dx,
        greaterThan(tester.getCenter(find.byType(OrderCard)).dx),
      );
      expect(
        tester.getTopLeft(cancel).dy,
        greaterThan(tester.getBottomLeft(find.text('#GF-TEST')).dy),
      );
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('Cancel Order?'), findsOneWidget);
      expect(find.text('Order Details'), findsNothing);
      expect(find.text('#GF-TEST'), findsNWidgets(2));
      await tester.tap(find.text('Keep Order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#GF-TEST'));
      await tester.pumpAndSettle();
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Cancellation Reason'), findsNothing);
      expect(find.text('Stale reason from an older record.'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      auth.change(null);
      await tester.pumpAndSettle();
      expect(cancel, findsNothing);
      auth.change(IdentityUser('other'));
      await tester.pumpAndSettle();
      expect(cancel, findsNothing);
      auth.change(IdentityUser('customer'));
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);

      for (final order in [
        update(assignment: {'acceptedByChefId': 'chef'}),
        update(assignment: {'acceptedByChefName': 'Chef'}),
        update(
          assignment: {'acceptedAt': Timestamp.fromMillisecondsSinceEpoch(1)},
        ),
        update(
          assignment: {'readyAt': Timestamp.fromMillisecondsSinceEpoch(1)},
        ),
        update(customerId: 'other'),
        update(customerId: null),
        for (final status in OrderStatus.values.skip(1)) update(status: status),
      ]) {
        orders.add([order]);
        await tester.pumpAndSettle();
        expect(cancel, findsNothing);
        expect(find.text('Stale reason from an older record.'), findsNothing);
      }
      expect(find.text('No active orders'), findsOneWidget);
      await tester.tap(find.text('Order History'));
      await tester.pumpAndSettle();
      expect(find.text('#GF-TEST'), findsOneWidget);
      expect(find.text('No reason provided'), findsOneWidget);
    },
  );

  testWidgets('confirmation submits once, shows progress and reports success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final orders = StreamController<List<OrderModel>>();
    addTearDown(orders.close);
    final result = Completer<void>();
    var calls = 0;
    final pending = fixtures.order('GF-TEST', OrderStatus.pending, 1);
    final owned = OrderModel.fromMap({
      ...pending.toMap(),
      'customerId': 'customer',
    }, pending.meals)..docId = pending.docId;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerOrdersScreen(
          loadOrders: () => orders.stream,
          watchCustomerId: () => Stream.value('customer'),
          cancelOrder: (id, {reason}) {
            expect(id, pending.docId);
            expect(reason, 'Changed my plans.');
            calls++;
            return result.future;
          },
        ),
      ),
    );
    orders.add([owned]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel Order'));
    await tester.pumpAndSettle();
    final reasonField = find.byType(TextField);
    expect(tester.widget<TextField>(reasonField).maxLength, 200);
    await tester.enterText(reasonField, '  Changed my plans.  ');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Yes, Cancel Order');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel Order?'), findsOneWidget);
    final canceled = OrderModel.fromMap({
      ...owned.toMap(),
      'status': 'canceled',
      'cancellationReason': 'Changed my plans.',
    }, owned.meals)..docId = owned.docId;
    orders.add([canceled]);
    result.complete();
    await tester.pumpAndSettle();
    expect(find.text('Order cancelled successfully'), findsOneWidget);
    expect(find.text('Order Details'), findsNothing);
    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('Cancel Order?'), findsNothing);
    expect(find.byTooltip('Cancel Order'), findsNothing);
    tester.view.resetViewInsets();
    await tester.tap(find.text('Order History'));
    await tester.pumpAndSettle();
    expect(find.text('#GF-TEST'), findsOneWidget);
    expect(find.text('Cancellation Reason'), findsOneWidget);
    expect(find.text('Changed my plans.'), findsOneWidget);
    await tester.tap(find.text('#GF-TEST'));
    await tester.pumpAndSettle();
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('Changed my plans.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected cancellation keeps the sheet open with the error', (
    tester,
  ) async {
    final pending = fixtures.order('GF-TEST', OrderStatus.pending, 1);
    final owned = OrderModel.fromMap({
      ...pending.toMap(),
      'customerId': 'customer',
    }, pending.meals)..docId = pending.docId;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerOrdersScreen(
          loadOrders: () => Stream.value([owned]),
          watchCustomerId: () => Stream.value('customer'),
          cancelOrder: (id, {reason}) async {
            expect(reason, isEmpty);
            throw const OrderCancellationException(
              'This order has already been accepted or is no longer pending.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Cancel Order'));
    await tester.tap(find.byTooltip('Cancel Order'));
    await tester.pumpAndSettle();
    final confirm = find.text('Yes, Cancel Order');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Cancel Order?'), findsOneWidget);
    expect(
      find.text(
        'This order has already been accepted or is no longer pending.',
      ),
      findsOneWidget,
    );
    expect(find.text('Order cancelled successfully'), findsNothing);
  });

  testWidgets('Arabic mirrors the card action and supports an empty reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = fixtures.order('GF-TEST', OrderStatus.pending, 1);
    final owned = OrderModel.fromMap({
      ...pending.toMap(),
      'customerId': 'customer',
    }, pending.meals)..docId = pending.docId;
    final orders = StreamController<List<OrderModel>>();
    addTearDown(orders.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: GoodFoodLocalizations.supportedLocales,
        localizationsDelegates: const [
          GoodFoodLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: CustomerOrdersScreen(
          loadOrders: () => orders.stream,
          watchCustomerId: () => Stream.value('customer'),
          cancelOrder: (id, {reason}) async {
            expect(reason, isEmpty);
            orders.add([
              OrderModel.fromMap({
                ...owned.toMap(),
                'status': 'canceled',
              }, owned.meals)..docId = id,
            ]);
          },
        ),
      ),
    );
    orders.add([owned]);
    await tester.pumpAndSettle();
    final trash = find.byTooltip('إلغاء الطلب');
    expect(
      tester.getCenter(trash).dx,
      lessThan(tester.getCenter(find.byType(OrderCard)).dx),
    );
    await tester.ensureVisible(trash);
    await tester.pumpAndSettle();
    await tester.tap(trash);
    await tester.pumpAndSettle();
    expect(find.text('إلغاء الطلب؟'), findsOneWidget);
    expect(
      find.text('هل أنت متأكد من إلغاء الطلب؟ لا يمكن التراجع عن الإلغاء.'),
      findsOneWidget,
    );
    expect(find.text('الاحتفاظ بالطلب'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.labelText, 'سبب إلغاء الطلب (اختياري)');
    expect(field.decoration!.hintText, 'اكتب سبب الإلغاء لو حابب...');
    final confirm = find.text('تأكيد إلغاء الطلب');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('تم إلغاء الطلب بنجاح'), findsOneWidget);
    expect(find.text('تفاصيل الطلب'), findsNothing);
    final context = tester.element(find.byType(CustomerOrdersScreen));
    await tester.tap(find.text(context.tr('Order History')));
    await tester.pumpAndSettle();
    expect(find.text('سبب الإلغاء'), findsOneWidget);
    expect(find.text('لم يتم تحديد سبب'), findsOneWidget);
    final longReason = List.filled(7, 'تغيّر موعد الزيارة.').join(' ');
    orders.add([
      OrderModel.fromMap({
        ...owned.toMap(),
        'status': 'canceled',
        'cancellationReason': longReason,
      }, owned.meals)..docId = owned.docId,
    ]);
    await tester.pumpAndSettle();
    expect(find.text(longReason), findsOneWidget);
    await tester.tap(find.text('#GF-TEST'));
    await tester.pumpAndSettle();
    expect(find.text(longReason), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
