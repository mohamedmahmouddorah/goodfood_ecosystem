import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/features/chef/data/repositories/chef_orders_source.dart';
import 'package:goodfood_ecosystem/features/chef/data/services/chef_identity_service.dart';
import 'package:goodfood_ecosystem/features/chef/presentation/view/chef_view.dart';
import 'package:goodfood_ecosystem/features/chef/presentation/view_model/chef_orders_cubit.dart';
import 'package:goodfood_ecosystem/features/chef/presentation/view_model/chef_orders_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';

OrderModel order(String id, OrderStatus status) => OrderModel(
  docId: id,
  dispId: id,
  tableNo: 5,
  noOfGuests: 2,
  meals: [
    OrderItemModel(
      mealId: 'meal',
      mealName: 'Actual meal field',
      mealImage: '',
      quantity: 2,
      unitPrice: 10,
    ),
  ],
  status: status,
  subtotal: 20,
  serviceCharge: 0,
  total: 20,
  createdAt: DateTime(2026, 11, 17),
);

// Test-only UI source. It is never used by the production /chef route.
class ChefFixtureSource implements ChefOrdersSource {
  final changes = StreamController<ChefOrderQueues>.broadcast();
  ChefOrderQueues current = ChefOrderQueues(
    chef: const ChefIdentity(uid: 'a', name: 'Chef A'),
    incoming: [order('NEW-1', OrderStatus.pending)],
    active: [],
    ready: [],
  );
  var accepted = 0;
  var ready = 0;
  var watches = 0;
  bool conflict = false;
  Completer<void>? hold;

  @override
  Stream<ChefOrderQueues> watch() => Stream.multi((controller) {
    watches++;
    controller.add(current);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> accept(String id) async {
    accepted++;
    await hold?.future;
    if (conflict) throw const ChefOrderConflict();
    final acceptedOrder = current.incoming.single
      ..status = OrderStatus.preparing;
    current = ChefOrderQueues(
      chef: current.chef,
      incoming: [],
      active: [acceptedOrder],
      ready: current.ready,
    );
    changes.add(current);
  }

  @override
  Future<void> markReady(String id) async {
    ready++;
    final readyOrder = current.active.single..status = OrderStatus.ready;
    current = ChefOrderQueues(
      chef: current.chef,
      incoming: [],
      active: [],
      ready: [readyOrder],
    );
    changes.add(current);
  }

  @override
  String? assignmentName(OrderModel order) =>
      order.status == OrderStatus.pending ? null : 'Chef A';
}

void main() {
  test(
    'identity uses Auth UID and rejects inactive, missing and non-chef profiles',
    () {
      final identity = ChefIdentityService.identityFromProfile(
        'real-auth-uid',
        {
          'uid': 'forged-local-uid',
          'name': 'Chef A',
          'role': 'Chef',
          'status': 'Active',
        },
      );
      expect(identity.uid, 'real-auth-uid');
      for (final profile in [
        null,
        {'name': 'A', 'role': 'Admin', 'status': 'Active'},
        {'name': 'A', 'role': 'Chef', 'status': 'Inactive'},
        {'name': ' ', 'role': 'Chef', 'status': 'Active'},
      ]) {
        expect(
          () => ChefIdentityService.identityFromProfile('a', profile),
          throwsA(isA<ChefAccessDenied>()),
        );
      }
    },
  );

  test(
    'duplicate taps are blocked and conflict reconnects exactly once',
    () async {
      final source = ChefFixtureSource()
        ..hold = Completer<void>()
        ..conflict = true;
      final cubit = ChefOrdersCubit(source);
      addTearDown(source.changes.close);
      addTearDown(cubit.close);
      cubit.load();
      await Future<void>.delayed(Duration.zero);
      final first = cubit.accept('NEW-1');
      await cubit.accept('NEW-1');
      expect(source.accepted, 1);
      expect(cubit.state.busyIds, contains('NEW-1'));
      source.hold!.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(source.watches, 2);
      expect(cubit.state.busyIds, isEmpty);
    },
  );

  test('loss of chef access clears previously visible orders', () async {
    final source = ChefFixtureSource();
    final cubit = ChefOrdersCubit(source);
    addTearDown(source.changes.close);
    addTearDown(cubit.close);
    cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.visibleOrders, hasLength(1));
    source.changes.addError(const ChefAccessDenied());
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, ChefOrdersStatus.denied);
    expect(cubit.state.visibleOrders, isEmpty);
  });

  for (final language in ['ar', 'en']) {
    for (final width in [320.0, 390.0, 1100.0]) {
      testWidgets('chef workflow UI $language fits $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = ChefFixtureSource();
        addTearDown(source.changes.close);
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
            home: ChefView(source: source),
          ),
        );
        await tester.pumpAndSettle();
        final accept = find.text(
          language == 'ar' ? 'قبول الطلب' : 'Accept Order',
        );
        await tester.ensureVisible(accept);
        await tester.tap(accept);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(language == 'ar' ? 'طلباتي الحالية' : 'My Active Orders'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chef A'), findsNWidgets(2));
        final markReady = find.text(
          language == 'ar' ? 'جاهز للتقديم' : 'Mark Ready',
        );
        await tester.ensureVisible(markReady);
        await tester.tap(markReady);
        await tester.pumpAndSettle();
        expect(source.accepted, 1);
        expect(source.ready, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
