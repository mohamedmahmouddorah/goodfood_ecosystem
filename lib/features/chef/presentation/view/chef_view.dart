import 'package:goodfood_ecosystem/core/firebase/firebase_environment.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/chef_orders_repository.dart';
import '../../data/repositories/chef_orders_source.dart';
import 'chef_orders_dashboard.dart';

/// The existing /chef route uses real Auth and Firestore by default.
class ChefView extends StatelessWidget {
  const ChefView({super.key, this.source});
  final ChefOrdersSource? source;

  @override
  Widget build(BuildContext context) => ChefOrdersDashboard(
    source:
        source ??
        ChefOrdersRepository(
          store: FirebaseEnvironment.store,
          auth: FirebaseEnvironment.auth,
        ),
  );
}
