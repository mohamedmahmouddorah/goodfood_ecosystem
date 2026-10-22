import 'package:firebase_auth/firebase_auth.dart';
import 'auth_error.dart';

AuthError mapAuthError(FirebaseAuthException exception) {
  switch (exception.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return AuthError.invalidCredentials;

    case 'network-request-failed':
      return AuthError.networkError;
   
    case 'too-many-requests':
      return AuthError.tooManyRequests;

    case 'user-disabled':
      return AuthError.userDisabled;
    case 'invalid-email':
      return AuthError.InvalidEmail;
    default:
      return AuthError.unknown;
  }
}