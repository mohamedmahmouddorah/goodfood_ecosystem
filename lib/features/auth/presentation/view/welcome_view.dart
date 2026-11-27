import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: const [LanguageToggle()],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('${AppAssets.path}welcome_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              final scale = (constraints.maxWidth / 900).clamp(1.0, 1.45).toDouble();
              final content = Container(
                constraints: const BoxConstraints(maxWidth: 1120),
                margin: EdgeInsets.symmetric(
                  horizontal: wide ? 36 : 20,
                  vertical: wide ? 28 : 16,
                ),
                padding: EdgeInsets.all(wide ? 44 : 24),
                decoration: BoxDecoration(
                  color: const Color(0xD9001014),
                  borderRadius: BorderRadius.circular(wide ? 32 : 24),
                  border: Border.all(color: AppColors.cardBorder.withOpacity(.7)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 14)),
                  ],
                ),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: _brandPanel(context, scale)),
                          SizedBox(width: 52 * scale),
                          Expanded(child: _welcomeActions(context, scale, centered: false)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _brandPanel(context, scale),
                          SizedBox(height: 36 * scale),
                          _welcomeActions(context, scale, centered: true),
                        ],
                      ),
              );

              return Center(
                child: SingleChildScrollView(
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brandPanel(BuildContext context, double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          '${AppAssets.path}logo.svg',
          fit: BoxFit.contain,
          width: 190 * scale,
          height: 140 * scale,
        ),
        AppText('GoodFood', style: AppFonts.mainTitle.copyWith(fontSize: 42 * scale)),
        AppText('RESTAURANT', style: AppFonts.smallGoldTiltle.copyWith(fontSize: 14 * scale, letterSpacing: 3)),
        SizedBox(height: 20 * scale),
        Container(
          width: 76 * scale,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.goldenYellow,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        SizedBox(height: 18 * scale),
        AppText(
          'Fresh ingredients  •  Great taste',
          textAlign: TextAlign.center,
          style: AppFonts.subTitle.copyWith(fontSize: 17 * scale, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _welcomeActions(BuildContext context, double scale, {required bool centered}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        AppText(
          'Welcome',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: AppFonts.mainTitle.copyWith(fontSize: 42 * scale, height: 1.1),
        ),
        SizedBox(height: 12 * scale),
        AppText(
          'Good food, Better moments',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: AppFonts.subTitle.copyWith(fontSize: 20 * scale),
        ),
        SizedBox(height: 34 * scale),
        SizedBox(
          width: centered ? double.infinity : 360 * scale,
          height: 64 * scale,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/customer_details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldDark,
              foregroundColor: Colors.black,
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  'Start Ordering',
                  style: AppFonts.subTitle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20 * scale,
                  ),
                ),
                SizedBox(width: 12 * scale),
                Icon(Icons.arrow_forward_rounded, size: 27 * scale, color: Colors.black),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
