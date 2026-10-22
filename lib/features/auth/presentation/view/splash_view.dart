import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
          Navigator.pushNamedAndRemoveUntil(
            context,
            state.route,
            (route) => false,
          );
        } else if (state is AuthSplashFailState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.msg)),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                "${AppAssets.path}splash_background.png",
              ),
              fit: .cover,
            ),
          ),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Spacer(),
              SvgPicture.asset(
                "${AppAssets.path}logo.svg",
                fit: .contain,
                width: 130,
                height: 90,
              ),
              Text(
                "GoodFood",
                style: AppFonts.mainTitle,
              ),
              Text(
                "RESTAURANT",
                style: AppFonts.smallGoldTiltle,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  "Good Food - Better Moments",
                  style: AppFonts.subTitle,
                ),
              ),
              Spacer(),
              Text(
                "Loading...",
                style: AppFonts.subTitle,
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 16.0,
                  top: 8,
                ),
                child: SizedBox(
                  width: 250,
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    color: AppColors.goldenYellow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}