import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/localization/app_locale_cubit.dart';
import 'core/localization/goodfood_localizations.dart';
import 'core/firebase/firebase_environment.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/admin/presentation/view/admin_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/login_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/role_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/splash_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/welcome_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';
import 'package:goodfood_ecosystem/features/chef/presentation/view/chef_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/cart_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/checkout_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/customer_details_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/order_confirmed_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/widgets/cart_item.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_cubit.dart';
import 'package:hive_flutter/adapters.dart';

import 'features/menu/data/repositories/menu_repository.dart';
import 'features/menu/data/services/menu_cache_factory.dart';
import 'features/menu/data/services/menu_remote_service.dart';
import 'features/menu/presentation/view/menu_screen.dart';
import 'features/orders/presentation/view/customer_orders_screen.dart';
import 'features/orders/data/repositories/customer_orders_repository.dart';
import 'features/orders/data/services/customer_order_tracking.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env file not found or empty: $e');
  }

  await FirebaseEnvironment.initialize();

  await Hive.initFlutter();
  Hive.registerAdapter(OrderItemModelAdapter());
  Box<OrderItemModel> cartBox = await Hive.openBox<OrderItemModel>(
    FirebaseEnvironment.useEmulators ? 'cartBox_chef_emulator' : 'cartBox',
  );

  final repository = MenuRepository(
    MenuRemoteService(FirebaseEnvironment.store),
    mealLocalCache: FirebaseEnvironment.useEmulators
        ? null
        : createMenuLocalCache(),
  );

  repository.startSync();

  final cartRepositry = CartRepo(cartBox: cartBox);
  final localeCubit = AppLocaleCubit(await SharedPreferences.getInstance());
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthCubit()),
        BlocProvider(create: (_) => localeCubit),
      ],
      child: MyApp(repository: repository, cartRepo: cartRepositry),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository, required this.cartRepo});

  final MenuRepository repository;
  final CartRepo cartRepo;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goodfood EcoSystem',
      locale: context.watch<AppLocaleCubit>().state,
      supportedLocales: GoodFoodLocalizations.supportedLocales,
      localizationsDelegates: const [
        GoodFoodLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: context.watch<AppLocaleCubit>().state.languageCode == 'ar'
            ? 'NotoSansArabic'
            : 'Arimo',
        fontFamilyFallback: const ['NotoSansArabic'],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B84A),
          brightness: Brightness.dark,
        ),
      ),
      routes: {
        '/orders': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          return CustomerOrdersScreen(
            loadOrders: () => FirebaseEnvironment.useEmulators
                ? CustomerOrdersRepository(
                    FirebaseEnvironment.store,
                  ).watchSignedInCustomerOrders(FirebaseEnvironment.auth)
                : CustomerOrdersRepository(
                    FirebaseEnvironment.store,
                  ).watchTrackedOrders(
                    tracking: CustomerOrderTracking.forCurrentDevice(),
                    extraIds: arguments is List<String> ? arguments : const [],
                  ),
          );
        },
        '/admin': (context) => AdminView(menu: repository),
        '/chef': (context) => ChefView(),
        '/login': (context) => LoginView(),
        '/welcome': (context) => WelcomeView(),
        '/role_selection': (context) => RoleView(),
        '/customer_details': (context) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => CustomerOrderCubit()),
            BlocProvider(create: (context) => MenuCubit(repository)),
            BlocProvider(create: (context) => CartCubit(repo: cartRepo)),
          ],
          child: CustomerDetailsView(),
        ),
        '/menu': (context) =>
            MenuScreen(repository: repository, repo: cartRepo),
        '/cart': (context) => CartView(repository: repository),
        '/checkout': (context) =>
            CheckoutView(repository: repository, cartRepo: cartRepo),
        '/order_confirmed': (context) =>
            OrderConfirmedView(repository: repository, cartRepo: cartRepo),
      },
      home: SplashView(),
    );
  }
}
