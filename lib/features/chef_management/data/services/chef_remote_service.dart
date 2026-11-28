import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:goodfood_ecosystem/core/firebase/firebase_environment.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';

class ChefRemoteService {
  static final ChefRemoteService instance = ChefRemoteService._internal();
  ChefRemoteService._internal();

  final List<UserModel> _localChefs = [];
  final StreamController<List<UserModel>> _localController =
      StreamController<List<UserModel>>.broadcast();

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  CollectionReference<Map<String, dynamic>>? get _usersCollection =>
      isFirebaseReady ? FirebaseEnvironment.store.collection('users') : null;

  Stream<List<UserModel>> getChefsStream() {
    if (isFirebaseReady) {
      return _usersCollection!.where('role', isEqualTo: 'Chef').snapshots().map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data()..['uid'] = doc.id;
          return UserModel.fromMap(data);
        }).toList(),
      );
    }
    return Stream<List<UserModel>>.multi((controller) {
      controller.add(List<UserModel>.unmodifiable(_localChefs));
      final subscription = _localController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  /// Provisions the account through an isolated Firebase app so the admin's
  /// current session is never replaced by createUserWithEmailAndPassword.
  Future<void> addChef(UserModel chef, {required String password}) async {
    if (!isFirebaseReady) {
      _localChefs.insert(0, chef);
      _localController.add(List.unmodifiable(_localChefs));
      return;
    }
    final adminApp = FirebaseEnvironment.app;
    final secondaryAppName = 'chef-provision-${DateTime.now().microsecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    User? createdUser;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: adminApp.options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      if (FirebaseEnvironment.useEmulators) {
        await secondaryAuth.useAuthEmulator(FirebaseEnvironment.emulatorHost, 9099, automaticHostMapping: false);
      }
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: chef.email,
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) throw StateError('Firebase did not return the new chef account.');
      await FirebaseEnvironment.store.collection('users').doc(createdUser.uid).set({
        ...chef.toMap(),
        'uid': createdUser.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      try { await createdUser?.delete(); } catch (rollbackError) {
        debugPrint('Chef account rollback failed: $rollbackError');
      }
      rethrow;
    } finally {
      try { await secondaryApp?.delete(); } catch (error) {
        debugPrint('Secondary Firebase app cleanup failed: $error');
      }
    }
  }

  Future<void> updateChef(UserModel chef) async {
    final uid = chef.uid;
    if (uid == null || uid.isEmpty) return;
    if (isFirebaseReady) {
      await _usersCollection!.doc(uid).update(chef.toMap());
    } else {
      final index = _localChefs.indexWhere((c) => c.uid == uid);
      if (index != -1) { _localChefs[index] = chef; _localController.add(List.unmodifiable(_localChefs)); }
    }
  }

  Future<void> toggleStatus(String uid, AccountStatus status) async {
    if (isFirebaseReady) {
      await _usersCollection!.doc(uid).update({'status': status.name});
    } else {
      final index = _localChefs.indexWhere((c) => c.uid == uid);
      if (index != -1) { _localChefs[index] = _localChefs[index].copyWith(status: status); _localController.add(List.unmodifiable(_localChefs)); }
    }
  }

  Future<void> deleteChef(String uid) async {
    if (isFirebaseReady) {
      // Keep the Auth account but disable it in Firestore. Deleting Auth users
      // requires a trusted Admin SDK endpoint and must not be attempted by a client.
      await _usersCollection!.doc(uid).update({'status': AccountStatus.Inactive.name});
    } else {
      _localChefs.removeWhere((chef) => chef.uid == uid);
      _localController.add(List.unmodifiable(_localChefs));
    }
  }
}
