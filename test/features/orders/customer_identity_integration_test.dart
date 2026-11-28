import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goodfood_ecosystem/core/firebase/customer_identity_service.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:goodfood_ecosystem/features/orders/data/repositories/customer_orders_repository.dart';

class IdentityUser implements User {
  IdentityUser(this.uid, {this.isAnonymous = true});
  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IdentityCredential implements UserCredential {
  IdentityCredential(this.user);
  @override
  final User user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IdentityAuth implements FirebaseAuth {
  IdentityAuth([this.currentUser]);
  @override
  User? currentUser;
  int signIns = 0;
  final changes = StreamController<User?>.broadcast();
  void change(User? user) {
    currentUser = user;
    changes.add(user);
  }

  @override
  Stream<User?> authStateChanges() => Stream.multi((controller) {
    controller.add(currentUser);
    final sub = changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
  @override
  Future<UserCredential> signInAnonymously() async {
    signIns++;
    await Future<void>.delayed(Duration.zero);
    final user = IdentityUser('guest-$signIns');
    change(user);
    return IdentityCredential(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DisabledGuestAuth extends IdentityAuth {
  DisabledGuestAuth(this.code);

  final String code;

  @override
  Future<UserCredential> signInAnonymously() async {
    throw FirebaseAuthException(code: code);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'role': 'Customer'}));
  for (final code in ['operation-not-allowed', 'admin-restricted-operation']) {
    test('blocked guest sign-in ($code) creates no order', () async {
      final auth = DisabledGuestAuth(code);
      addTearDown(auth.changes.close);
      final store = FakeFirebaseFirestore();
      final creator = CustomerOrderCubit(
        store: store,
        auth: auth,
        secureCustomerFlow: true,
      );
      addTearDown(creator.close);

      await creator.placeOrder(
        [
          OrderItemModel(
            mealId: 'meal',
            mealName: 'Meal',
            mealImage: '',
            quantity: 1,
            unitPrice: 10,
          ),
        ],
        10,
        11,
        1,
      );

      expect(
        (creator.state as PlaceOrderFailState).msg,
        'Guest sign-in is unavailable. Please contact support.',
      );
      expect(creator.order, isNull);
      expect((await store.collection('orders').get()).docs, isEmpty);
    });
  }
  test(
    'guest initialization is shared across callers and existing staff session is reused',
    () async {
      final auth = IdentityAuth();
      addTearDown(auth.changes.close);
      final users = await Future.wait([
        CustomerIdentityService(auth).ensureSignedIn(),
        CustomerIdentityService(auth).ensureSignedIn(),
      ]);
      expect(users.map((u) => u.uid).toSet(), {'guest-1'});
      expect(auth.signIns, 1);
      auth.change(IdentityUser('chef', isAnonymous: false));
      expect(
        (await CustomerIdentityService(auth).ensureSignedIn()).uid,
        'chef',
      );
      expect(auth.signIns, 1);
    },
  );
  test('legacy ownership stays absent and owned documents roundtrip', () {
    final model = OrderModel(
      tableNo: 1,
      noOfGuests: 1,
      meals: [],
      subtotal: 0,
      serviceCharge: 0,
      total: 0,
      createdAt: DateTime.utc(2026),
    );
    expect(model.toMap().containsKey('customerId'), false);
    expect(OrderModel.fromMap(model.toMap(), []).customerId, null);
    expect(
      OrderModel.fromMap({
        ...model.toMap(),
        'customerId': 'real-uid',
      }, []).customerId,
      'real-uid',
    );
    expect(
      OrderModel.fromMap({
        ...model.toMap(),
        'created_at': null,
      }, []).createdAt.millisecondsSinceEpoch,
      0,
    );
  });
  test(
    'real creator attaches auth owner and customer query clears on logout and account switch',
    () async {
      final auth = IdentityAuth(IdentityUser('a')),
          store = FakeFirebaseFirestore();
      addTearDown(auth.changes.close);
      final creator = CustomerOrderCubit(
        store: store,
        auth: auth,
        secureCustomerFlow: true,
      );
      addTearDown(creator.close);
      creator.setCustomerDeyails(tableno: 7, noofguests: 2);
      await creator.placeOrder(
        [
          OrderItemModel(
            mealId: 'meal',
            mealName: 'Meal',
            mealImage: '',
            quantity: 2,
            unitPrice: 10,
          ),
        ],
        20,
        22,
        2,
      );
      expect(creator.state, isA<PlaceOrderSuccessState>());
      final id = creator.order!.docId;
      expect(
        (await store.collection('orders').doc(id).get()).data()!['customerId'],
        'a',
      );
      await creator.updatePayment(PaymentMethod.cash);
      expect(creator.state, isA<UpdatePaymentSuccessState>());
      final repo = CustomerOrdersRepository(store);
      final emissions = <List<OrderModel>>[];
      final sub = repo.watchCustomerOrders(auth).listen(emissions.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last.single.customerId, 'a');
      auth.change(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last, isEmpty);
      expect(creator.order, isNull);
      await store.collection('orders').doc(id).update({'status': 'ready'});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last, isEmpty);
      auth.change(IdentityUser('b'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last, isEmpty);
      auth.change(IdentityUser('a'));
      expect(
        (await repo
                .watchCustomerOrders(auth)
                .firstWhere((rows) => rows.isNotEmpty))
            .single
            .status,
        OrderStatus.ready,
      );
    },
  );
  for (final role in ['Customer', 'Stuff']) {
    test(
      'anonymous restoration with $role never reads a staff profile or signs out',
      () async {
        SharedPreferences.setMockInitialValues({'role': role});
        final auth = IdentityAuth(IdentityUser('guest'));
        addTearDown(auth.changes.close);
        final cubit = AuthCubit(
          auth: auth,
          store: FakeFirebaseFirestore(),
          secureCustomerFlow: true,
        );
        addTearDown(cubit.close);
        await cubit.navigateNext();
        expect(
          (cubit.state as AuthSplashSuccessState).route,
          role == 'Stuff' ? '/login' : '/welcome',
        );
        expect(auth.currentUser!.uid, 'guest');
        expect(auth.signIns, 0);
      },
    );
  }
  for (final role in ['Chef', 'Admin']) {
    test('existing active $role restores its staff route', () async {
      SharedPreferences.setMockInitialValues({'role': 'Stuff'});
      final auth = IdentityAuth(IdentityUser('staff', isAnonymous: false)),
          store = FakeFirebaseFirestore();
      addTearDown(auth.changes.close);
      await store.collection('users').doc('staff').set({
        'role': role,
        'status': 'Active',
        'name': 'Staff',
        'email': 'staff@local.test',
        'start_date': Timestamp.now(),
      });
      final cubit = AuthCubit(
        auth: auth,
        store: store,
        secureCustomerFlow: true,
      );
      addTearDown(cubit.close);
      await cubit.navigateNext();
      expect(
        (cubit.state as AuthSplashSuccessState).route,
        role == 'Chef' ? '/chef' : '/admin',
      );
      expect(auth.currentUser!.uid, 'staff');
      expect(auth.signIns, 0);
    });
  }
}
