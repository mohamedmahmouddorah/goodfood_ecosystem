import 'package:flutter/material.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

class GuestsNumber extends StatelessWidget {
  GuestsNumber({super.key ,  required this.quantityKey});

  final GlobalKey<FormFieldState<int>>quantityKey;
  @override
  Widget build(BuildContext context) {
    return FormField<int>(
      initialValue: 1,
      key: quantityKey,
      validator: (value) {
        if (value == null || value < 1) {
          return "Quantity must be at least 1";
        }
        return null;
      },
      builder: (state) {
        return Container(
          height: 88,
          width: double.infinity,
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  errorText: state.hasError ? state.errorText : null,
                  fillColor: AppColors.cardBackground,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.errorBorder,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                     IconButton(
                      onPressed: () {
                        if (state.value! > 1) {
                          state.didChange((state.value ?? 0) - 1);
                        }
                      },
                      icon: Icon(Icons.remove, size: 28, color: Colors.white),
                    ),
                    Text(
                      "${state.value ?? 0}",
                      style: AppFonts.boldSubTitleWhite18,
                    ),
                   IconButton(
                      onPressed: () {
                        state.didChange((state.value ?? 0) + 1);
                      },
                      icon: Icon(Icons.add, size: 24, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}