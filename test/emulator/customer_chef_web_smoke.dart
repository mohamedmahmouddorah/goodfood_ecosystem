import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goodfood_ecosystem/core/firebase/customer_identity_service.dart';
import 'package:goodfood_ecosystem/core/firebase/firebase_environment.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:goodfood_ecosystem/features/chef/data/repositories/chef_orders_repository.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:goodfood_ecosystem/features/orders/data/repositories/customer_orders_repository.dart';

// Explicit local test target. No production imports reference this entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb ||
      !kDebugMode ||
      !FirebaseEnvironment.useEmulators ||
      FirebaseEnvironment.emulatorHost != '127.0.0.1') {
    throw StateError('Local demo emulators only.');
  }
  final results = <String, dynamic>{};
  try {
    await FirebaseEnvironment.initialize();
    final auth = FirebaseEnvironment.auth, store = FirebaseEnvironment.store;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('customer-chef-smoke-resume');
    if (saved != null) {
      final previous = jsonDecode(saved) as Map<String, dynamic>;
      results.addAll(previous['results'] as Map<String, dynamic>);
      final restored = await auth.authStateChanges().first;
      check(
        results,
        'realPageReloadRestoresSameUid',
        restored?.uid == previous['uid'],
      );
      await prefs.setString('role', 'Customer');
      final splash = AuthCubit(secureCustomerFlow: true);
      await splash.navigateNext();
      check(
        results,
        'anonymousSplashPreservesSession',
        splash.state is AuthSplashSuccessState &&
            (splash.state as AuthSplashSuccessState).route == '/welcome' &&
            auth.currentUser?.uid == previous['uid'],
      );
      await splash.close();
      final repo = CustomerOrdersRepository(store);
      final rows = await repo
          .watchCustomerOrders(auth)
          .firstWhere((rows) => rows.any((o) => o.docId == previous['id']));
      check(
        results,
        'reloadRestoresOwnedReadyOrder',
        rows.firstWhere((o) => o.docId == previous['id']).status ==
            OrderStatus.ready,
      );
      final cleared = Completer<void>();
      var loggedOut = false;
      final sub = repo.watchCustomerOrders(auth).listen((rows) {
        if (loggedOut && rows.isEmpty && !cleared.isCompleted) {
          cleared.complete();
        }
      });
      loggedOut = true;
      await auth.signOut();
      await cleared.future.timeout(const Duration(seconds: 15));
      await sub.cancel();
      check(results, 'logoutClearsCustomerRows', true);
      final other = await CustomerIdentityService(auth).ensureSignedIn();
      check(results, 'newIdentityIsDistinct', other.uid != previous['uid']);
      final otherRows = await repo.watchCustomerOrders(auth).first;
      check(results, 'newCustomerCannotListOldOrders', otherRows.isEmpty);
      await denied(
        () => store.collection('orders').doc(previous['id'] as String).get(),
      );
      check(results, 'newCustomerCannotReadKnownId', true);
      await prefs.remove('customer-chef-smoke-resume');
      results['passed'] = true;
    } else {
      final a = await chef('customer-workflow-a', 'chef-a@local.test');
      final b = await chef('customer-workflow-b', 'chef-b@local.test');
      final creator = CustomerOrderCubit(secureCustomerFlow: true);
      creator.setCustomerDeyails(
        tableno: 7,
        noofguests: 2,
        custName: 'Local guest',
      );
      await creator.placeOrder(
        [
          OrderItemModel(
            mealId: 'chef-emulator-meal',
            mealName: 'Emulator Test Meal',
            mealImage: '',
            quantity: 2,
            unitPrice: 10,
          ),
        ],
        20,
        22,
        2,
      );
      check(
        results,
        'actualCustomerCubitCreatesOrder',
        creator.state is PlaceOrderSuccessState,
      );
      final customer = auth.currentUser!;
      check(results, 'customerIsAnonymous', customer.isAnonymous);
      check(
        results,
        'threeIndependentIdentities',
        {
              customer.uid,
              a.auth.currentUser!.uid,
              b.auth.currentUser!.uid,
            }.length ==
            3,
      );
      final id = creator.order!.docId;
      final data = (await store.collection('orders').doc(id).get()).data()!;
      check(
        results,
        'realOwnerAndServerCreationTime',
        data['customerId'] == customer.uid && data['created_at'] is Timestamp,
      );
      final customerOrders = CustomerOrdersRepository(store);
      final myOrders = await customerOrders
          .watchCustomerOrders(auth)
          .firstWhere((rows) => rows.any((order) => order.docId == id))
          .timeout(const Duration(seconds: 15));
      final pending = myOrders.firstWhere((order) => order.docId == id);
      check(
        results,
        'newOrderAppearsInMyOrdersAsPendingAndUnassigned',
        pending.status == OrderStatus.pending && pending.isUnassigned,
      );
      for (final repo in [a.repo, b.repo]) {
        await repo
            .watch()
            .firstWhere((q) => q.incoming.any((o) => o.docId == id))
            .timeout(const Duration(seconds: 15));
      }
      check(results, 'bothChefsSeeCustomerOrder', true);
      final preparing = CustomerOrdersRepository(store)
          .watchCustomerOrders(auth)
          .firstWhere(
            (rows) => rows.any(
              (o) => o.docId == id && o.status == OrderStatus.preparing,
            ),
          )
          .timeout(const Duration(seconds: 15));
      await a.repo.accept(id);
      await preparing;
      await b.repo
          .watch()
          .firstWhere((q) => q.incoming.every((o) => o.docId != id))
          .timeout(const Duration(seconds: 15));
      await denied(() => b.repo.accept(id));
      await denied(() => b.repo.markReady(id));
      await denied(
        () => store.collection('orders').doc(id).update({
          'status': 'ready',
          'readyAt': FieldValue.serverTimestamp(),
        }),
      );
      check(results, 'loserAndCustomerCannotAdvance', true);
      // Preserve the original create-then-payment workflow even after acceptance.
      await creator.updatePayment(PaymentMethod.cash);
      check(
        results,
        'oneTimePaymentSelectionAfterAcceptance',
        creator.state is UpdatePaymentSuccessState,
      );
      await denied(
        () => store.collection('orders').doc(id).update({
          'payment_data': {
            'payment_method': 'card',
            'payment_date': FieldValue.serverTimestamp(),
          },
        }),
      );
      check(results, 'secondPaymentSelectionDenied', true);
      final ready = CustomerOrdersRepository(store)
          .watchCustomerOrders(auth)
          .firstWhere(
            (rows) => rows.any(
              (o) =>
                  o.docId == id &&
                  o.status == OrderStatus.ready &&
                  o.readyAt != null,
            ),
          )
          .timeout(const Duration(seconds: 15));
      await a.repo.markReady(id);
      final finalOrder = (await ready).firstWhere((o) => o.docId == id);
      check(
        results,
        'realCustomerReceivesReady',
        finalOrder.customerId == customer.uid &&
            finalOrder.acceptedByChefId == a.auth.currentUser!.uid &&
            finalOrder.acceptedByChefName == 'Chef A',
      );
      creator.resetForNewOrder();
      creator.setCustomerDeyails(tableno: 7, noofguests: 1);
      await creator.placeOrder(
        [
          OrderItemModel(
            mealId: 'chef-emulator-meal',
            mealName: 'Emulator Test Meal',
            mealImage: '',
            quantity: 1,
            unitPrice: 10,
          ),
        ],
        10,
        11,
        1,
      );
      check(
        results,
        'secondActualOrderCreated',
        creator.state is PlaceOrderSuccessState,
      );
      final raceId = creator.order!.docId;
      Future<bool> claim(ChefOrdersRepository repo) async {
        try {
          await repo.accept(raceId);
          return true;
        } catch (_) {
          return false;
        }
      }

      final race = await Future.wait([claim(a.repo), claim(b.repo)]);
      check(
        results,
        'realDartTransactionsExactlyOneWinner',
        race.where((won) => won).length == 1,
      );
      await creator.close();
      await prefs.setString(
        'customer-chef-smoke-resume',
        jsonEncode({'uid': customer.uid, 'id': id, 'results': results}),
      );
      results['needsReload'] = true;
    }
  } catch (error, stack) {
    results['passed'] = false;
    results['error'] = error.toString();
    debugPrintStack(stackTrace: stack);
  }
  final report = jsonEncode(results);
  debugPrint('CUSTOMER_CHEF_RESULT:$report');
  runApp(
    MaterialApp(
      home: Scaffold(body: SafeArea(child: SelectableText(report))),
    ),
  );
}

void check(Map<String, dynamic> results, String key, bool valid) {
  if (!valid) throw StateError(key);
  results[key] = true;
}

Future<void> denied(Future<dynamic> Function() action) async {
  try {
    await action();
  } catch (_) {
    return;
  }
  throw StateError('Unauthorized action unexpectedly succeeded.');
}

Future<({ChefOrdersRepository repo, FirebaseAuth auth})> chef(
  String name,
  String email,
) async {
  final app = await Firebase.initializeApp(
    name: name,
    options: FirebaseEnvironment.app.options,
  );
  final auth = FirebaseAuth.instanceFor(app: app),
      store = FirebaseFirestore.instanceFor(app: app);
  await auth.useAuthEmulator('127.0.0.1', 9099);
  store.useFirestoreEmulator('127.0.0.1', 8787);
  store.settings = const Settings(persistenceEnabled: false);
  await auth.signInWithEmailAndPassword(
    email: email,
    password: 'ChefLocal123!',
  );
  return (repo: ChefOrdersRepository(store: store, auth: auth), auth: auth);
}
