import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goodfood_ecosystem/core/localization/app_locale_cubit.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/menu_remote_service.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/menu_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/meal_card.dart';

// UI fixtures are test-only. Production uses the existing Firestore repository.
class MenuFixtureRemote implements MenuRemoteService {
  @override
  Stream<RemoteMealsSnapshot> watchAvailable() => Stream.value(
    const RemoteMealsSnapshot(
      meals: [
        MealModel(
          id: 'salad',
          name: 'Garden Salad',
          category: MealCategory.starters,
          price: 8.5,
          imageUrl: '',
          description: 'Fresh vegetables with a light dressing',
        ),
        MealModel(
          id: 'main',
          name: 'Grilled Chicken',
          category: MealCategory.mainCourse,
          price: 14,
          imageUrl: '',
          description: 'Prepared to order',
        ),
      ],
      isFromCache: false,
      hasPendingWrites: false,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmptyCart implements CartRepo {
  @override
  List<OrderItemModel> getAllItems() => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final code in ['ar', 'en']) {
    for (final width in [320.0, 390.0, 430.0, 1280.0]) {
      testWidgets(
        'customer menu $code fits $width and filters actual repository results',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            AppLocaleCubit.preferenceKey: code,
          });
          final locale = AppLocaleCubit(await SharedPreferences.getInstance());
          addTearDown(locale.close);
          await tester.pumpWidget(
            BlocProvider.value(
              value: locale,
              child: BlocBuilder<AppLocaleCubit, Locale>(
                builder: (context, value) => MaterialApp(
                  locale: value,
                  supportedLocales: GoodFoodLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    GoodFoodLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  routes: {
                    '/orders': (_) =>
                        const Scaffold(body: Text('Orders route')),
                  },
                  home: MenuScreen(
                    repository: MenuRepository(MenuFixtureRemote()),
                    repo: EmptyCart(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(MealCard), findsNWidgets(2));
          expect(
            tester.getCenter(find.text('AR')).dx,
            lessThan(tester.getCenter(find.text('EN')).dx),
          );
          await tester.enterText(find.byType(TextField), '  GARDEN ');
          await tester.pumpAndSettle(const Duration(milliseconds: 200));
          expect(find.byType(MealCard), findsOneWidget);
          expect(find.text('Garden Salad'), findsOneWidget);
          await tester.tap(
            find.byTooltip(code == 'ar' ? 'مسح البحث' : 'Clear search'),
          );
          await tester.pumpAndSettle(const Duration(milliseconds: 200));
          expect(find.byType(MealCard), findsNWidgets(2));
          await tester.tap(find.text(code == 'ar' ? 'المقبلات' : 'Starters'));
          await tester.pumpAndSettle();
          expect(find.byType(MealCard), findsOneWidget);
          await tester.tap(find.text(code == 'ar' ? 'الطلبات' : 'Orders'));
          await tester.pumpAndSettle();
          expect(find.text('Orders route'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
