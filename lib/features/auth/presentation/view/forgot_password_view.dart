import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/localization/goodfood_localizations.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../view_model/auth_cubit.dart';
import '../view_model/auth_state.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _handledSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthForgotPasswordSuccessState && !_handledSuccess) {
          _handledSuccess = true;
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF26352D),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF9FE0B5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('If an account exists for this email, a reset link will be sent.'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          Navigator.pushReplacementNamed(context, '/login');
        } else if (state is AuthForgotPasswordFailState) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF49302D),
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFFC4B8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('We could not process your request. Check your connection and try again.'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Forgot Password?')),
          actions: const [LanguageToggle()],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 400 ? 20.0 : 32.0;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock_reset, size: 64, color: AppColors.goldDark),
                          const SizedBox(height: 24),
                          Text(
                            context.tr('Reset your password'),
                            textAlign: TextAlign.center,
                            style: AppFonts.mainTitle.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('Enter the email address associated with your account. We will send you a password reset link.'),
                            textAlign: TextAlign.center,
                            style: AppFonts.subTitle.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              hintText: context.tr('Email'),
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: AppColors.cardBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return context.tr('Email is required.');
                              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                                return context.tr('Please enter a valid email address.');
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),
                          BlocBuilder<AuthCubit, AuthState>(
                            builder: (context, state) {
                              final loading = state is AuthForgotPasswordLoadingState;
                              return SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: loading ? null : _submit,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldDark),
                                  child: loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xff3B2414),
                                          ),
                                        )
                                      : Text(
                                          context.tr('Send reset link'),
                                          style: const TextStyle(
                                            color: Color(0xff3B2414),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().sendPasswordResetEmail(_emailController.text.trim());
  }
}
