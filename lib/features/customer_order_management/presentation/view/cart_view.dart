import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/checkout_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/widgets/cart_item.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';

class CartView extends StatefulWidget {
  const CartView({super.key, this.repository});

  final MenuRepository? repository;

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  @override
  Widget build(BuildContext context) {
    final orderCubit = context.read<CustomerOrderCubit>();
    final cartCubit = context.read<CartCubit>();

    return MultiBlocListener(
      listeners: [
        BlocListener<CartCubit, CartState>(
          listener: (context, state) {
            if (ModalRoute.of(context)?.isCurrent == false) return;
            if (state is RemoveFromCartSccessState) {
              showAppSnackBar(
                context,
                message: '${state.removedItem.mealName} deleted successfully!',
                kind: FeedbackKind.success,
              );
            } else if (state is RemoveFromCartFailState) {
              showAppSnackBar(
                context,
                message: state.msg,
                kind: FeedbackKind.error,
              );
            }
          },
        ),
        BlocListener<CustomerOrderCubit, CustomerOrderState>(
          listener: (context, state) async {
            if (ModalRoute.of(context)?.isCurrent == false) return;
            if (state is PlaceOrderSuccessState) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(
                        value: context.read<CustomerOrderCubit>(),
                      ),
                      BlocProvider.value(value: context.read<CartCubit>()),
                    ],
                    child: CheckoutView(
                      repository: widget.repository,
                      cartRepo: context.read<CartCubit>().repo,
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<CartCubit, CartState>(
        builder: (context, cartState) {
          final isCartEmpty = cartState.cartItems.isEmpty;

          return BlocBuilder<CustomerOrderCubit, CustomerOrderState>(
            builder: (context, orderState) {
              final isPlacingOrder = orderState is PlaceOrderLoadingState;

              return Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  title: AppText(
                    "Your Order",
                    style: AppFonts.mainTitle.copyWith(
                      fontSize: MediaQuery.sizeOf(context).width >= 800
                          ? 32
                          : 22,
                    ),
                  ),
                  actions: [
                    const LanguageToggle(),
                    if (!isCartEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 16.0),
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xff79747E),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              color: const Color(0xff122332),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 4,
                            ),
                            child: AppText(
                              "${cartState.cartItems.length} items",
                              style: AppFonts.reqularSubTitleWhite18.copyWith(
                                color: const Color(0xff94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                bottomNavigationBar: isCartEmpty
                    ? null
                    : SafeArea(
                        top: false,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: 1,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 680,
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * .65,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Divider(
                                    color: Color(0xff142331),
                                    thickness: 1.5,
                                  ),
                                  _summaryRow('Subtotal', cartCubit.subTotal),
                                  const SizedBox(height: 6),
                                  _summaryRow('Tax', cartCubit.tax),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Divider(
                                      color: Color(0xff142331),
                                      thickness: 1.5,
                                    ),
                                  ),
                                  _summaryRow(
                                    'Total',
                                    cartCubit.total,
                                    isTotal: true,
                                  ),
                                  if (orderState is PlaceOrderFailState)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: AppInlineFeedback(orderState.msg),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                      vertical: 16,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: isPlacingOrder
                                          ? null
                                          : () {
                                              clearAppSnackBars(context);
                                              orderCubit.placeOrder(
                                                cartCubit.cartItems,
                                                cartCubit.subTotal,
                                                cartCubit.total,
                                                cartCubit.tax,
                                              );
                                            },
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        backgroundColor: AppColors.goldDark,
                                        disabledBackgroundColor: AppColors
                                            .goldDark
                                            .withValues(alpha: 0.6),
                                        shadowColor: AppColors.goldDark
                                            .withValues(alpha: 0.5),
                                        elevation: 10,
                                        minimumSize: const Size(
                                          double.infinity,
                                          56,
                                        ),
                                      ),
                                      child: isPlacingOrder
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.black,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                AppText(
                                                  "Place Order",
                                                  style: AppFonts.subTitle
                                                      .copyWith(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward,
                                                  color: Colors.black,
                                                  size: 24,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                body: Stack(
                  children: [
                    if (isCartEmpty)
                      _buildEmptyCartView(context)
                    else
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0,
                                  ),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    itemCount: cartState.cartItems.length,
                                    itemBuilder: (context, index) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: CartItem(
                                        item: cartState.cartItems[index],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Full-screen Loading Overlay on placing order
                    if (isPlacingOrder)
                      Container(
                        color: Colors.black.withValues(alpha: 0.7),
                        width: double.infinity,
                        height: double.infinity,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141C28),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.goldLight.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.goldLight.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.5,
                                    color: AppColors.goldLight,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                AppText(
                                  "Placing your order...",
                                  style: AppFonts.boldSubTitleWhite18.copyWith(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const AppText(
                                  "Please wait a moment",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isTotal = false}) {
    final caption = AppFonts.reqularSubTitleWhite18.copyWith(
      color: const Color(0xff94A3B8),
      fontSize: isTotal ? 18 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: AppText(label, style: caption)),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '\$${amount.toStringAsFixed(2)}',
                    textDirection: TextDirection.ltr,
                    style: isTotal
                        ? AppFonts.boldSubTitleWhite18.copyWith(
                            fontSize: 24,
                            height: 1,
                          )
                        : AppFonts.reqularSubTitleWhite18.copyWith(
                            fontSize: 15,
                          ),
                  ),
                ),
                if (isTotal)
                  AppText(
                    'Incl. all taxes',
                    textAlign: TextAlign.end,
                    style: caption.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern glowing cart circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF131B26),
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.35),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldLight.withValues(alpha: 0.15),
                    blurRadius: 36,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 54,
                  color: AppColors.goldLight,
                ),
              ),
            ),
            const SizedBox(height: 28),
            AppText(
              "Your Cart is Empty",
              style: AppFonts.mainTitle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AppText(
              "Looks like you haven't added anything to your cart yet.\nExplore our delicious menu and find your favorite meal!",
              style: AppFonts.reqularSubTitleWhite18.copyWith(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/menu');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldDark,
                minimumSize: const Size(220, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: AppColors.goldDark.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    color: Colors.black,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  AppText(
                    "Start Shopping",
                    style: AppFonts.subTitle.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
