import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_error.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_error_mapper.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/firebase/firebase_environment.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    FirebaseAuth? auth,
    FirebaseFirestore? store,
    this.secureCustomerFlow = FirebaseEnvironment.useEmulators,
  }) : authInstance = auth ?? FirebaseEnvironment.auth,
       storeInstance = store ?? FirebaseEnvironment.store,
       super(AuthIntialState());
  final bool secureCustomerFlow;
  UserModel? currentUser;
  final FirebaseAuth authInstance;
  final FirebaseFirestore storeInstance;

  Future<void> logout() async {
    await authInstance.signOut();
    currentUser = null;
  }

Future<void> login(String email, String pass) async {
  emit(AuthLoginLoadingState());

  UserCredential userCredential;

  // 1. Firebase Authentication
  try {
    userCredential = await authInstance.signInWithEmailAndPassword(
      email: email.trim(),
      password: pass,
    );

    if (userCredential.user == null) {
      emit(AuthLoginFailState(errorType: AuthError.unknown));
      return;
    }
  } on FirebaseAuthException catch (e) {
    debugPrint('AUTH LOGIN ERROR: ${e.code}');
    debugPrint('AUTH LOGIN MESSAGE: ${e.message}');

    emit(AuthLoginFailState(errorType: mapAuthError(e)));
    return;
  } catch (e) {
    debugPrint('UNEXPECTED AUTH ERROR: $e');

    emit(AuthLoginFailState(errorType: AuthError.unknown));
    return;
  }

  // 2. Firestore User Data
  try {
    final user = userCredential.user!;

    final userMap = await storeInstance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userMap.exists || userMap.data() == null) {
      debugPrint('USER PROFILE NOT FOUND: ${user.uid}');

      emit(AuthLoginFailState(errorType: AuthError.unknown));
      return;
    }

    currentUser = UserModel.fromMap(userMap.data()!);

    emit(AuthLoginSuccessState(user: currentUser!));
  } on FirebaseException catch (e) {
    debugPrint('FIRESTORE LOGIN ERROR: ${e.code}');
    debugPrint('FIRESTORE MESSAGE: ${e.message}');

    emit(AuthLoginFailState(errorType: AuthError.unknown));
  } catch (e) {
    debugPrint('USER MODEL ERROR: $e');

    emit(AuthLoginFailState(errorType: AuthError.unknown));
  }
}

  Future<void> sendPasswordResetEmail(String email) async {
    emit(AuthForgotPasswordLoadingState());
    try {
      await authInstance.sendPasswordResetEmail(email: email.trim());
      emit(AuthForgotPasswordSuccessState());
    } on FirebaseAuthException catch (e) {
      // Do not reveal whether an email is registered (account enumeration).
      if (e.code == 'user-not-found') {
        emit(AuthForgotPasswordSuccessState());
        return;
      }
      emit(
        AuthForgotPasswordFailState(
          message: 'We could not process your request. Check your connection and try again.',
        ),
      );
    } catch (_) {
      emit(
        AuthForgotPasswordFailState(
          message: 'We could not process your request. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> selectRole(String selected) async {
    emit(AuthSelectRoleLoadingState());
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = await sp.setString("role", selected);

      if (!saved) {
        emit(AuthSelectRoleFailState(msg: "Failed to save role"));
        return;
      }
      emit(AuthSelectRoleSuccessState(role: selected));
    } catch (e) {
      emit(AuthSelectRoleFailState(msg: e.toString()));
    }
  }

  Future<void> navigateNext() async {
    emit(AuthSplashLoadingState());

    final startTime = DateTime.now();

    try {
      final sp = await SharedPreferences.getInstance();
      final role = sp.getString("role");

      String route;

      if (role == null) {
        route = '/role_selection';
      } else {
        final user = await authInstance.authStateChanges().first;

        if (secureCustomerFlow &&
            (role != 'Stuff' || user?.isAnonymous == true)) {
          currentUser = null;
          route = role == 'Stuff' ? '/login' : '/welcome';
        } else if (user == null) {
          route = role == "Stuff" ? '/login' : '/welcome';
        } else {
          final userMap = await storeInstance
              .collection("users")
              .doc(user.uid)
              .get();

          if (!userMap.exists || userMap.data() == null) {
            await authInstance.signOut();
            currentUser = null;
            route = role == "Stuff" ? '/login' : '/welcome';
          } else {
            currentUser = UserModel.fromMap(userMap.data()!);

            if (role == "Stuff") {
              route = currentUser!.role.name == "Admin" ? '/admin' : '/chef';
            } else {
              route = '/welcome';
            }
          }
        }
      }

      const splashDuration = Duration(seconds: 2);
      final elapsed = DateTime.now().difference(startTime);

      if (elapsed < splashDuration) {
        await Future.delayed(splashDuration - elapsed);
      }

      if (isClosed) return;

      emit(AuthSplashSuccessState(route: route));
    } catch (e) {
      const splashDuration = Duration(seconds: 2);
      final elapsed = DateTime.now().difference(startTime);

      if (elapsed < splashDuration) {
        await Future.delayed(splashDuration - elapsed);
      }

      if (isClosed) return;

      emit(
        AuthSplashFailState(
          msg: "Unable to initialize the app. Please try again.",
        ),
      );
    }
  }
}
