import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../localization/app_locale_cubit.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AppLocaleCubit?>();
    if (cubit == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 64,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final code in ['ar', 'en'])
                      Semantics(
                        selected: cubit.state.languageCode == code,
                        button: true,
                        child: InkWell(
                          onTap: () async {
                            try {
                              await cubit.select(code);
                            } catch (_) {
                              if (!context.mounted) return;
                              if (ScaffoldMessenger.maybeOf(context) != null) {
                                showAppSnackBar(
                                  context,
                                  message:
                                      'Could not save language. Please try again.',
                                  kind: FeedbackKind.error,
                                );
                              }
                            }
                          },
                          child: SizedBox(
                            width: 32,
                            height: 40,
                            child: Center(
                              child: Container(
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 24,
                                  maxWidth: 28,
                                  maxHeight: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: cubit.state.languageCode == code
                                      ? AppColors.primaryGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  code.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cubit.state.languageCode == code
                                        ? AppColors.addChefText
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
