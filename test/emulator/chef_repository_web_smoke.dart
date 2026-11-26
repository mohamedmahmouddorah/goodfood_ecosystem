import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/core/firebase/firebase_environment.dart';
import 'package:goodfood_ecosystem/features/chef/data/repositories/chef_orders_repository.dart';
import 'package:goodfood_ecosystem/features/chef/data/repositories/chef_orders_source.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/orders/data/repositories/customer_orders_repository.dart';

// Explicit local smoke target, never imported by lib/main.dart.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb ||
      !kDebugMode ||
      !FirebaseEnvironment.useEmulators ||
      FirebaseEnvironment.emulatorHost != '127.0.0.1') {
    throw StateError(
      'This smoke target runs only against the local demo emulators.',
    );
  }
  final results = <String, Object>{};
  try {
    await FirebaseEnvironment.initialize();
    final appB = await Firebase.initializeApp(
      name: 'chef-b-smoke',
      options: FirebaseEnvironment.app.options,
    );
    final storeA = FirebaseEnvironment.store;
    final storeB = FirebaseFirestore.instanceFor(app: appB);
    storeB.useFirestoreEmulator('127.0.0.1', 8787);
    storeB.settings = const Settings(persistenceEnabled: false);
    final authA = FirebaseEnvironment.auth,
        authB = FirebaseAuth.instanceFor(app: appB);
    await authB.useAuthEmulator('127.0.0.1', 9099);
    await authA.signInWithEmailAndPassword(
      email: 'chef-a@local.test',
      password: 'ChefLocal123!',
    );
    await authB.signInWithEmailAndPassword(
      email: 'chef-b@local.test',
      password: 'ChefLocal123!',
    );
    final a = ChefOrdersRepository(store: storeA, auth: authA);
    final b = ChefOrdersRepository(store: storeB, auth: authB);
    Future<ChefOrderQueues> queue(
      ChefOrdersRepository repo,
      bool Function(ChefOrderQueues) predicate,
    ) =>
        repo.watch().firstWhere(predicate).timeout(const Duration(seconds: 15));
    final before = await Future.wait([
      queue(a, (q) => q.incoming.any((order) => order.docId == 'workflow')),
      queue(b, (q) => q.incoming.any((order) => order.docId == 'workflow')),
    ]);
    results['sharedQueue'] = before.every(
      (q) => q.incoming.any((order) => order.docId == 'workflow'),
    );
    final removed = queue(
      b,
      (q) => q.incoming.every((order) => order.docId != 'workflow'),
    );
    await a.accept('workflow');
    await removed;
    final accepted = (await queue(
      a,
      (q) => q.active.any((order) => order.docId == 'workflow'),
    )).active.firstWhere((order) => order.docId == 'workflow');
    results['authenticatedUid'] =
        accepted.acceptedByChefId == authA.currentUser!.uid;
    results['nameSnapshot'] = accepted.acceptedByChefName == 'Chef A';
    results['serverAcceptedAt'] = accepted.acceptedAt != null;
    var competitorBlocked = false;
    try {
      await b.accept('workflow');
    } catch (_) {
      competitorBlocked = true;
    }
    results['competitorCannotAccept'] = competitorBlocked;
    var readyBlocked = false;
    try {
      await b.markReady('workflow');
    } catch (_) {
      readyBlocked = true;
    }
    results['otherChefCannotMarkReady'] = readyBlocked;
    // Reuse the actual Customer Orders parser/listener with an authorized owner
    // credential. This does not assert guest customer read permissions.
    final customerReady = CustomerOrdersRepository(storeA)
        .watchOrders(['workflow'])
        .firstWhere((orders) => orders.single.status == OrderStatus.ready)
        .timeout(const Duration(seconds: 15));
    await a.markReady('workflow');
    final ready = (await customerReady).single;
    results['customerRepositoryReceivesReady'] =
        ready.readyAt != null &&
        ready.acceptedByChefId == authA.currentUser!.uid;
    final reopened = ChefOrdersRepository(store: storeA, auth: authA);
    results['reopenedAssignment'] =
        (await queue(
          reopened,
          (q) => q.ready.any((order) => order.docId == 'workflow'),
        )).ready.any(
          (order) =>
              order.docId == 'workflow' && order.acceptedByChefName == 'Chef A',
        );
    Future<bool> claim(ChefOrdersRepository repo) async {
      try {
        await repo.accept('concurrency');
        return true;
      } catch (_) {
        return false;
      }
    }

    final race = await Future.wait([claim(a), claim(b)]);
    results['exactlyOneConcurrentWinner'] =
        race.where((won) => won).length == 1;
    if (results.values.any((value) => value != true)) {
      throw StateError('A smoke assertion failed.');
    }
    results['passed'] = true;
  } catch (error) {
    results['passed'] = false;
    results['error'] = error.toString();
  }
  final report = jsonEncode(results);
  debugPrint('CHEF_EMULATOR_RESULT:$report');
  runApp(
    MaterialApp(
      home: Scaffold(body: SafeArea(child: SelectableText(report))),
    ),
  );
}
