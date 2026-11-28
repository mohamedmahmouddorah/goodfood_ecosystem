import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/presentation/widgets/menu_palette.dart';
import '../view_model/admin_orders_cubit.dart';
import '../widgets/admin_widgets.dart';

String adminStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'Pending',
  OrderStatus.preparing => 'Preparing',
  OrderStatus.ready => 'Ready',
  OrderStatus.delivered => 'Delivered',
  OrderStatus.canceled => 'Cancelled',
};

Color adminStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.pending => MenuPalette.gold,
  OrderStatus.preparing => const Color(0xFF46C0F0),
  OrderStatus.ready => MenuPalette.success,
  OrderStatus.delivered => const Color(0xFFC3B3FF),
  OrderStatus.canceled => const Color(0xFFF69E9E),
};

String _dateTime(BuildContext context, DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return context.tr('Unavailable');
  final formats = MaterialLocalizations.of(context);
  final local = date.toLocal();
  return '${formats.formatShortDate(local)} · ${formats.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String _amount(BuildContext context, double amount) {
  final formats = MaterialLocalizations.of(context);
  final parts = amount.abs().toStringAsFixed(2).split('.');
  if (parts.length != 2 || int.tryParse(parts.first) == null) {
    return context.tr('Unavailable');
  }
  final whole = formats.formatDecimal(int.parse(parts.first));
  final fraction = parts.last
      .split('')
      .map((digit) => formats.formatDecimal(int.parse(digit)))
      .join();
  final decimal = Localizations.localeOf(context).languageCode == 'ar'
      ? '٫'
      : '.';
  return '\$${amount < 0 ? '−' : ''}$whole$decimal$fraction';
}

String? _present(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

String _orderId(BuildContext context, OrderModel order) {
  final display = _present(order.dispId);
  return display == null ? context.tr('Order ID unavailable') : '#$display';
}

String _chef(BuildContext context, OrderModel order) =>
    _present(order.acceptedByChefName) ??
    _present(order.acceptedByChefId) ??
    context.tr(order.isUnassigned ? 'Unassigned' : 'Unavailable');

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key, this.kitchenOnly = false});
  final bool kitchenOnly;

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  String _search = '';
  OrderStatus? _status;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: adminBackground,
    appBar: AppBar(
      title: AppText(widget.kitchenOnly ? 'Kitchen Overview' : 'Manage Orders'),
      backgroundColor: adminBackground,
      actions: const [LanguageToggle()],
    ),
    body: AdminPageWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                labelText: context.tr('Search by order ID'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in <OrderStatus?>[
                  null,
                  ...widget.kitchenOnly
                      ? [
                          OrderStatus.pending,
                          OrderStatus.preparing,
                          OrderStatus.ready,
                        ]
                      : OrderStatus.values,
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      selected: _status == status,
                      label: AppText(
                        status == null
                            ? 'All statuses'
                            : adminStatusLabel(status),
                      ),
                      onSelected: (_) => setState(() => _status = status),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<AdminOrdersCubit, AdminOrdersState>(
              builder: (context, state) => AdminOrderContent(
                state: state,
                builder: (_) {
                  final matches = state
                      .matching(
                        _search,
                        _status,
                        kitchenOnly: widget.kitchenOnly,
                      )
                      .toList();
                  if (matches.isEmpty) {
                    return Center(
                      child: AdminMessage(
                        message: _search.trim().isEmpty && _status == null
                            ? (widget.kitchenOnly
                                  ? 'No orders in the kitchen queue.'
                                  : 'No orders yet.')
                            : 'No orders match your search or filter.',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        AdminOrderCard(order: matches[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AdminOrderCard extends StatelessWidget {
  const AdminOrderCard({super.key, required this.order, this.compact = false});
  final OrderModel order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = adminStatusColor(order.status);
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _orderId(context, order),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: status.withValues(alpha: .45)),
                  color: status.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: AppText(
                    adminStatusLabel(order.status),
                    style: TextStyle(
                      color: status,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              AppText(
                'Table ${MaterialLocalizations.of(context).formatDecimal(order.tableNo)}',
              ),
              Text(
                _dateTime(context, order.createdAt),
                style: const TextStyle(color: MenuPalette.muted),
              ),
              if (!compact)
                if (_present(order.clientName) case final String name)
                  Text(name),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${context.tr('Assigned chef')} · ${_chef(context, order)}',
            style: const TextStyle(color: MenuPalette.muted),
          ),
          if (!compact) ...[
            const Divider(color: adminBorder),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _amount(context, order.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _OrderDetails(orderId: order.docId),
                    ),
                  ),
                  child: const AppText('View Details'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: adminBackground,
    appBar: AppBar(
      title: const AppText('Order Details'),
      backgroundColor: adminBackground,
      actions: const [LanguageToggle()],
    ),
    body: AdminPageWidth(
      child: BlocBuilder<AdminOrdersCubit, AdminOrdersState>(
        builder: (context, state) => AdminOrderContent(
          state: state,
          builder: (orders) {
            final order = orders
                .where((order) => order.docId == orderId)
                .firstOrNull;
            if (order == null) {
              return const Center(
                child: AdminMessage(
                  message: 'This order is no longer available.',
                ),
              );
            }
            final formats = MaterialLocalizations.of(context);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AdminOrderCard(order: order, compact: true),
                const SizedBox(height: 16),
                AdminPanel(
                  child: Column(
                    children: [
                      _Detail(
                        'Customer',
                        _present(order.clientName) ?? context.tr('Unavailable'),
                      ),
                      _Detail(
                        'Customer ID',
                        _present(order.customerId) ?? context.tr('Unavailable'),
                      ),
                      _Detail(
                        'Guests',
                        formats.formatDecimal(order.noOfGuests),
                      ),
                      _Detail(
                        'Accepted at',
                        order.acceptedAt == null
                            ? context.tr('Unavailable')
                            : _dateTime(context, order.acceptedAt!),
                      ),
                      _Detail(
                        'Ready at',
                        order.readyAt == null
                            ? context.tr('Unavailable')
                            : _dateTime(context, order.readyAt!),
                      ),
                      if (order.status == OrderStatus.canceled &&
                          _present(order.cancellationReason) != null)
                        _Detail(
                          'Cancellation reason',
                          order.cancellationReason!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const AdminSectionTitle('Ordered items'),
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (order.meals.isEmpty)
                        const AppText('No items recorded.'),
                      for (final item in order.meals)
                        _Detail(
                          item.mealName,
                          '${formats.formatDecimal(item.quantity)} × ${_amount(context, item.unitPrice)}',
                          translate: false,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const AdminSectionTitle('Stored order totals'),
                AdminPanel(
                  child: Column(
                    children: [
                      _Detail('Subtotal', _amount(context, order.subtotal)),
                      _Detail(
                        'Service Charge',
                        _amount(context, order.serviceCharge),
                      ),
                      _Detail('Total', _amount(context, order.total)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value, {this.translate = true});
  final String label;
  final String value;
  final bool translate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(translate ? context.tr(label) : label)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: MenuPalette.muted),
          ),
        ),
      ],
    ),
  );
}
