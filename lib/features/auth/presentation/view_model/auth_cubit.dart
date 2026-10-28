import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_error.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_error_mapper.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthIntialState());
  UserModel? currentUser; 
  final authInstance = FirebaseAuth.instance;
  final storeInstance = FirebaseFirestore.instance;
  Future<void> login(String email, String pass) async {
    emit(AuthLoginLoadingState());
    try {
      final userCrd = await authInstance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      if (userCrd.user == null) {
        emit(AuthLoginFailState(errorType: AuthError.unknown));
        return;
      } else {
        final userMap = await storeInstance
            .collection("users")
            .doc(userCrd.user!.uid)
            .get();
        currentUser = UserModel.fromMap(userMap.data()!);
        emit(AuthLoginSuccessState(user: currentUser!));
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthLoginFailState(errorType: mapAuthError(e)));
    } catch (e) {
      emit(AuthLoginFailState(errorType: AuthError.unknown));
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
      final user = authInstance.currentUser;

      if (user == null) {
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
            route = currentUser!.role.name == "Admin"
                ? '/admin'
                : '/chef';
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
