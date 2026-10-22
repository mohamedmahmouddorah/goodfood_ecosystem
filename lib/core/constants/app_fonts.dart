import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';

class AppFonts {
  const AppFonts._();
  static final mainTitle = TextStyle(
    color: Colors.white,
    fontSize: 36,
    fontWeight: .bold,
    height: 1.2
  );
  static final subTitle = TextStyle(
    color:  Color.fromARGB(255, 243, 207, 207),
    fontSize: 18,
    fontWeight: .w400
  );
  static final smallGoldTiltle = TextStyle(
    color: AppColors.goldenYellow,
    fontSize: 12,
    fontWeight: .w400,
    height: 1
  );
}