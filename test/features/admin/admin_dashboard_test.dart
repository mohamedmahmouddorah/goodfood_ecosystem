import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/features/admin/data/admin_repository.dart';
import 'package:goodfood_ecosystem/features/admin/presentation/view/admin_view.dart';
import 'package:goodfood_ecosystem/features/chef_management/presentation/view/chef_management_screen.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/admin/presentation/view/admin_orders_view.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/menu_remote_service.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/menu_management_screen.dart';

class _AdminSource implements AdminDataSource {
  final auth = StreamController<String?>.broadcast();
  final profile = StreamController<String?>.broadcast();
  final orders = StreamController<List<OrderModel>>.broadcast();
  bool requestedTokenRefresh = false;

  @override
  Stream<String?> watchClaimedAdmin({bool refreshToken = false}) {
    requestedTokenRefresh = refreshToken;
    return auth.stream.map((uid) => uid);
  }

  @override
  Stream<String?> watchAdminName(String uid) => profile.stream;

  @override
  Stream<List<OrderModel>> watchOrders() => orders.stream;

  Future<void> close() async {
    await auth.close();
    await profile.close();
    await orders.close();
  }
}

class _MenuService extends Fake implements MenuRemoteService {
  @override
  Stream<RemoteMealsSnapshot> watchAll({
    MealCategory? category,
    bool includeHidden = false,
  }) => Stream.value(
    const RemoteMealsSnapshot(
      meals: [],
      isFromCache: false,
      hasPendingWrites: false,
    ),
  );
}

OrderModel _order(
  String id,
  int day,
  OrderStatus status, {
  String? chef,
  String? cancellationReason,
}) => OrderModel(
  docId: id,
  dispId: id,
  tableNo: 4,
  noOfGuests: 2,
  meals: [],
  status: status,
  subtotal: 20,
  serviceCharge: 2,
  total: 22,
  createdAt: DateTime(2026, 11, day),
  acceptedByChefId: chef,
  cancellationReason: cancellationReason,
);

Future<void> _mount(
  WidgetTester tester,
  _AdminSource source, {
  String language = 'en',
  Size size = const Size(1200, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(source.close);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: GoodFoodLocalizations.supportedLocales,
      localizationsDelegates: const [
        GoodFoodLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: AdminView(menu: MenuRepository(_MenuService()), repository: source),
    ),
  );
}

Future<void> _authorize(WidgetTester tester, _AdminSource source) async {
  source.auth.add('admin');
  await tester.pump();
  source.profile.add('Sam');
  await tester.pump();
}

void main() {
  testWidgets(
    'requires the claim and an active server profile before reading orders',
    (tester) async {
      final source = _AdminSource();
      await _mount(tester, source);
      source.auth.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Admin access required.'), findsOneWidget);
      expect(source.profile.hasListener, isFalse);
      expect(source.orders.hasListener, isFalse);
      await tester.tap(find.text('Refresh access'));
      await tester.pump();
      expect(source.requestedTokenRefresh, isTrue);
      source.auth.add('claimed-user');
      await tester.pump();
      await tester.pump();
      expect(source.profile.hasListener, isTrue);
      source.profile.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Admin access required.'), findsOneWidget);
      expect(source.orders.hasListener, isFalse);
    },
  );

  testWidgets('live metrics, filtering, details and revocation', (
    tester,
  ) async {
    final source = _AdminSource();
    await _mount(tester, source);
    await _authorize(tester, source);
    source.orders.add([
      _order('GF-101', 20, OrderStatus.pending),
      _order('GF-102', 21, OrderStatus.ready, chef: 'chef-a'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Sam'), findsOneWidget);
    expect(find.text('Total Orders'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    source.orders.add([
      _order('GF-101', 20, OrderStatus.delivered),
      _order('GF-102', 21, OrderStatus.ready, chef: 'chef-a'),
      _order(
        'GF-103',
        22,
        OrderStatus.canceled,
        cancellationReason: 'Changed my plans.',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Manage Orders'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('#GF-103')).dy,
      lessThan(tester.getTopLeft(find.text('#GF-102')).dy),
    );
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(AdminOrderCard, '#GF-103'),
        matching: find.text('View Details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancellation reason'), findsOneWidget);
    expect(find.text('Changed my plans.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' #gf-102 ');
    await tester.pumpAndSettle();
    expect(find.text('#GF-102'), findsOneWidget);
    expect(find.text('#GF-103'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Delivered'));
    await tester.pumpAndSettle();
    expect(find.text('No orders match your search or filter.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ready'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('Assigned chef · chef-a'), findsOneWidget);
    expect(find.text('Stored order totals'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);

    source.profile.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.text('Order Details'), findsNothing);
    expect(source.orders.hasListener, isFalse);
  });

  testWidgets('opens the existing menu and chef screens and returns', (
    tester,
  ) async {
    final source = _AdminSource();
    await _mount(tester, source);
    await _authorize(tester, source);
    source.orders.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No orders yet.'), findsOneWidget);
    await tester.tap(find.text('Manage Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuManagementScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Chefs'));
    await tester.pumpAndSettle();
    expect(find.byType(ChefManagementScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('GoodFood Admin Dashboard'), findsOneWidget);
  });

  testWidgets(
    'Arabic on a narrow phone handles a Firestore permission error and retry',
    (tester) async {
      final source = _AdminSource();
      await _mount(tester, source, language: 'ar', size: const Size(320, 740));
      await _authorize(tester, source);
      source.orders.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      final title = find.text('لوحة إدارة GoodFood');
      expect(title, findsOneWidget);
      expect(Directionality.of(tester.element(title)), TextDirection.rtl);
      expect(find.text('تعذّر تحميل الطلبات.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('إعادة المحاولة'));
        await Future<void>.delayed(Duration.zero);
        expect(source.orders.hasListener, isTrue);
        source.orders.add([_order('GF-102', 21, OrderStatus.pending)]);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('إجمالي الطلبات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
