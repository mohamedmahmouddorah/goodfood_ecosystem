import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/admin/data/admin_repository.dart';

class _Token extends Fake implements IdTokenResult {
  _Token(this.claims);

  @override
  final Map<String, dynamic> claims;
}

class _User extends Fake implements User {
  _User(
    this.uid, {
    this.isAnonymous = false,
    this.claims = const {},
    this.refreshedClaims,
  });

  @override
  final String uid;
  @override
  final bool isAnonymous;
  final Map<String, dynamic> claims;
  final Map<String, dynamic>? refreshedClaims;
  final refreshRequests = <bool>[];

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    refreshRequests.add(forceRefresh);
    return _Token(forceRefresh ? refreshedClaims ?? claims : claims);
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser, {this.eventUser});

  @override
  final User? currentUser;
  final User? eventUser;

  @override
  Stream<User?> idTokenChanges() => Stream.value(eventUser ?? currentUser);
}

void main() {
  test(
    'refresh picks up a provisioned claim in the existing admin session',
    () async {
      final user = _User('existing-admin', refreshedClaims: {'admin': true});
      final store = FakeFirebaseFirestore();
      await store.collection('users').doc(user.uid).set({
        'role': 'Chef',
        'status': 'Active',
        'name': 'Existing Admin',
      });
      final repo = AdminRepository(_Auth(user), store);
      expect(await repo.watchClaimedAdmin().first, isNull);
      expect(await repo.watchClaimedAdmin(refreshToken: true).first, user.uid);
      expect(user.refreshRequests, [false, true]);
    },
  );

  test(
    'an existing active Admin profile satisfies the admin access guard',
    () async {
      final store = FakeFirebaseFirestore();
      await store.collection('users').doc('existing-admin').set({
        'role': 'Admin',
        'status': 'Active',
        'name': 'Existing Admin',
      });
      final repo = AdminRepository(_Auth(_User('existing-admin')), store);
      expect(
        await repo.watchAdminName('existing-admin').first,
        'Existing Admin',
      );
      expect(await repo.watchClaimedAdmin().first, 'existing-admin');
    },
  );

  for (final (uid, role, status, claims, anonymous, authorized) in [
    ('admin', 'Admin', 'Active', {'admin': true}, false, true),
    ('ordinary', 'Customer', 'Active', <String, dynamic>{}, false, false),
    ('chef', 'Chef', 'Active', <String, dynamic>{}, false, false),
    ('inactive', 'Admin', 'Inactive', {'admin': true}, false, false),
    ('guest', 'Admin', 'Active', {'admin': true}, true, false),
    ('wrong-type', 'Admin', 'Active', {'admin': 'true'}, false, true),
  ]) {
    test('checks the identity, token and profile for $uid', () async {
      final store = FakeFirebaseFirestore();
      await store.collection('users').doc(uid).set({
        'role': role,
        'status': status,
        'name': uid,
      });
      final auth = _Auth(_User(uid, isAnonymous: anonymous, claims: claims));
      final repo = AdminRepository(auth, store);
      final claimedUid = await repo.watchClaimedAdmin().first;
      final name = claimedUid == null
          ? null
          : await repo.watchAdminName(claimedUid).first;
      expect(name, authorized ? uid : null);
    });
  }

  test('rejects a claimed token event for a different current UID', () async {
    final repo = AdminRepository(
      _Auth(_User('current'), eventUser: _User('old', claims: {'admin': true})),
      FakeFirebaseFirestore(),
    );
    expect(await repo.watchClaimedAdmin().first, isNull);
  });
}
