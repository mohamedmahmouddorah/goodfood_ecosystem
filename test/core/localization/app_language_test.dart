import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/localization/app_locale_cubit.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/welcome_view.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/add_edit_meal_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/meal_details_screen.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view/customer_orders_screen.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view_models/orders_cubit.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view_models/orders_state.dart';

Widget app(AppLocaleCubit cubit, {Widget? home}) => BlocProvider.value(
  value: cubit,
  child: BlocBuilder<AppLocaleCubit, Locale>(
    builder: (context, locale) => MaterialApp(
      locale: locale,
      supportedLocales: GoodFoodLocalizations.supportedLocales,
      localizationsDelegates: const [
        GoodFoodLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home ?? const WelcomeView(),
      routes: {
        '/customer_details': (_) =>
            CustomerOrdersScreen(loadOrders: () => Stream.value([])),
      },
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores preference and last rapid selection persists', () async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = AppLocaleCubit(prefs);
    addTearDown(cubit.close);
    expect(cubit.state.languageCode, 'en');
    await Future.wait([
      cubit.select('ar'),
      cubit.select('en'),
      cubit.select('ar'),
    ]);
    final restored = AppLocaleCubit(await SharedPreferences.getInstance());
    addTearDown(restored.close);
    expect(restored.state.languageCode, 'ar');
    await cubit.select('invalid');
    expect(cubit.state.languageCode, 'ar');
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('global switch preserves navigation and tab at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final cubit = AppLocaleCubit(prefs);
      addTearDown(cubit.close);
      await tester.pumpWidget(app(cubit));
      await tester.pumpAndSettle();
      expect(find.text('Start Ordering'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'English welcome');
      final originalAR = tester.getCenter(find.text('AR'));
      expect(originalAR.dx, lessThan(tester.getCenter(find.text('EN')).dx));
      await tester.tap(find.text('AR'));
      await tester.pumpAndSettle();
      expect(find.text('ابدأ الطلب'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Arabic welcome');
      expect(
        Directionality.of(tester.element(find.text('ابدأ الطلب'))),
        TextDirection.rtl,
      );
      expect(
        tester.getCenter(find.text('AR')).dx,
        lessThan(tester.getCenter(find.text('EN')).dx),
      );
      final selected = tester.widget<Container>(
        find
            .ancestor(of: find.text('AR'), matching: find.byType(Container))
            .first,
      );
      expect(
        (selected.decoration! as BoxDecoration).color,
        AppColors.primaryGold,
      );

      await tester.tap(find.text('ابدأ الطلب'));
      await tester.pumpAndSettle();
      expect(find.text('طلباتك'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Arabic orders');
      await tester.tap(find.text('سجل الطلبات'));
      await tester.pumpAndSettle();
      final ordersCubit = tester
          .element(find.byType(ListView))
          .read<OrdersCubit>();
      expect(ordersCubit.state.tab, OrdersTab.history);
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Your orders'), findsOneWidget);
      expect(find.text('No order history yet'), findsOneWidget);
      expect(
        tester.element(find.byType(ListView)).read<OrdersCubit>(),
        same(ordersCubit),
      );
      expect(
        Directionality.of(tester.element(find.text('Your orders'))),
        TextDirection.ltr,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Start Ordering'), findsOneWidget);
      expect(cubit.state.languageCode, 'en');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stored Arabic initializes built-in widgets and form hints', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppLocaleCubit.preferenceKey: 'ar',
    });
    final cubit = AppLocaleCubit(await SharedPreferences.getInstance());
    addTearDown(cubit.close);
    await tester.pumpWidget(app(cubit));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('ابدأ الطلب'));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(MaterialLocalizations.of(context).backButtonTooltip, 'رجوع');
    expect(context.tr('Table 7 • 2 items'), 'الطاولة 7 • 2 أصناف');
    expect(context.tr('Qty: 2'), 'الكمية: 2');
    expect(
      context.tr('A customer-supplied meal name'),
      'A customer-supplied meal name',
    );
  });

  testWidgets('Arabic meal editor keeps input and fits a narrow AppBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = AppLocaleCubit(await SharedPreferences.getInstance());
    addTearDown(cubit.close);
    await tester.pumpWidget(app(cubit, home: const AddEditMealScreen()));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('meal-name'));
    await tester.enterText(name, 'Customer supplied meal');
    await tester.tap(find.text('AR'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة وجبة'), findsOneWidget);
    expect(find.text('Customer supplied meal'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: name, matching: find.byType(TextField)),
          )
          .decoration!
          .hintText,
      'مثال: دجاج مشوي',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Arabic details keep server data unchanged and translate actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = AppLocaleCubit(await SharedPreferences.getInstance());
      addTearDown(cubit.close);
      await cubit.select('ar');
      await tester.pumpWidget(
        app(
          cubit,
          home: MealDetailsScreen(
            meal: const MealModel(
              id: 'test',
              name: 'Ready',
              category: MealCategory.mainCourse,
              price: 10,
              imageUrl: '',
              description: 'Original description',
            ),
            onAdd: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Original description'), findsOneWidget);
      expect(find.text('تفاصيل الوجبة'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('أضف إلى السلة'), 200);
      expect(tester.takeException(), isNull);
    },
  );
}
