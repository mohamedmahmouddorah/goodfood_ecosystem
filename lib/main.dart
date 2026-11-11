import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/menu/data/repositories/menu_repository.dart';
import 'features/menu/data/services/meal_local_cache.dart';
import 'features/menu/data/services/menu_remote_service.dart';
import 'features/menu/presentation/view/menu_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env file not found or empty: $e');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  final repository = MenuRepository(
    MenuRemoteService(FirebaseFirestore.instance),
    mealLocalCache: SqliteMealLocalCache(),
  );

  
  repository.startSync();

  runApp(MyApp(repository: repository));
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B84A),
          brightness: Brightness.dark,
        ),
      ),
      home: MenuScreen(repository: repository),
    );
  }
}