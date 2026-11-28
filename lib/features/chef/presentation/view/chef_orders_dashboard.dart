import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/goodfood_localizations.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../../../orders/presentation/widgets/orders_palette.dart';
import '../../data/repositories/chef_orders_source.dart';
import '../view_model/chef_orders_cubit.dart';
import '../view_model/chef_orders_state.dart';
import '../widgets/chef_order_card.dart';
import 'chef_order_details_screen.dart';
import 'chef_order_history_screen.dart';

class ChefOrdersDashboard extends StatelessWidget {
  const ChefOrdersDashboard({super.key, required this.source});
  final ChefOrdersSource source;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChefOrdersCubit(source)..load(),
    child: const _DashboardBody(),
  );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  static const _labels = ['New Orders', 'My Active Orders', 'Ready Orders'];
  static const _colors = [
    AppColors.primaryGold,
    Color(0xFF29B6E8),
    AppColors.activeGreen,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OrdersPalette.background,
    appBar: AppBar(
      backgroundColor: OrdersPalette.background,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          Icon(
            Icons.restaurant_rounded,
            color: AppColors.primaryGold,
            size: MediaQuery.sizeOf(context).width >= 800 ? 36 : 24,
          ),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'GoodFood',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: MediaQuery.sizeOf(context).width >= 800 ? 32 : 21,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.tr('Order History'),
          icon: const Icon(Icons.history_rounded),
          onPressed: () {
            final cubit = context.read<ChefOrdersCubit>();
            Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const ChefOrderHistoryScreen(),
                ),
              ),
            );
          },
        ),
        const LanguageToggle(),
      ],
    ),
    body: SafeArea(
      top: false,
      child: BlocConsumer<ChefOrdersCubit, ChefOrdersState>(
        listenWhen: (previous, current) =>
            previous.noticeId != current.noticeId && current.notice != null,
        listener: (context, state) {
          if (ModalRoute.of(context)?.isCurrent == false) return;
          showAppSnackBar(
            context,
            message: state.noticeMessage!,
            kind: switch (state.notice) {
              ChefNotice.accepted || ChefNotice.ready => FeedbackKind.success,
              ChefNotice.conflict => FeedbackKind.warning,
              _ => FeedbackKind.error,
            },
          );
        },
        builder: (context, state) {
          final cubit = context.read<ChefOrdersCubit>();
          final queues = state.queues;
          final counts = [
            queues?.incoming.length ?? 0,
            queues?.active.length ?? 0,
            queues?.ready.length ?? 0,
          ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width >= 800 ? 28 : 20,
                  20,
                  MediaQuery.sizeOf(context).width >= 800 ? 28 : 20,
                  84,
                ),
                itemCount:
                    1 +
                    (state.visibleOrders.isEmpty
                        ? 1
                        : state.visibleOrders.length),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Chef Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.sizeOf(context).width >= 800
                                ? 34
                                : 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          'Manage and prepare incoming orders',
                          style: TextStyle(
                            color: OrdersPalette.muted,
                            fontSize: MediaQuery.sizeOf(context).width >= 800
                                ? 16
                                : 14,
                          ),
                        ),
                        if (queues != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            queues.chef.name,
                            style: const TextStyle(color: AppColors.goldLight),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            for (var section = 0; section < 3; section++) ...[
                              if (section > 0) const SizedBox(width: 8),
                              Expanded(
                                child: Material(
                                  color: OrdersPalette.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => cubit.select(
                                      ChefOrdersSection.values[section],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${counts[section]}',
                                            style: TextStyle(
                                              color: _colors[section],
                                              fontSize: 26,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          AppText(
                                            _labels[section],
                                            style: const TextStyle(
                                              color: OrdersPalette.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var section = 0; section < 3; section++)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: ChoiceChip(
                                    selected: state.section.index == section,
                                    selectedColor: AppColors.primaryGold,
                                    backgroundColor: OrdersPalette.surface,
                                    showCheckmark: false,
                                    label: Text(
                                      '${context.tr(_labels[section])} (${counts[section]})',
                                      style: TextStyle(
                                        color: state.section.index == section
                                            ? Colors.black
                                            : OrdersPalette.muted,
                                      ),
                                    ),
                                    onSelected: (_) => cubit.select(
                                      ChefOrdersSection.values[section],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  if (state.status == ChefOrdersStatus.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGold,
                        ),
                      ),
                    );
                  }
                  if (state.status == ChefOrdersStatus.error ||
                      state.status == ChefOrdersStatus.denied) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            state.status == ChefOrdersStatus.denied
                                ? Icons.lock_outline
                                : Icons.cloud_off_outlined,
                            size: 42,
                            color: AppColors.primaryGold,
                          ),
                          const SizedBox(height: 16),
                          AppText(
                            state.status == ChefOrdersStatus.denied
                                ? 'An active, signed-in chef account is required.'
                                : 'Could not load kitchen orders. Check your connection and Firestore permissions.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: OrdersPalette.muted),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: cubit.load,
                            child: const AppText('Try again'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state.visibleOrders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 42,
                            color: AppColors.primaryGold,
                          ),
                          SizedBox(height: 16),
                          AppText(
                            'No orders in this section.',
                            style: TextStyle(color: OrdersPalette.muted),
                          ),
                        ],
                      ),
                    );
                  }
                  final order = state.visibleOrders[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ChefOrderCard(
                      order: order,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: cubit,
                            child: ChefOrderDetailsScreen(orderId: order.docId),
                          ),
                        ),
                      ),
                      assignedChefName: cubit.source.assignmentName(order),
                      busy: state.busyIds.contains(order.docId),
                      onAccept: state.section == ChefOrdersSection.incoming
                          ? () => cubit.accept(order.docId)
                          : null,
                      onReady: state.section == ChefOrdersSection.active
                          ? () => cubit.markReady(order.docId)
                          : null,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}
