import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import '../../../auth/presentation/view_model/auth_cubit.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../view_model/admin_orders_cubit.dart';

const adminBackground = Color(0xFF101010);
const _surface = Color(0xFF1C1C1C);
const adminBorder = Color(0xFF353535);

class AdminLogoutButton extends StatefulWidget {
  const AdminLogoutButton({super.key});

  @override
  State<AdminLogoutButton> createState() => _AdminLogoutButtonState();
}

class _AdminLogoutButtonState extends State<AdminLogoutButton> {
  bool _busy = false;

  Future<void> _logout() async {
    final auth = context.read<AuthCubit>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final error = context.tr('Could not sign out.');
    setState(() => _busy = true);
    try {
      await auth.logout();
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr('Sign out'),
    onPressed: _busy ? null : _logout,
    icon: const Icon(Icons.logout),
  );
}

class AdminOrderContent extends StatelessWidget {
  const AdminOrderContent({
    super.key,
    required this.state,
    required this.builder,
  });
  final AdminOrdersState state;
  final Widget Function(List<OrderModel>) builder;

  @override
  Widget build(BuildContext context) {
    final orders = state.orders;
    if (orders != null) return builder(orders);
    if (state.failed) {
      return AdminMessage(
        message: 'Could not load orders.',
        retry: context.read<AdminOrdersCubit>().load,
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class AdminMessage extends StatelessWidget {
  const AdminMessage({
    super.key,
    required this.message,
    this.retry,
    this.retryLabel = 'Retry',
  });
  final String message;
  final VoidCallback? retry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(message, textAlign: TextAlign.center),
          if (retry != null)
            TextButton(onPressed: retry, child: AppText(retryLabel)),
        ],
      ),
    ),
  );
}

class AdminPageWidth extends StatelessWidget {
  const AdminPageWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: child,
      ),
    ),
  );
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: adminBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    ),
  );
}

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppText(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class AdminTiles extends StatelessWidget {
  const AdminTiles({
    super.key,
    required this.minimumWidth,
    required this.children,
  });
  final double minimumWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final columns = ((constraints.maxWidth + gap) / (minimumWidth + gap))
          .floor()
          .clamp(1, children.length);
      final tile = (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: tile, child: child),
        ],
      );
    },
  );
}
