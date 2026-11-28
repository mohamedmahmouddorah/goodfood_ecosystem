import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/cart_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/checkout_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/order_confirmed_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:hive/hive.dart';

import '../orders/customer_identity_integration_test.dart'
    show IdentityAuth, IdentityUser;

void main() {
  testWidgets('narrow checkout confirmation tracks the saved order ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = IdentityAuth(IdentityUser('customer'));
    final cubit = CustomerOrderCubit(
      store: FakeFirebaseFirestore(),
      auth: auth,
      secureCustomerFlow: true,
    );
    addTearDown(auth.changes.close);
    addTearDown(cubit.close);
    await tester.runAsync(
      () => cubit.placeOrder(
        [
          OrderItemModel(
            mealId: 'meal',
            mealName: 'Test meal',
            mealImage: '',
            quantity: 2,
            unitPrice: 10,
          ),
        ],
        20,
        22,
        2,
      ),
    );
    final savedId = cubit.order!.docId;
    Object? received;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const OrderConfirmedView(),
        ),
        routes: {
          '/orders': (context) {
            received = ModalRoute.of(context)?.settings.arguments;
            return const Scaffold(body: Text('Customer orders route'));
          },
        },
      ),
    );
    await tester.pumpAndSettle();
    final track = find.text('Track Your Order');
    await tester.ensureVisible(track);
    await tester.tap(track);
    await tester.pumpAndSettle();
    expect(received, [savedId]);
    expect(find.text('Customer orders route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ar']) {
    testWidgets('cart prices fit and follow quantity and removal ($language)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'Arimo',
        )..addFont(rootBundle.load('assets/fonts/Arimo-Regular.ttf'))).load();
        await (FontLoader('NotoSansArabic')..addFont(
              rootBundle.load(
                'assets/fonts/noto_sans_arabic/NotoSansArabic.ttf',
              ),
            ))
            .load();
      });
      final auth = IdentityAuth();
      final order = CustomerOrderCubit(
        store: FakeFirebaseFirestore(),
        auth: auth,
      );
      final cart = CartCubit(repo: CartRepo(cartBox: _CartBox()))
        ..loadCartData();
      addTearDown(auth.changes.close);
      addTearDown(order.close);
      addTearDown(cart.close);
      tester.view.physicalSize = const Size(430, 800);
      Widget app(Widget home) => MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GoodFoodLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: language == 'ar' ? 'NotoSansArabic' : 'Arimo',
          fontFamilyFallback: const ['Arimo'],
        ),
        home: home,
      );
      await tester.pumpWidget(
        app(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cart),
              BlocProvider.value(value: order),
            ],
            child: const CartView(),
          ),
        ),
      );
      Finder inFooter(Finder target) => find.descendant(
        of: find.byWidget(
          tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar!,
        ),
        matching: target,
      );
      void expectPrices(String subtotal, String tax, String total) {
        for (final amount in [subtotal, tax, total]) {
          expect(inFooter(find.text('\$$amount')), findsOneWidget);
        }
        expect(inFooter(find.textContaining(r'${cartCubit')), findsNothing);
      }

      void expectSummaryLayout(
        double width,
        String subtotal,
        String tax,
        String total,
      ) {
        expectPrices(subtotal, tax, total);
        final button = inFooter(find.byType(ElevatedButton));
        expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
        final label = inFooter(
          find.text(language == 'ar' ? 'المجموع الفرعي' : 'Subtotal'),
        );
        final price = inFooter(find.text('\$$subtotal'));
        final labelRect = tester.getRect(label);
        final priceRect = tester.getRect(price);
        if (language == 'ar') {
          expect(priceRect.right, lessThanOrEqualTo(labelRect.left));
        } else {
          expect(labelRect.right, lessThanOrEqualTo(priceRect.left));
        }
        expect(tester.takeException(), isNull, reason: 'viewport width $width');
      }

      for (final width in [320.0, 360.0, 390.0, 430.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pump();
        expectSummaryLayout(width, '25.00', '2.50', '27.50');
      }

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expectPrices('35.00', '3.50', '38.50');
      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pump();
      expectPrices('25.00', '2.50', '27.50');
      final trash = find.byIcon(Icons.delete_outline_rounded).last;
      expect(tester.widget<Icon>(trash).color, const Color(0xFFEF4444));
      final button = find.ancestor(
        of: trash,
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(button), const Size(48, 48));
      expect(
        tester.getTopLeft(button).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byIcon(Icons.add).last).dy,
        ),
      );
      if (language == 'ar') {
        expect(tester.getCenter(button).dx, lessThan(640));
      } else {
        expect(tester.getCenter(button).dx, greaterThan(640));
      }
      await tester.tap(trash);
      await tester.pump();
      expectPrices('20.00', '2.00', '22.00');
    });
  }

  testWidgets('cart creates an owned order and checkout selects payment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('Arimo')
        ..addFont(rootBundle.load('assets/fonts/Arimo-Regular.ttf'));
      await font.load();
    });
    final auth = _GuestAuth();
    final store = FakeFirebaseFirestore();
    final orders = CustomerOrderCubit(
      store: store,
      auth: auth,
      secureCustomerFlow: true,
    );
    final cart = CartCubit(repo: CartRepo(cartBox: _CartBox()))..loadCartData();
    addTearDown(auth.changes.close);
    addTearDown(orders.close);
    addTearDown(cart.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Arimo'),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cart),
            BlocProvider.value(value: orders),
          ],
          child: const CartView(),
        ),
      ),
    );
    final remove = find.byIcon(Icons.delete_outline_rounded).last;
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final snack = find.byType(SnackBar);
    expect(snack, findsOneWidget);
    expect(find.text('Another meal deleted successfully!'), findsOneWidget);
    expect(
      tester.getBottomLeft(snack).dy,
      lessThan(tester.getTopLeft(find.text('Subtotal')).dy),
    );
    final placeOrder = find.text('Place Order');
    await tester.ensureVisible(placeOrder);
    await tester.runAsync(() async {
      final failed = orders.stream
          .firstWhere((state) => state is PlaceOrderFailState)
          .timeout(const Duration(seconds: 5));
      await tester.tap(placeOrder);
      await failed;
    });
    await tester.pump();
    final error = find.byType(AppInlineFeedback);
    expect(error, findsOneWidget);
    expect(
      tester.getBottomLeft(error).dy,
      lessThan(tester.getTopLeft(placeOrder).dy),
    );
    expect(find.byType(SnackBar), findsNothing);
    auth.allowSignIn = true;
    await tester.runAsync(() async {
      final placed = orders.stream
          .firstWhere((state) => state is! PlaceOrderLoadingState)
          .timeout(const Duration(seconds: 5));
      await tester.tap(placeOrder);
      expect(await placed, isA<PlaceOrderSuccessState>());
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CheckoutView), findsOneWidget);
    expect(error, findsNothing);

    final continueToPayment = find.text('Continue to Payment');
    await tester.ensureVisible(continueToPayment);
    await tester.runAsync(() async {
      final payment = orders.stream
          .firstWhere((state) => state is! UpdatePaymentLoadingState)
          .timeout(const Duration(seconds: 5));
      await tester.tap(continueToPayment);
      expect(await payment, isA<UpdatePaymentSuccessState>());
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OrderConfirmedView), findsOneWidget);

    final data = (await tester.runAsync(
      () async => (await store.collection('orders').get()).docs.single.data(),
    ))!;
    expect(auth.signIns, 1);
    expect(data['customerId'], auth.currentUser!.uid);
    expect(data['status'], 'pending');
    expect(data['subtotal'], 20);
    expect(data['service_charge'], 2);
    expect(data['total'], 22);
    expect(data['payment_data']['payment_method'], 'cash');
  });
}

class _GuestAuth extends IdentityAuth {
  bool allowSignIn = false;

  @override
  Future<UserCredential> signInAnonymously() async {
    if (!allowSignIn) {
      throw FirebaseAuthException(code: 'operation-not-allowed');
    }
    return super.signInAnonymously();
  }
}

class _CartBox implements Box<OrderItemModel> {
  final items = [
    OrderItemModel(
      mealId: 'meal',
      mealName: 'Test meal',
      mealImage: '',
      quantity: 2,
      unitPrice: 10,
    ),
    OrderItemModel(
      mealId: 'another-meal',
      mealName: 'Another meal',
      mealImage: '',
      quantity: 1,
      unitPrice: 5,
    ),
  ];

  @override
  Iterable<OrderItemModel> get values => items;

  @override
  OrderItemModel? get(dynamic key, {OrderItemModel? defaultValue}) =>
      items.where((item) => item.mealId == key).firstOrNull ?? defaultValue;

  @override
  Future<void> put(dynamic key, OrderItemModel value) async {}

  @override
  Future<void> delete(dynamic key) async {
    items.removeWhere((item) => item.mealId == key);
  }

  @override
  Future<int> clear() async {
    final count = items.length;
    items.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
