import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/goodfood_localizations.dart';
import '../../../orders/presentation/widgets/orders_palette.dart';
import '../view_model/chef_orders_cubit.dart';
import '../view_model/chef_orders_state.dart';
import '../widgets/chef_order_card.dart';
import 'chef_order_details_screen.dart';

class ChefOrderHistoryScreen extends StatelessWidget {
  const ChefOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OrdersPalette.background,
    appBar: AppBar(
      backgroundColor: OrdersPalette.background,
      foregroundColor: AppColors.textWhite,
      title: const AppText('Order History'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: BlocBuilder<ChefOrdersCubit, ChefOrdersState>(
            builder: (context, state) {
              final cubit = context.read<ChefOrdersCubit>();
              final orders = state.queues?.history ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const AppText(
                    'Order History',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const AppText(
                    'Orders you have finished preparing',
                    style: TextStyle(color: OrdersPalette.muted),
                  ),
                  const SizedBox(height: 16),
                  if (state.status == ChefOrdersStatus.loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGold,
                        ),
                      ),
                    )
                  else if (state.status == ChefOrdersStatus.denied)
                    const AppText(
                      'An active, signed-in chef account is required.',
                      style: TextStyle(color: OrdersPalette.muted),
                    )
                  else if (state.status == ChefOrdersStatus.error) ...[
                    const AppText(
                      'Could not load kitchen orders. Check your connection and Firestore permissions.',
                      style: TextStyle(color: OrdersPalette.muted),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton(
                        onPressed: cubit.load,
                        child: const AppText('Try again'),
                      ),
                    ),
                  ] else if (orders.isEmpty)
                    _emptyState()
                  else
                    for (final order in orders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ChefOrderCard(
                          order: order,
                          historySummary: true,
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: cubit,
                                child: ChefOrderDetailsScreen(
                                  orderId: order.docId,
                                  historyOnly: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _emptyState() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(Icons.history_rounded, color: AppColors.primaryGold, size: 42),
        SizedBox(height: 12),
        AppText(
          'No order history yet',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        AppText(
          'Your completed kitchen orders will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: OrdersPalette.muted),
        ),
      ],
    ),
  );
}
