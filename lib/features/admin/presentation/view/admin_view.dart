import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../../../auth/presentation/view_model/auth_cubit.dart';
import '../../../menu/data/repositories/menu_repository.dart';
import '../../data/admin_repository.dart';
import '../view_model/admin_orders_cubit.dart';
import '../widgets/admin_widgets.dart';
import 'admin_dashboard.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key, required this.menu, this.repository});

  final MenuRepository menu;
  final AdminDataSource? repository;

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  late final _repository =
      widget.repository ??
      AdminRepository(
        context.read<AuthCubit>().authInstance,
        context.read<AuthCubit>().storeInstance,
      );
  late var _authorization = _repository.watchClaimedAdmin();

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: _authorization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting ||
          snapshot.hasError ||
          snapshot.data == null) {
        return _AdminAccessScreen(
          snapshot: snapshot,
          retryLabel: 'Refresh access',
          retry: () => setState(
            () => _authorization = _repository.watchClaimedAdmin(
              refreshToken: true,
            ),
          ),
        );
      }
      return _AdminProfile(
        key: ValueKey(snapshot.data),
        watchProfile: () => _repository.watchAdminName(snapshot.data!),
        watchOrders: _repository.watchOrders,
        menu: widget.menu,
      );
    },
  );
}

class _AdminProfile extends StatefulWidget {
  const _AdminProfile({
    super.key,
    required this.watchProfile,
    required this.watchOrders,
    required this.menu,
  });

  final Stream<String?> Function() watchProfile;
  final AdminOrderStream watchOrders;
  final MenuRepository menu;

  @override
  State<_AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<_AdminProfile> {
  late var _profile = widget.watchProfile();

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting ||
          snapshot.hasError ||
          snapshot.data == null) {
        return _AdminAccessScreen(
          snapshot: snapshot,
          retry: () => setState(() => _profile = widget.watchProfile()),
        );
      }
      return RepositoryProvider<String>.value(
        value: snapshot.data!,
        child: BlocProvider(
          create: (_) => AdminOrdersCubit(widget.watchOrders)..load(),
          child: _AdminNavigator(menu: widget.menu),
        ),
      );
    },
  );
}

// Keeping the navigator inside the authorization boundary also removes open
// details, management routes, and their dialogs when access is revoked.
class _AdminNavigator extends StatefulWidget {
  const _AdminNavigator({required this.menu});
  final MenuRepository menu;

  @override
  State<_AdminNavigator> createState() => _AdminNavigatorState();
}

class _AdminNavigatorState extends State<_AdminNavigator> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigator.currentState!.maybePop(result),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => AdminDashboard(menu: widget.menu),
      ),
    ),
  );
}

class _AdminAccessScreen extends StatelessWidget {
  const _AdminAccessScreen({
    required this.snapshot,
    required this.retry,
    this.retryLabel = 'Retry',
  });

  final AsyncSnapshot<String?> snapshot;
  final VoidCallback retry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: adminBackground,
    appBar: AppBar(actions: const [LanguageToggle(), AdminLogoutButton()]),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: snapshot.connectionState == ConnectionState.waiting
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  TextButton(onPressed: retry, child: AppText(retryLabel)),
                ],
              )
            : AdminMessage(
                message: snapshot.hasError
                    ? 'Could not verify admin access.'
                    : 'Admin access required.',
                retry: retry,
                retryLabel: retryLabel,
              ),
      ),
    ),
  );
}
