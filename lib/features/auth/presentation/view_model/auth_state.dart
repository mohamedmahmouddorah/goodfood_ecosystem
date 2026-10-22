import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_error.dart';

class AuthState {}
class AuthIntialState extends AuthState {}
class AuthLoginLoadingState extends AuthState {}
class AuthLoginSuccessState extends AuthState{
   UserModel user ;
   AuthLoginSuccessState({required this.user});
}
class AuthLoginFailState extends AuthState {
  AuthError errorType;
  AuthLoginFailState({required this.errorType });
}
class AuthAutoLoginLoadingState extends AuthState {}
class AuthAutoLoginSuccessState extends AuthState{
   UserModel user ;
   AuthAutoLoginSuccessState({required this.user});
}
class AuthAutoLoginFailState extends AuthState {
  String msg;
  AuthAutoLoginFailState({required this.msg});
}
class AuthSelectRoleLoadingState extends AuthState {}
class AuthSelectRoleSuccessState extends AuthState{
  String role ;
  AuthSelectRoleSuccessState({required this.role});
}
class AuthSelectRoleFailState extends AuthState {
  String msg;
  AuthSelectRoleFailState({required this.msg});
}
class AuthSplashLoadingState extends AuthState {}

class AuthSplashSuccessState extends AuthState {
  final String route;

  AuthSplashSuccessState({required this.route});
}

class AuthSplashFailState extends AuthState {
  final String msg;

  AuthSplashFailState({required this.msg});
}