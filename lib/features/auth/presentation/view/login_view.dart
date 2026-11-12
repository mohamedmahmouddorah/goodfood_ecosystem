import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_error.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/widgets/app_text_fields.dart';

class LoginView extends StatelessWidget {
  LoginView({super.key});
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoginSuccessState) {
          if (state.user.role == Role.Admin) {
            Navigator.pushReplacementNamed(context, '/admin');
          } else if (state.user.role == Role.Chef) {
            Navigator.pushReplacementNamed(context, '/chef');
          }
        }
        if (state is AuthLoginFailState) {
          String header;
          String body;
          IconData icon;
          if (state.errorType == AuthError.networkError) {
            header = "No inernet connection";
            body = "Please check your network, and try again";
            icon = Icons.wifi;
          } else if (state.errorType == AuthError.invalidCredentials) {
            header = "Email or password aren't correct.";
            body = "Please check your credentials, and try again";
            icon = Icons.error;
          } else if (state.errorType == AuthError.userDisabled) {
            header = "Your acoount deactivated";
            body = "Please check your manager, and try again";
            icon = Icons.error;
          } 
          else if (state.errorType == AuthError.InvalidEmail) {
            header = "Email Not Valid";
            body = "Please enter valid email, and try again";
            icon = Icons.error;
          } 
          else {
            header = "Login Failed";
            body = "Something went wrong. please try again later.";
            icon = Icons.error;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppColors.errorIconBackground,
                      ),
                      child: Icon(icon, size: 20, color: AppColors.errorIcon),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          header,
                          style: AppFonts.mainTitle.copyWith(fontSize: 18),
                        ),
                        Text(
                          body,
                          style: AppFonts.subTitle.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.errorBackground,
              behavior: .floating,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(15),
                side: BorderSide(color: AppColors.errorBorder),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("${AppAssets.path}login_background.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 128.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SvgPicture.asset(
                    "${AppAssets.path}logo.svg",
                    fit: .contain,
                    width: 130,
                    height: 90,
                  ),
                  Text("GoodFood", style: AppFonts.mainTitle),
                  Text("RESTAURANT", style: AppFonts.smallGoldTiltle),
                  Padding(
                    padding: const EdgeInsets.only(top: 32.0),
                    child: Text(
                      "Staff Login",
                      style: AppFonts.subTitle.copyWith(
                        fontSize: 30,
                        fontWeight: .bold,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(
                    "Please login to access your account",
                    style: AppFonts.subTitle.copyWith(fontSize: 16),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 28,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          AppTextFields(
                            cont: emailController,
                            hintTxt: "Username or email",
                            type: AppFieldsType.username,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: AppTextFields(
                              cont: passwordController,
                              hintTxt: "Password",
                              type: AppFieldsType.password,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                authCubit.login(
                                  emailController.text,
                                  passwordController.text,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(350, 55),
                              backgroundColor: AppColors.goldDark,
                            ),

                            child: BlocBuilder<AuthCubit, AuthState>(
                              
                              builder: (context, state) {
                                if(state is AuthLoginLoadingState){
                                  return CircularProgressIndicator(color: Color(0xff3B2414),);
                                }
                                return Text(
                                  "Login",
                                  style: AppFonts.subTitle.copyWith(
                                    color: Color(0xff3B2414),
                                    fontSize: 24,
                                    fontWeight: .bold,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text("Forgot Password?", style: AppFonts.subTitle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
