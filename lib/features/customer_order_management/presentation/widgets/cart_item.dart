import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/widgets/quatity_container.dart';

class CartItem extends StatelessWidget {
  CartItem({super.key, required this.item});
  final quantityKey = GlobalKey<FormFieldState<int>>();
  final OrderItemModel item;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: BoxBorder.all(color: AppColors.cardBorder, width: 2),
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
        child: Center(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CachedNetworkImage(
                  imageUrl: item.mealImage,
                  width: 85,
                  height: 85,
                  fit: BoxFit.fill,
      
                  placeholder: (context, url) {
                    return Container(
                      width: 100,
                      height: 100,
                      color: AppColors.cardBackground,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorWidget: (context, url, error) {
                    return Image.asset(
                      "${AppAssets.path}placeholder_img.png",
                      width: 85,
                      height: 85,
                      fit: BoxFit.fill,
                    );
                  },
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          item.mealName,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.boldSubTitleWhite18,
                        ),
                      ),
                    ),
                    /** Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        item.mealName,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.reqularSubTitleWhite18.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ), */
                    BlocBuilder<CartCubit, CartState>(
                      builder: (context, state) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            
                            "\$${(item.unitPrice * item.quantity).toStringAsFixed(2)}",
                            style: AppFonts.reqularSubTitleWhite18.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        );
                        
                      },
                    ),
                     Row(
                       children: [
                         SizedBox(width : 100 , child: QuatityContainer(quantityKey: quantityKey, item: item)),
                         IconButton(onPressed: (){
                          context.read<CartCubit>().removeFromCart(item);
                         }, icon: Icon(Icons.delete ,color: Colors.white,))
                       ],
                     ),
                  ],
                ),
              ),
              SizedBox(width: 20),
             
            ],
          ),
        ),
      ),
    );
  }
}
