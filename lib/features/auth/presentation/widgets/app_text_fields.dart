import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

enum AppFieldsType { username, password, tableNo, name }

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
      return context.tr("Table number is required");
    }

    final number = int.tryParse(value);

    if (number == null || number <= 0) {
      return context.tr("Please enter a valid table number");
    }

    return null;
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    final name = value.trim();

    final nameRegex = RegExp(r'^[a-zA-Z\u0621-\u064A\s]+$');

    if (!nameRegex.hasMatch(name)) {
      return 'Name must contain letters only';
    }

    if (name.length < 3) {
      return 'Name must be at least 3 characters';
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
      constraints: const BoxConstraints(minHeight: 88),
      width: double.infinity,
      child: TextFormField(
        controller: widget.cont,
        validator: widget.type == AppFieldsType.tableNo
            ? validateTableNo
            : widget.type == AppFieldsType.name
            ? validateName
            : (value) {
                if (value == null || value.isEmpty) {
                  return context.tr(
                    widget.type == AppFieldsType.username
                        ? 'Username or Email is required'
                        : 'Password is required',
                  );
                }
                if (widget.type == AppFieldsType.username &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                  return context.tr('Please enter a valid email address');
                }
                return null;
              },
        obscureText: isSecure,
        style: AppFonts.subTitle,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 20),
          isDense: true,
          hintText: context.tr(widget.hintTxt),
          prefixIcon: Icon(
            widget.type == AppFieldsType.username
                ? Icons.person_outlined
                : widget.type == AppFieldsType.password
                ? Icons.lock_outline
                : widget.type == AppFieldsType.name
                ? Icons.person_outlined
                : Icons.assignment_outlined,
            size: 28,
          ),
          iconColor: Colors.white,
          fillColor: AppColors.cardBackground,
          filled: true,
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.errorBorder, width: 2),
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
          // Only password fields get a visibility toggle. Supplying an
          // IconButton with a null icon still reserves suffix space.
          suffixIcon: widget.type == AppFieldsType.password
              ? IconButton(
                  tooltip: isSecure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => isSecure = !isSecure),
                  icon: Icon(
                    isSecure ? Icons.visibility_off : Icons.visibility,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
