import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/admin/presentation/view/admin_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/customer_details_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/login_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/role_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/splash_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/welcome_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/chef/presentation/view/chef_view.dart';

import 'features/menu/data/repositories/menu_repository.dart';
import 'features/menu/data/services/meal_local_cache.dart';
import 'features/menu/data/services/menu_remote_service.dart';
import 'features/menu/presentation/view/menu_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Built once, not inside build().
  final repository = MenuRepository(
    MenuRemoteService(FirebaseFirestore.instance),
    mealLocalCache: SqliteMealLocalCache(),
  );
  runApp(
    BlocProvider(
      create: (context) => AuthCubit(),
      child: MyApp(repository: repository),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});

  final MenuRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goodfood EcoSystem',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "Arimo",
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B84A),
          brightness: Brightness.dark,
        ),
      ),
      routes: {
        '/admin': (context) => AdminView(),
        '/chef': (context) => ChefView(),
        '/login':(context) => LoginView(),
        '/welcome':(context) => WelcomeView(),
        '/role_selection' : (context) => RoleView()
      },
      home: SplashView(),
    );
  }
}
