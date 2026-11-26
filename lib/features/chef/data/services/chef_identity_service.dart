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

  Stream<ChefIdentity> watch() => auth.authStateChanges().switchMap((user) {
    if (user == null) {
      return Stream<ChefIdentity>.error(const ChefAccessDenied());
    }
    return store.collection('users').doc(user.uid).snapshots().map((snapshot) {
      return identityFromProfile(user.uid, snapshot.data());
    });
  });

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
