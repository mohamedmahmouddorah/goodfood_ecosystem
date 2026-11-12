import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';


class ChefRemoteService {
  static final ChefRemoteService instance = ChefRemoteService._internal();
  ChefRemoteService._internal();

  final List<UserModel> _localChefs = [];
  final StreamController<List<UserModel>> _localController =
      StreamController<List<UserModel>>.broadcast();

  bool get isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _chefsCollection {
    if (!isFirebaseReady) return null;
    return FirebaseFirestore.instance.collection('chefs');
  }

  /// Stream of chefs from Firebase Firestore (with fallback to local memory)
  Stream<List<UserModel>> getChefsStream() {
    if (isFirebaseReady) {
      return _chefsCollection!.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return UserModel.fromMap(data);
        }).toList();
      });
    }

    return Stream<List<UserModel>>.multi((controller) {
      controller.add(List<UserModel>.unmodifiable(_localChefs));
      final subscription = _localController.stream.listen(
        (data) => controller.add(List<UserModel>.unmodifiable(data)),
      );
      controller.onCancel = () => subscription.cancel();
    });
  }

  Future<void> addChef(UserModel chef) async {
    if (isFirebaseReady) {
      final docRef = await _chefsCollection!.add(chef.toMap());
      chef.uid = docRef.id;
    } else {
      _localChefs.insert(0, chef);
      _localController.add(_localChefs);
    }
  }

  Future<void> updateChef(UserModel chef) async {
    final uid = chef.uid;
    if (uid == null || uid.isEmpty) return;

    if (isFirebaseReady) {
      await _chefsCollection!.doc(uid).update(chef.toMap());
    } else {
      final index = _localChefs.indexWhere((c) => c.uid == uid);
      if (index != -1) {
        _localChefs[index] = chef;
        _localController.add(_localChefs);
      }
    }
  }

  Future<void> toggleStatus(String uid, AccountStatus newStatus) async {
    if (isFirebaseReady) {
      await _chefsCollection!.doc(uid).update({'status': newStatus.name});
    } else {
      final index = _localChefs.indexWhere((c) => c.uid == uid);
      if (index != -1) {
        _localChefs[index] = _localChefs[index].copyWith(status: newStatus);
        _localController.add(_localChefs);
      }
    }
  }

  Future<void> deleteChef(String uid) async {
    if (isFirebaseReady) {
      await _chefsCollection!.doc(uid).delete();
    } else {
      _localChefs.removeWhere((c) => c.uid == uid);
      _localController.add(_localChefs);
    }
  }
}
