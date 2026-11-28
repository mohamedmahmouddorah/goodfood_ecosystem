import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

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
    return auth.idTokenChanges().switchMap((user) {
      if (user == null || user.isAnonymous) {
        _log('result=${user == null ? 'signed-out' : 'anonymous'}');
        return Stream<String?>.value(null);
      }
      final uid = user.uid;
      // Keep the authorization boundary subscribed to the actual profile.
      // A role/status update now revokes or restores access without requiring
      // a logout/login cycle or a manual refresh.
      return store.collection('users').doc(uid)
          .snapshots(includeMetadataChanges: true)
          .asyncMap((profile) async {
            final forceRefresh = refreshPending;
            refreshPending = false;
            if (auth.currentUser?.uid != uid) return null;
            final token = await user.getIdTokenResult(forceRefresh);
            if (auth.currentUser?.uid != uid) return null;
            final result = _profileResult(profile);
            final hasClaim = token.claims?['admin'] == true;
            _log('uid=$uid result=$result hasClaim=$hasClaim');
            if (result == 'profile-verified' ||
                (hasClaim && profile.data()?['status'] != 'Inactive')) {
              return uid;
            }
            return null;
          })
          .handleError((Object error, StackTrace stack) {
            _logProfileError(uid, error);
            Error.throwWithStackTrace(error, stack);
          });
    });
  }

  Future<String?> _checkAdmin(User? user, bool forceRefresh) async {
    if (user == null || user.isAnonymous) {
      _log(
        'uid=${user?.uid} result=${user == null ? 'signed-out' : 'anonymous'}',
      );
      return null;
    }

    final uid = user.uid;

    try {
      final token = await user.getIdTokenResult(forceRefresh);
      if (auth.currentUser?.uid != uid) {
        return null;
      }

      DocumentSnapshot<Map<String, dynamic>> profile;
      try {
        profile = await store
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
      } catch (_) {
        profile = await store.collection('users').doc(uid).get();
      }

      if (auth.currentUser?.uid != uid) {
        _log('uid=$uid result=identity-changed');
        return null;
      }

      final result = _profileResult(profile);
      final hasClaim = token.claims?['admin'] == true;

      _log('uid=$uid result=$result hasClaim=$hasClaim');

      // Admin access is granted if either:
      // 1) The Firestore profile has role Admin and status Active
      // 2) Or the Firebase Auth token contains the admin: true custom claim (and is not Inactive)
      if (result == 'profile-verified' ||
          (hasClaim && profile.data()?['status'] != 'Inactive')) {
        return uid;
      }

      return null;
    } catch (error) {
      _logProfileError(uid, error);
      rethrow;
    }
  }

  String _profileResult(DocumentSnapshot<Map<String, dynamic>> profile) {
    final data = profile.data();
    if (data == null) return 'profile-missing';

    final role = data['role']?.toString().trim();
    final status = data['status']?.toString().trim();

    final isAdmin =
        role != null && (role == 'Admin' || role.toLowerCase() == 'admin');
    final isActive =
        status == null ||
        status == 'Active' ||
        status.toLowerCase() == 'active';

    final result = !isAdmin
        ? 'role-not-admin'
        : !isActive
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
      .map((snapshot) => snapshot.docs.map(OrderModel.fromDocument).toList());
}
