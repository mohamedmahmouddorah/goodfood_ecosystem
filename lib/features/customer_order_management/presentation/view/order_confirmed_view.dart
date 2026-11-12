import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/meal_local_cache.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/menu_remote_service.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/menu_screen.dart';
import 'package:hive/hive.dart';

class OrderConfirmedView extends StatelessWidget {
  const OrderConfirmedView({super.key, this.repository, this.cartRepo});

  final MenuRepository? repository;
  final CartRepo? cartRepo;

  void _backToMenu(BuildContext context) {
    final orderCubit = context.read<CustomerOrderCubit>();

    final cRepo = cartRepo ??
        CartRepo(
          cartBox: Hive.box<OrderItemModel>('cartBox'),
        );
    cRepo.clearCart();

    final menuRepo = repository ??
        MenuRepository(
          MenuRemoteService(FirebaseFirestore.instance),
          mealLocalCache: SqliteMealLocalCache(),
        );

    final newOrderCubit = CustomerOrderCubit()
      ..tableNo = orderCubit.tableNo
      ..noOfGuests = orderCubit.noOfGuests
      ..name = orderCubit.name;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => newOrderCubit,
          child: MenuScreen(
            repository: menuRepo,
            repo: cRepo,
          ),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderCubit = context.watch<CustomerOrderCubit>();
    final order = orderCubit.order;

    final dispId = order?.dispId.isNotEmpty == true
        ? order!.dispId
        : (orderCubit.pendingOrderId != null
            ? 'GF-${orderCubit.pendingOrderId!.substring(0, 6).toUpperCase()}'
            : '#1024');

    final tableNo = order?.tableNo ?? orderCubit.tableNo ?? 5;
    final meals = order?.meals ?? <OrderItemModel>[];
    final total = order?.total ?? 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToMenu(context);
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
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.restaurant_menu,
                      color: AppColors.goldLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "GOODFOOD",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          "RESTAURANT",
                          style: AppFonts.smallGoldTiltle.copyWith(
                            fontSize: 8,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: isSmall ? 8.0 : 16.0),
                  child: InkWell(
                    onTap: () => _backToMenu(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: isSmall ? 32 : 36,
                      height: isSmall ? 32 : 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E2838),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: const Color(0xFF94A3B8),
                        size: isSmall ? 16 : 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1050 : 580),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 8.0,
                  ),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column: Success Hero + Status Card
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildHero(isSmall),
                                  const SizedBox(height: 24),
                                  _buildStatusCard(
                                    dispId,
                                    tableNo,
                                    meals,
                                    isSmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right column: Overview Card + Action Buttons
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildOverviewCard(meals, total, isSmall),
                                  const SizedBox(height: 24),
                                  _buildActionButtons(context, isSmall),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHero(isSmall),
                            const SizedBox(height: 20),
                            _buildStatusCard(dispId, tableNo, meals, isSmall),
                            const SizedBox(height: 16),
                            _buildOverviewCard(meals, total, isSmall),
                            const SizedBox(height: 24),
                            _buildActionButtons(context, isSmall),
                            const SizedBox(height: 20),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(bool isSmall) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: isSmall ? 68 : 78,
            height: isSmall ? 68 : 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF181510),
              border: Border.all(
                color: AppColors.goldLight,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldLight.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.check,
              color: AppColors.goldLight,
              size: isSmall ? 34 : 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Order Confirmed!",
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmall ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Your order has been placed and is currently\nbeing prepared in the kitchen.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: isSmall ? 12 : 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String dispId,
    int tableNo,
    List<OrderItemModel> meals,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        "Order $dispId",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF382A15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "In Progress",
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "EST. WAITING TIME",
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: isSmall ? 8 : 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "15-20 min",
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Table $tableNo • ${meals.length} items",
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // Progress line tracker
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF243042),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF243042),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Labels safely expanded to never overflow
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.goldLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Sent to Kitchen",
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: isSmall ? 10 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  "Preparing",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: isSmall ? 10 : 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  "Ready to Serve",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: isSmall ? 10 : 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    List<OrderItemModel> meals,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ORDER OVERVIEW",
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: isSmall ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                "\$${total.toStringAsFixed(2)} Paid",
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: isSmall ? 12 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (meals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  "No meals listed",
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: meals.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final meal = meals[index];
                return Row(
                  children: [
                    Container(
                      width: isSmall ? 32 : 38,
                      height: isSmall ? 32 : 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2838),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: meal.mealImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: meal.mealImage,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.restaurant,
                                  color: AppColors.goldLight,
                                  size: 18,
                                ),
                              )
                            : const Icon(
                                Icons.restaurant,
                                color: AppColors.goldLight,
                                size: 18,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.mealName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmall ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Qty: ${meal.quantity}",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "\$${(meal.unitPrice * meal.quantity).toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmall ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isSmall) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            // Button doesn't have action when pressed, as requested
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldDark,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                "View Order Details",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Colors.black,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _backToMenu(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF141C28),
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: Color(0xFF243042)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            "Back to Menu",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
