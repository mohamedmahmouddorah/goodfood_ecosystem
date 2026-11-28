import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/widgets/role_container.dart';

class RoleView extends StatelessWidget {
  const RoleView({super.key});

  @override
  Widget build(BuildContext context) {
    final roleState = context.watch<AuthCubit>().state;
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSelectRoleSuccessState) {
          showAppSnackBar(
            context,
            message: 'You now selected as ${state.role}',
            kind: FeedbackKind.success,
          );
          if (state.role == "Stuff") {
            Navigator.pushReplacementNamed(context, '/login');
          } else {
            Navigator.pushReplacementNamed(context, '/welcome');
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
              opacity: 0.9,
              image: AssetImage("${AppAssets.path}role_background.png"),
              fit: .cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 48.0),
              child: SingleChildScrollView(
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
                        "Select Device Type",
                        style: AppFonts.subTitle.copyWith(
                          fontSize: 30,
                          fontWeight: .bold,
                        ),
                      ),
                    ),
                    AppText(
                      "Choose the type of device you are setting up",
                      style: AppFonts.subTitle.copyWith(fontSize: 16),
                    ),
                    if (roleState is AuthSelectRoleFailState)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                        child: AppInlineFeedback(roleState.msg),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            RoleContainer(
                              path: "${AppAssets.path}customer.png",
                              desc: "For customers to place orders",
                              type: "Customer",
                            ),
                            RoleContainer(
                              path: "${AppAssets.path}chef.png",
                              desc: "For staff to manage tasks",
                              type: "Stuff",
                            ),
                          ];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: constraints.maxWidth < 560
                                    ? Column(
                                        children: [
                                          cards[0],
                                          const SizedBox(height: 16),
                                          cards[1],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(child: cards[0]),
                                          const SizedBox(width: 20),
                                          Expanded(child: cards[1]),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
