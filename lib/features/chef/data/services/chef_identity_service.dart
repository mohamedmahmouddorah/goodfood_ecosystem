import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

/// Identity is anchored to Firebase Auth, never a locally selected role or a
/// manually created /chefs roster document.
class ChefIdentity {
  const ChefIdentity({required this.uid, required this.name});
  final String uid;
  final String name;
}

class ChefAccessDenied implements Exception {
  const ChefAccessDenied();
}

class ChefIdentityService {
  ChefIdentityService({required this.auth, required this.store});
  final FirebaseAuth auth;
  final FirebaseFirestore store;

  Stream<ChefIdentity?> watch() {
    String? previousUid;
    return auth.authStateChanges().switchMap((user) async* {
      final switched = previousUid != null && previousUid != user?.uid;
      previousUid = user?.uid;
      if (user == null) {
        throw const ChefAccessDenied();
      }
      final profile = store
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map<ChefIdentity?>(
            (snapshot) => identityFromProfile(user.uid, snapshot.data()),
          );
      // Clear the previous chef's queues before waiting for the new profile.
      if (switched) yield null;
      yield* profile;
    });
  }

  static ChefIdentity identityFromProfile(
    String uid,
    Map<String, dynamic>? data,
  ) {
    final name = data?['name'];
    if (uid.isEmpty ||
        data?['role'] != 'Chef' ||
        data?['status'] != 'Active' ||
        name is! String ||
        name.trim().isEmpty) {
      throw const ChefAccessDenied();
    }
    return ChefIdentity(uid: uid, name: name);
  }
}
