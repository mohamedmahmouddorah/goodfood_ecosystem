import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view/login_view.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';

import 'customer_identity_integration_test.dart' show IdentityAuth;

void main() {
  for (final code in ['en', 'ar']) {
    testWidgets(
      'login validates the field and shows a failed login inline $code',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final auth = _LoginAuth();
        final cubit = AuthCubit(auth: auth, store: FakeFirebaseFirestore());
        addTearDown(auth.changes.close);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(code),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GoodFoodLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: BlocProvider.value(value: cubit, child: LoginView()),
          ),
        );
        final fields = find.byType(TextFormField);
        final submit = find.byType(ElevatedButton);
        await tester.enterText(fields.first, 'invalid');
        await tester.enterText(fields.last, 'password');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        final context = tester.element(fields.first);
        final validation = find.text(
          context.tr('Please enter a valid email address'),
        );
        expect(validation, findsOneWidget);
        expect(
          tester.getTopLeft(validation).dy,
          greaterThan(tester.getTopLeft(fields.first).dy),
        );
        expect(auth.attempts, 0);

        await tester.enterText(fields.first, 'staff@example.test');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        final error = find.byType(AppInlineFeedback);
        expect(error, findsOneWidget);
        await tester.ensureVisible(error);
        expect(
          tester.getBottomLeft(error).dy,
          lessThan(tester.getTopLeft(submit).dy),
        );
        expect(tester.getBottomLeft(error).dy, lessThan(390));
        expect(
          Directionality.of(tester.element(error)),
          code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(auth.attempts, 1);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _LoginAuth extends IdentityAuth {
  int attempts = 0;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    attempts++;
    throw FirebaseAuthException(code: 'invalid-credential');
  }
}
