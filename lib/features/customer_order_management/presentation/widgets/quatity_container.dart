import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
class QuatityContainer extends StatelessWidget {
  const QuatityContainer({super.key , required this.quantityKey , required this.item});
  final OrderItemModel item ;
  final GlobalKey<FormFieldState<int>>quantityKey;
  @override
  Widget build(BuildContext context) {
    final cartCubit = context.read<CartCubit>();
    return FormField<int>(
      initialValue: item.quantity,
      key: quantityKey,
      validator: (value) {
        if (value == null || value < 1) {
          return "Quantity must be at least 1";
        }
        return null;
      },
      builder: (state) {
        return Container(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputDecorator(
                
                decoration: InputDecoration(
                  
                  isDense: true,
                  constraints: BoxConstraints(
                    minWidth: 28,
                    minHeight: 28
                  ),
                  contentPadding: EdgeInsets.zero,
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
                  mainAxisSize: .min,
                  children: [
                     IconButton(
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        
                      ),
                        constraints: const BoxConstraints(
          minWidth: 15,
          minHeight: 15,
        ),
        visualDensity: VisualDensity.compact,
      
                      onPressed: () {
                        if (state.value! > 1) {
                          cartCubit.updateQuantity(item, (state.value ?? 0) - 1);
                          state.didChange((state.value ?? 0) - 1);
                        }
                      },
                      icon: Icon(Icons.remove, size: 14, color: Colors.white),
                    ),
                    Text(
                      "${state.value ?? 0}",
                      style: AppFonts.boldSubTitleWhite18.copyWith(fontSize: 14),
                    ),
                   IconButton(
                    style: IconButton.styleFrom(
                        padding: EdgeInsets.zero
                      ),
                        constraints: const BoxConstraints(
          minWidth: 15,
          minHeight: 15,
        ),
        visualDensity: VisualDensity.compact,
                      onPressed: () {
                        cartCubit.updateQuantity(item, (state.value ?? 0) + 1);
                        state.didChange((state.value ?? 0) + 1);
                      },
                      icon: Icon(Icons.add, size: 14, color: Colors.white),
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
