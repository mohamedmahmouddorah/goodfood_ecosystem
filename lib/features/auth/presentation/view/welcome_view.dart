import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage("${AppAssets.path}welcome_background.png") , fit: .fill)
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                    Spacer(),
                    Text("Welcome" , style: AppFonts.subTitle.copyWith(fontSize: 36 , height: 1),),
                    Text("Good food, Better moments" , style: AppFonts.subTitle,),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: ElevatedButton(onPressed: (){},
                       style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldDark,
                        minimumSize: Size(350, 55)
                       ),
                       child: Row(
                        mainAxisSize: .min,
                        mainAxisAlignment: .center,
                         children: [
                           Text("Start Ordering" , style: AppFonts.subTitle.copyWith(color: Colors.black , fontWeight: .bold),),
                           SizedBox(width: 8,),
                           Icon(Icons.arrow_forward , color: Colors.black, size: 28,)
                         ],
                       )
                       ),
                    ),
                    Text("Fresh ingredients  •  Great taste" , style: AppFonts.smallGoldTiltle.copyWith(color: Colors.white),)
              ],
            ),
          ),
        ),
      ),
    );
  }
}