import 'package:firebase_auth/firebase_auth.dart';

/// Restores the Auth session or signs in anonymously for owned customer orders.
class CustomerIdentityService {
  CustomerIdentityService(this.auth);
  final FirebaseAuth auth;
  static final _pending = Expando<Future<User>>();

  Future<User> ensureSignedIn() =>
      _pending[auth] ??= _restoreOrSignIn().whenComplete(() {
        _pending[auth] = null;
      });

  Future<User> _restoreOrSignIn() async {
    final restored = await auth.authStateChanges().first;
    if (restored != null) return restored;
    // Recheck after asynchronous restoration; never replace a staff session.
    final current = auth.currentUser;
    if (current != null) return current;
    final credential = await auth.signInAnonymously();
    return credential.user ?? (throw StateError('Customer sign-in failed.'));
  }
}
