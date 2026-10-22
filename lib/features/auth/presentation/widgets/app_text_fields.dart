import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

enum AppFieldsType { username, password }

class AppTextFields extends StatefulWidget {
  const AppTextFields({
    super.key,
    required this.cont,
    required this.hintTxt,
    required this.type,
  });
  final TextEditingController cont;
  final String hintTxt;
  final AppFieldsType type;

  @override
  State<AppTextFields> createState() => _AppTextFieldsState();
}

class _AppTextFieldsState extends State<AppTextFields> {
  bool isSecure = false;
  @override
  void initState() {
    super.initState();
    isSecure = widget.type == AppFieldsType.password;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.cont,
      validator: (value) {
        if(value == null || value.isEmpty){
          return "${widget.type == AppFieldsType.username?"Username or Email" : "Password"} is required";
        }
        return null;
      },
      obscureText: isSecure,
      style: AppFonts.subTitle,
      decoration: InputDecoration(
        hintText: widget.hintTxt,
        prefixIcon: Icon(
          widget.type == AppFieldsType.username
              ? Icons.person_outlined
              : Icons.lock_outline,
        ),
        iconColor: Colors.white,
        fillColor: AppColors.cardBackground,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
        ),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              isSecure = !isSecure;
            });
          },
          icon: Icon(
            widget.type != AppFieldsType.password
                ? null
                : isSecure
                ? Icons.visibility
                : Icons.visibility_off,
          ),
        ),
      ),
    );
  }
}
