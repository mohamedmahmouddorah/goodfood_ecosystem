import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

enum AppFieldsType { username, password , tableNo , name }

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
  String? validateTableNo(String? value) {
  if (value == null || value.isEmpty) {
    return "Table number is required";
  }

  final number = int.tryParse(value);

  if (number == null || number <= 0) {
    return "Please enter a valid table number";
  }

  return null;
}
  @override
  void initState() {
    super.initState();
    isSecure = widget.type == AppFieldsType.password;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      width: double.infinity,
      child: TextFormField(
        controller: widget.cont,
        validator: widget.type == AppFieldsType.tableNo ? validateTableNo : widget.type == AppFieldsType.name  ? null  : (value) {
          if(value == null || value.isEmpty){
            return "${widget.type == AppFieldsType.username?"Username or Email" : "Password"} is required";
          }
          return null;
        },
        obscureText: isSecure,
        style: AppFonts.subTitle,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric( vertical: 20),
          isDense: true,
          hintText: widget.hintTxt,
          prefixIcon: Icon(
            widget.type == AppFieldsType.username
                ? Icons.person_outlined
                : widget.type == AppFieldsType.password? Icons.lock_outline : widget.type == AppFieldsType.name? Icons.person_outlined : Icons.assignment_outlined
                       , size: 28, ),
          iconColor: Colors.white,
          fillColor: AppColors.cardBackground,
          filled: true,
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: AppColors.errorBorder,
              width: 2,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
          ),
      
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }
}
