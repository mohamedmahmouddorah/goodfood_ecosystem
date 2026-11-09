import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/order_confirmed_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';

class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key, this.repository, this.cartRepo});

  final MenuRepository? repository;
  final CartRepo? cartRepo;

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isNameEnabled = true;
  late int _guestsCount;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final orderCubit = context.read<CustomerOrderCubit>();
      _guestsCount = orderCubit.noOfGuests ?? orderCubit.order?.noOfGuests ?? 1;
      _isInitialized = true;
    }
  }

  void _onContinueToPayment(BuildContext context) async {
    final orderCubit = context.read<CustomerOrderCubit>();
    final cartCubit = context.read<CartCubit>();

    if (orderCubit.order == null && cartCubit.cartItems.isNotEmpty) {
      await orderCubit.placeOrder(
        cartCubit.cartItems,
        cartCubit.subTotal,
        cartCubit.total,
        cartCubit.tax,
      );
    }

    await orderCubit.updatePayment(_selectedPaymentMethod);
  }

  @override
  Widget build(BuildContext context) {
    final orderCubit = context.watch<CustomerOrderCubit>();
    final cartCubit = context.watch<CartCubit>();

    final tableNo = orderCubit.tableNo ?? orderCubit.order?.tableNo ?? 5;
    final clientName = orderCubit.name ?? orderCubit.order?.clientName;

    final List<OrderItemModel> items = (orderCubit.order?.meals != null &&
            orderCubit.order!.meals.isNotEmpty)
        ? orderCubit.order!.meals
        : cartCubit.cartItems;

    final double subtotal = orderCubit.order?.subtotal ?? cartCubit.subTotal;
    final double serviceCharge =
        orderCubit.order?.serviceCharge ?? cartCubit.tax;
    final double total = orderCubit.order?.total ?? cartCubit.total;

    return BlocListener<CustomerOrderCubit, CustomerOrderState>(
      listener: (context, state) {
        if (state is UpdatePaymentSuccessState) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<CustomerOrderCubit>(),
                child: OrderConfirmedView(
                  repository: widget.repository,
                  cartRepo: widget.cartRepo,
                ),
              ),
            ),
          );
        } else if (state is UpdatePaymentFailState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.errorIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: AppColors.errorIcon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.msg,
                      style: AppFonts.mainTitle.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.errorBackground,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.errorBorder),
              ),
            ),
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWide = width >= 800;
          final isSmall = width < 360;
          final horizontalPadding = isSmall ? 10.0 : (isWide ? 24.0 : 16.0);

          return Scaffold(
            backgroundColor: const Color(0xFF0B1019),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0B1019),
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF222D3D)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              centerTitle: true,
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(
                      "Checkout",
                      style: AppFonts.boldSubTitleWhite18.copyWith(
                        fontSize: isSmall ? 16 : 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "GOODFOOD DINING",
                      style: AppFonts.smallGoldTiltle.copyWith(
                        fontSize: isSmall ? 8 : 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: isSmall ? 8.0 : 16.0),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 8 : 10,
                        vertical: isSmall ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1C16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.goldLight.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.goldLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Table $tableNo",
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: isSmall ? 11 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body:  Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: isWide ? 1050 : 580,
    ),
    child: SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 12.0,
                  ),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Customer Details + Order Summary
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCustomerDetailsCard(clientName, isSmall),
                                  const SizedBox(height: 16),
                                  _buildOrderSummaryCard(
                                    items,
                                    subtotal,
                                    serviceCharge,
                                    total,
                                    isSmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Column: Payment Method + Payment Button
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Payment Method",
                                    style: AppFonts.boldSubTitleWhite18.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPaymentOption(
                                    method: PaymentMethod.cash,
                                    icon: Icons.payments_outlined,
                                    title: "Cash at Counter",
                                    subtitle:
                                        "Pay physically with cash or invoice",
                                    isSmall: isSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPaymentOption(
                                    method: PaymentMethod.card,
                                    icon: Icons.credit_card_outlined,
                                    title: "Card Payment",
                                    subtitle:
                                        "Credit or debit terminal at table",
                                    isSmall: isSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPaymentOption(
                                    method: PaymentMethod.mobileWallet,
                                    icon: Icons.phone_iphone_outlined,
                                    title: "Mobile Wallet",
                                    subtitle:
                                        "Instant contactless checkout",
                                    badgeText: "APPLE PAY",
                                    isSmall: isSmall,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildPayButton(context),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCustomerDetailsCard(clientName, isSmall),
                            const SizedBox(height: 16),
                            _buildOrderSummaryCard(
                              items,
                              subtotal,
                              serviceCharge,
                              total,
                              isSmall,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Payment Method",
                              style: AppFonts.boldSubTitleWhite18.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPaymentOption(
                              method: PaymentMethod.cash,
                              icon: Icons.payments_outlined,
                              title: "Cash at Counter",
                              subtitle: "Pay physically with cash or invoice",
                              isSmall: isSmall,
                            ),
                            const SizedBox(height: 10),
                            _buildPaymentOption(
                              method: PaymentMethod.card,
                              icon: Icons.credit_card_outlined,
                              title: "Card Payment",
                              subtitle: "Credit or debit terminal at table",
                              isSmall: isSmall,
                            ),
                            const SizedBox(height: 10),
                            _buildPaymentOption(
                              method: PaymentMethod.mobileWallet,
                              icon: Icons.phone_iphone_outlined,
                              title: "Mobile Wallet",
                              subtitle: "Instant contactless checkout",
                              badgeText: "APPLE PAY",
                              isSmall: isSmall,
                            ),
                            //const SizedBox(height: 24),
                                        const SizedBox(height: 24),
_buildPayButton(context),
const SizedBox(height: 16),
                          ],
                        ),
                ),
              ),
            ),
            ),

          );
        },
      ),
    );
  }

  Widget _buildPayButton(BuildContext context) {
    return BlocBuilder<CustomerOrderCubit, CustomerOrderState>(
      builder: (context, state) {
        final isLoading = state is UpdatePaymentLoadingState ||
            state is PlaceOrderLoadingState;
        return ElevatedButton(
          onPressed: isLoading ? null : () => _onContinueToPayment(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldDark,
            disabledBackgroundColor:
                AppColors.goldDark.withValues(alpha: 0.6),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: AppColors.goldDark.withValues(alpha: 0.35),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Continue to Payment",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.black,
                      size: 20,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCustomerDetailsCard(String? clientName, bool isSmall) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F293B)),
      ),
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: isSmall ? 32 : 36,
                height: isSmall ? 32 : 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2536),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.goldLight,
                  size: isSmall ? 18 : 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Customer Details",
                  style: AppFonts.boldSubTitleWhite18.copyWith(
                    fontSize: isSmall ? 14 : 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Dine-In",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Number of Guests
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Number of Guests",
                      style: AppFonts.boldSubTitleWhite18.copyWith(
                        fontSize: isSmall ? 13 : 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Standard table arrangement",
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: isSmall ? 11 : 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1722),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF243042)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (_guestsCount > 1) {
                          setState(() => _guestsCount--);
                          context
                              .read<CustomerOrderCubit>()
                              .updateGuests(_guestsCount);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          "-",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "$_guestsCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _guestsCount++);
                        context
                            .read<CustomerOrderCubit>()
                            .updateGuests(_guestsCount);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          "+",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 28),
          // Your Name (Optional)
          Row(
            children: [
              const Icon(
                Icons.notifications_none,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName != null && clientName.isNotEmpty
                          ? clientName
                          : "Your Name (Optional)",
                      style: AppFonts.boldSubTitleWhite18.copyWith(
                        fontSize: isSmall ? 13 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Display on waiter terminal",
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: isSmall ? 11 : 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isNameEnabled,
                onChanged: (val) {
                  setState(() => _isNameEnabled = val);
                },
                activeThumbColor: AppColors.goldLight,
                activeTrackColor: AppColors.goldLight.withValues(alpha: 0.35),
                inactiveThumbColor: const Color(0xFF64748B),
                inactiveTrackColor: const Color(0xFF1E2838),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(
    List<OrderItemModel> items,
    double subtotal,
    double serviceCharge,
    double total,
    bool isSmall,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F293B)),
      ),
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Order Summary",
                style: AppFonts.boldSubTitleWhite18.copyWith(
                  fontSize: isSmall ? 14 : 16,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2318),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.goldLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "${items.length} items",
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  "No items in order",
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                return Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: item.mealImage,
                            width: isSmall ? 44 : 52,
                            height: isSmall ? 44 : 52,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: isSmall ? 44 : 52,
                              height: isSmall ? 44 : 52,
                              color: const Color(0xFF1E2838),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              "${AppAssets.path}placeholder_img.png",
                              width: isSmall ? 44 : 52,
                              height: isSmall ? 44 : 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF0F1722).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color:
                                    AppColors.goldLight.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              "${item.quantity}x",
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.mealName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmall ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Freshly prepared",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "\$${(item.unitPrice * item.quantity).toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmall ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          const Divider(color: Color(0xFF1E293B), height: 26),
          // Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Subtotal",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              Text(
                "\$${subtotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    "Service Charge",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B1E0C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "10%",
                      style: TextStyle(
                        color: Color(0xFFF97316),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "\$${serviceCharge.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Table VAT (Included)",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              Text(
                "\$0.00",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TOTAL AMOUNT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "\$${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    bool isSmall = false,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () {
        setState(() => _selectedPaymentMethod = method);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: isSmall ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141C28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.goldLight : const Color(0xFF1F293B),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isSmall ? 34 : 40,
              height: isSmall ? 34 : 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2536),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.goldLight : const Color(0xFF94A3B8),
                size: isSmall ? 18 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmall ? 13 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF263244),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: isSmall ? 11 : 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.goldLight : const Color(0xFF334155),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.goldLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
