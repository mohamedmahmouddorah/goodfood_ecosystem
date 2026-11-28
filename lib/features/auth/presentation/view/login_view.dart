import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
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
    final authCubit = context.watch<AuthCubit>();
    final state = authCubit.state;
    final error = state is AuthLoginFailState
        ? switch (state.errorType) {
            AuthError.networkError =>
              'Please check your network, and try again',
            AuthError.invalidCredentials => "Email or password aren't correct.",
            AuthError.userDisabled => 'Your acoount deactivated',
            AuthError.InvalidEmail => 'Please enter valid email, and try again',
            _ => 'Something went wrong. please try again later.',
          }
        : null;
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoginSuccessState) {
          if (state.user.role == Role.Admin) {
            Navigator.pushReplacementNamed(context, '/admin');
          } else if (state.user.role == Role.Chef) {
            Navigator.pushReplacementNamed(context, '/chef');
          }
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: const [LanguageToggle()],
        ),

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
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          "${AppAssets.path}logo.svg",
                          fit: .contain,
                          width: 130,
                          height: 90,
                        ),
                        AppText("GoodFood", style: AppFonts.mainTitle),
                        AppText("RESTAURANT", style: AppFonts.smallGoldTiltle),
                        Padding(
                          padding: const EdgeInsets.only(top: 32.0),
                          child: AppText(
                            "Staff Login",
                            style: AppFonts.subTitle.copyWith(
                              fontSize: 30,
                              fontWeight: .bold,
                              height: 1,
                            ),
                          ),
                        ),
                        AppText(
                          "Please login to access your account",
                          style: AppFonts.subTitle.copyWith(fontSize: 16),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  child: AppTextFields(
                                    cont: passwordController,
                                    hintTxt: "Password",
                                    type: AppFieldsType.password,
                                  ),
                                ),
                                if (error != null) ...[
                                  AppInlineFeedback(error),
                                  const SizedBox(height: 10),
                                ],
                                ElevatedButton(
                                  onPressed: state is AuthLoginLoadingState
                                      ? null
                                      : () {
                                          if (formKey.currentState!
                                              .validate()) {
                                            FocusScope.of(context).unfocus();
                                            authCubit.login(
                                              emailController.text,
                                              passwordController.text,
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      55,
                                    ),
                                    backgroundColor: AppColors.goldDark,
                                  ),

                                  child: state is AuthLoginLoadingState
                                      ? const CircularProgressIndicator(
                                          color: Color(0xff3B2414),
                                        )
                                      : AppText(
                                          'Login',
                                          style: AppFonts.subTitle.copyWith(
                                            color: const Color(0xff3B2414),
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/forgot_password'),
                          child: AppText(
                            "Forgot Password?",
                            style: AppFonts.subTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
