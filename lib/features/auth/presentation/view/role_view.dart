import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_state.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/widgets/role_container.dart';

class RoleView extends StatelessWidget {
  const RoleView({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        debugPrint('Listener received: ${state.runtimeType}');

        // TODO: implement listener
        if (state is AuthSelectRoleSuccessState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(
                    "You now selected as ${state.role}",
                    style: AppFonts.subTitle,
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
          if (state.role == "Stuff") {
            Navigator.pushReplacementNamed(context, '/login');
          } else {
            Navigator.pushReplacementNamed(context, '/welcome');
          }
        }
        if (state is AuthSelectRoleFailState) {
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
                      child: Icon(
                        Icons.error,
                        size: 20,
                        color: AppColors.errorIcon,
                      ),
                    ),
                  ),
                  Text(state.msg, style: AppFonts.subTitle),
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
                    Text("GoodFood", style: AppFonts.mainTitle),
                    Text("RESTAURANT", style: AppFonts.smallGoldTiltle),
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Text(
                        "Select Device Type",
                        style: AppFonts.subTitle.copyWith(
                          fontSize: 30,
                          fontWeight: .bold,
                        ),
                      ),
                    ),
                    Text(
                      "Choose the type of device you are setting up",
                      style: AppFonts.subTitle.copyWith(fontSize: 16),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Row(
                        children: [
                          SizedBox(width: 12),
                          Expanded(
                            child: RoleContainer(
                              path: "${AppAssets.path}customer.png",
                              desc: "For customers to place orders",
                              type: "Customer",
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: RoleContainer(
                              path: "${AppAssets.path}chef.png",
                              desc: "For staff to manage tasks",
                              type: "Stuff",
                            ),
                          ),
                          SizedBox(width: 12),
                        ],
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
