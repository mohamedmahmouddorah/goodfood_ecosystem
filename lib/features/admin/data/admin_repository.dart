import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../customer_order_management/data/models/order_model.dart';

abstract interface class AdminDataSource {
  Stream<String?> watchClaimedAdmin({bool refreshToken = false});
  Stream<String?> watchAdminName(String uid);
  Stream<List<OrderModel>> watchOrders();
}

class AdminRepository implements AdminDataSource {
  const AdminRepository(this.auth, this.store);

  final FirebaseAuth auth;
  final FirebaseFirestore store;

  static const _diagnostics =
      kDebugMode && bool.fromEnvironment('ADMIN_ACCESS_DIAGNOSTICS');

  void _log(String message) {
    if (_diagnostics) debugPrint('[AdminAccess] $message');
  }

  @override
  Stream<String?> watchClaimedAdmin({bool refreshToken = false}) {
    var refreshPending = refreshToken;
    return auth.idTokenChanges().asyncMap((user) {
      // A forced refresh can itself emit an ID token event. Consume it once.
      final forceRefresh = refreshPending;
      refreshPending = false;
      return _checkClaim(user, forceRefresh);
    });
  }

  Future<String?> _checkClaim(User? user, bool forceRefresh) async {
    if (user == null || user.isAnonymous) {
      _log(
        'uid=${user?.uid} result=${user == null ? 'signed-out' : 'anonymous'}',
      );
      return null;
    }
    final uid = user.uid;
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      final hasClaim = token.claims?['admin'] == true;
      final sameUser = auth.currentUser?.uid == uid;
      final result = !sameUser
          ? 'identity-changed'
          : hasClaim
          ? 'claim-verified'
          : 'missing-admin-claim';
      _log('uid=$uid adminClaim=$hasClaim result=$result');
      if (_diagnostics && sameUser && !hasClaim) {
        unawaited(_inspectRejectedProfile(uid));
      }
      return hasClaim && sameUser ? uid : null;
    } on FirebaseAuthException catch (error) {
      _log('uid=$uid result=token-error code=${error.code}');
      rethrow;
    }
  }

  // This read provides context for a claim rejection and never grants access.
  Future<void> _inspectRejectedProfile(String uid) async {
    try {
      final profile = await store
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (auth.currentUser?.uid == uid) _profileResult(profile);
    } catch (error) {
      _logProfileError(uid, error);
    }
  }

  String _profileResult(DocumentSnapshot<Map<String, dynamic>> profile) {
    final data = profile.data();
    final role = data?['role'];
    final status = data?['status'];
    final result = data == null
        ? 'profile-missing'
        : role != 'Admin'
        ? 'role-not-admin'
        : status != 'Active'
        ? 'status-not-active'
        : 'profile-verified';
    if (_diagnostics) {
      final safeRole = switch (role) {
        'Admin' || 'Chef' || 'Customer' || null => role,
        _ => 'unrecognized',
      };
      final safeStatus = switch (status) {
        'Active' || 'Inactive' || null => status,
        _ => 'unrecognized',
      };
      _log(
        'uid=${profile.id} role=$safeRole status=$safeStatus profile=$result',
      );
    }
    return result;
  }

  void _logProfileError(String uid, Object error) {
    if (!_diagnostics) return;
    final code = error is FirebaseException ? error.code : 'unknown';
    _log('uid=$uid result=profile-read-error code=$code');
  }

  @override
  Stream<String?> watchAdminName(String uid) => store
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where(
        (profile) =>
            !profile.metadata.isFromCache && !profile.metadata.hasPendingWrites,
      )
      .map((profile) {
        final data = profile.data();
        final name = data?['name'];
        if (_profileResult(profile) != 'profile-verified') {
          return null;
        }
        return name is String ? name.trim() : '';
      })
      .handleError((Object error, StackTrace stack) {
        _logProfileError(uid, error);
        Error.throwWithStackTrace(error, stack);
      });

  @override
  Stream<List<OrderModel>> watchOrders() => store
      .collection('orders')
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.isFromCache)
      .map((snapshot) => snapshot.docs.map(OrderModel.fromDocument).toList());
}
