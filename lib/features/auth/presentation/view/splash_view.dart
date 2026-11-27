import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().navigateNext();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSplashSuccessState) {
          Navigator.pushNamedAndRemoveUntil(context, state.route, (route) => false);
        } else if (state is AuthSplashFailState) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(state.msg)));
        }
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('${AppAssets.path}splash_background.png'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 800;
                final scale = (constraints.maxWidth / 900).clamp(.9, 1.5).toDouble();
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 40 : 20),
                    child: Container(
                      width: wide ? 620 : double.infinity,
                      constraints: const BoxConstraints(maxWidth: 620),
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 56 : 28,
                        vertical: wide ? 52 : 36,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD9001014),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.cardBorder.withOpacity(.7)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            '${AppAssets.path}logo.svg',
                            fit: BoxFit.contain,
                            width: 180 * scale,
                            height: 130 * scale,
                          ),
                          AppText('GoodFood', style: AppFonts.mainTitle.copyWith(fontSize: 42 * scale)),
                          SizedBox(height: 5),
                          AppText(
                            'RESTAURANT',
                            style: AppFonts.smallGoldTiltle.copyWith(fontSize: 14 * scale, letterSpacing: 3),
                          ),
                          SizedBox(height: 24 * scale),
                          AppText(
                            'Good Food - Better Moments',
                            textAlign: TextAlign.center,
                            style: AppFonts.subTitle.copyWith(fontSize: 19 * scale),
                          ),
                          SizedBox(height: 44 * scale),
                          SizedBox(
                            width: 300 * scale,
                            child: LinearProgressIndicator(
                              minHeight: 7 * scale,
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.goldenYellow,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          AppText('Loading...', style: AppFonts.subTitle.copyWith(fontSize: 16 * scale)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
