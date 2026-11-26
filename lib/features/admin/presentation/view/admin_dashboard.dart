import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../../../chef_management/presentation/view/chef_management_screen.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/data/repositories/menu_repository.dart';
import '../../../menu/presentation/view/menu_management_screen.dart';
import '../../../menu/presentation/widgets/menu_palette.dart';
import '../view_model/admin_orders_cubit.dart';
import 'admin_orders_view.dart';
import '../widgets/admin_widgets.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.menu});

  final MenuRepository menu;

  @override
  Widget build(BuildContext context) {
    final name = context.watch<String>();
    final date = MaterialLocalizations.of(
      context,
    ).formatFullDate(DateTime.now());
    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminBackground,
        title: const Text('GoodFood'),
        leading: const Icon(Icons.restaurant, color: MenuPalette.gold),
        actions: const [LanguageToggle(), AdminLogoutButton()],
      ),
      body: AdminPageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(date, style: const TextStyle(color: MenuPalette.muted)),
            const SizedBox(height: 8),
            AppText(
              'GoodFood Admin Dashboard',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            AppText(name.isEmpty ? 'Welcome' : 'Welcome, $name'),
            const SizedBox(height: 24),
            BlocBuilder<AdminOrdersCubit, AdminOrdersState>(
              builder: (context, state) => AdminOrderContent(
                state: state,
                builder: (orders) =>
                    _Metrics(state: state, total: orders.length),
              ),
            ),
            const SizedBox(height: 24),
            const AdminSectionTitle('Quick actions'),
            AdminTiles(
              minimumWidth: 215,
              children: [
                _Action(
                  'Manage Orders',
                  Icons.receipt_long_outlined,
                  const AdminOrdersView(),
                ),
                _Action(
                  'Manage Menu',
                  Icons.restaurant_menu,
                  MenuManagementScreen(repository: menu),
                ),
                _Action(
                  'Manage Chefs',
                  Icons.people_outline,
                  const ChefManagementScreen(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            BlocBuilder<AdminOrdersCubit, AdminOrdersState>(
              builder: (context, state) {
                if (state.orders == null) return const SizedBox.shrink();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final recent = _OrderSection(
                      title: 'Recent Orders',
                      orders: state.orders!.take(5),
                      empty: 'No orders yet.',
                    );
                    final kitchen = _OrderSection(
                      title: 'Kitchen Overview',
                      orders: state.kitchen,
                      empty: 'No orders in the kitchen queue.',
                      compact: true,
                    );
                    if (constraints.maxWidth < 840) {
                      return Column(
                        children: [recent, const SizedBox(height: 24), kitchen],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: recent),
                        const SizedBox(width: 16),
                        Expanded(child: kitchen),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.state, required this.total});
  final AdminOrdersState state;
  final int total;

  @override
  Widget build(BuildContext context) => AdminTiles(
    minimumWidth: 145,
    children: [
      _Metric('Total Orders', total, MenuPalette.gold),
      _Metric(
        'Pending',
        state.count(OrderStatus.pending),
        adminStatusColor(OrderStatus.pending),
      ),
      _Metric(
        'Preparing',
        state.count(OrderStatus.preparing),
        adminStatusColor(OrderStatus.preparing),
      ),
      _Metric(
        'Ready',
        state.count(OrderStatus.ready),
        adminStatusColor(OrderStatus.ready),
      ),
      _Metric(
        'Delivered',
        state.count(OrderStatus.delivered),
        adminStatusColor(OrderStatus.delivered),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        Text(
          MaterialLocalizations.of(context).formatDecimal(value),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.destination);
  final String label;
  final IconData icon;
  final Widget destination;

  @override
  Widget build(BuildContext context) => AdminPanel(
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination)),
    child: Row(
      children: [
        Icon(icon, color: MenuPalette.gold),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const Icon(Icons.arrow_forward, size: 18),
      ],
    ),
  );
}

class _OrderSection extends StatelessWidget {
  const _OrderSection({
    required this.title,
    required this.orders,
    required this.empty,
    this.compact = false,
  });
  final String title;
  final Iterable<OrderModel> orders;
  final String empty;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminSectionTitle(title),
      if (orders.isEmpty) AdminPanel(child: AdminMessage(message: empty)),
      for (final order in orders.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AdminOrderCard(order: order, compact: compact),
        ),
      if (compact && orders.skip(5).isNotEmpty)
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminOrdersView(kitchenOnly: true),
            ),
          ),
          child: const AppText('View kitchen queue'),
        ),
    ],
  );
}
