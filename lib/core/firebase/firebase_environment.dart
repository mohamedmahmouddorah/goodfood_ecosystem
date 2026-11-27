import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Opt-in local mode. A demo project ID prevents accidental production access.
abstract final class FirebaseEnvironment {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const useOwnedCustomerOrders =
      useEmulators || bool.fromEnvironment('USE_OWNED_CUSTOMER_ORDERS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const demoProjectId = 'demo-goodfood-chef';
  // A named demo app avoids Android's automatically initialized production app.
  static FirebaseApp get app =>
      useEmulators ? Firebase.app(demoProjectId) : Firebase.app();
  static FirebaseAuth get auth =>
      useEmulators ? FirebaseAuth.instanceFor(app: app) : FirebaseAuth.instance;
  static FirebaseFirestore get store => useEmulators
      ? FirebaseFirestore.instanceFor(app: app)
      : FirebaseFirestore.instance;

  static Future<void> initialize() async {
    if (useEmulators && !kDebugMode) {
      throw StateError(
        'The local Firebase emulator mode requires a debug build.',
      );
    }
    // FlutterFire Web restores the emulator before cached Auth initialization
    // only on localhost. A different hostname may invalidate an emulator token
    // before useAuthEmulator is reached. Fail before initializing any SDK.
    if (useEmulators && kIsWeb && Uri.base.host != 'localhost') {
      throw StateError(
        'Open the local emulator app at http://localhost, not an IP address.',
      );
    }
    await Firebase.initializeApp(
      name: useEmulators ? demoProjectId : null,
      options: useEmulators
          ? const FirebaseOptions(
              apiKey: 'demo-api-key',
              appId: kIsWeb
                  ? '1:123456789:web:1234567890abcdef'
                  : '1:123456789:android:1234567890abcdef',
              messagingSenderId: '123456789',
              projectId: demoProjectId,
            )
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (useEmulators) {
      store.useFirestoreEmulator(
        emulatorHost,
        8787,
        automaticHostMapping: false,
      );
      await auth.useAuthEmulator(
        emulatorHost,
        9099,
        automaticHostMapping: false,
      );
    }
    store.settings = Settings(persistenceEnabled: !useEmulators);
  }
}
