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
    final pendingOrder = current.incoming.firstWhere(
      (order) => order.docId == id,
    );
    final acceptedOrder = OrderModel.fromMap({
      ...pendingOrder.toMap(),
      'status': OrderStatus.preparing.name,
      'acceptedByChefId': current.chef.uid,
      'acceptedByChefName': current.chef.name,
    }, pendingOrder.meals)..docId = id;
    current = ChefOrderQueues(
      chef: current.chef,
      incoming: current.incoming.where((order) => order.docId != id).toList(),
      active: [acceptedOrder],
      ready: current.ready,
      history: current.history,
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
      history: [readyOrder, ...current.history],
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

  testWidgets(
    'history updates from the dashboard and opens read-only details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ChefFixtureSource();
      addTearDown(source.changes.close);
      await tester.pumpWidget(MaterialApp(home: ChefView(source: source)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Order History'));
      await tester.pumpAndSettle();
      expect(find.text('No order history yet'), findsOneWidget);

      await source.accept('NEW-1');
      await tester.pumpAndSettle();
      expect(find.text('#NEW-1'), findsNothing);
      await source.markReady('NEW-1');
      await tester.pumpAndSettle();
      expect(find.text('#NEW-1'), findsOneWidget);
      expect(find.text('Actual meal field'), findsNothing);
      expect(find.text('2 items'), findsOneWidget);
      await tester.tap(find.text('#NEW-1'));
      await tester.pumpAndSettle();
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Actual meal field'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(source.watches, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();

      source.changes.addError(const ChefAccessDenied());
      await tester.pumpAndSettle();
      expect(
        find.text('An active, signed-in chef account is required.'),
        findsOneWidget,
      );
      expect(find.text('#NEW-1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('details follows the selected order from pending to ready', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = ChefFixtureSource()..hold = Completer<void>();
    addTearDown(source.changes.close);
    final second = order('NEW-2', OrderStatus.pending);
    final secondOrder = OrderModel.fromMap({
      ...second.toMap(),
      'table_no': 9,
      'client_name': 'Second customer',
    }, second.meals)..docId = second.docId;
    source.current = ChefOrderQueues(
      chef: source.current.chef,
      incoming: [...source.current.incoming, secondOrder],
      active: [],
      ready: [],
    );
    await tester.pumpWidget(MaterialApp(home: ChefView(source: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#NEW-1'));
    await tester.pumpAndSettle();
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('Table 5'), findsOneWidget);
    expect(find.text('Second customer'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final secondCard = find.text('#NEW-2');
    await tester.scrollUntilVisible(
      secondCard,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(secondCard);
    await tester.pumpAndSettle();
    expect(find.text('Table 9'), findsOneWidget);
    expect(find.text('Second customer'), findsOneWidget);
    expect(find.text('Actual meal field'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);

    await tester.tap(find.text('Accept Order'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    source.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Assigned chef'), findsOneWidget);
    expect(find.text('Chef A'), findsOneWidget);
    await tester.tap(find.text('Mark Ready'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(source.watches, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details removes actions when the order leaves the chef queues', (
    tester,
  ) async {
    final source = ChefFixtureSource();
    addTearDown(source.changes.close);
    await tester.pumpWidget(MaterialApp(home: ChefView(source: source)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#NEW-1'));
    await tester.pumpAndSettle();
    expect(find.text('Accept Order'), findsOneWidget);

    // Both cancellation and acceptance by another chef remove the order
    // from the current chef's queues.
    source.changes.add(
      ChefOrderQueues(
        chef: source.current.chef,
        incoming: [],
        active: [],
        ready: [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This order is no longer available.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(source.accepted, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chef Dashboard'), findsOneWidget);
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
        expect(find.byType(BackButton), findsNothing);
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
        expect(find.byType(BackButton), findsNothing);
        expect(source.accepted, 1);
        expect(source.ready, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
