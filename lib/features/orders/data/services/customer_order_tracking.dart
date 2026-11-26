import 'package:goodfood_ecosystem/core/firebase/firebase_environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device continuity only. These IDs confer no authorization or ownership.
/// Kept separate per Firebase project and signed-in principal (or guest device).
class CustomerOrderTracking {
  CustomerOrderTracking({
    required this.scope,
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  factory CustomerOrderTracking.forCurrentDevice() => CustomerOrderTracking(
    scope:
        '${FirebaseEnvironment.app.options.projectId}:'
        '${FirebaseEnvironment.auth.currentUser?.uid ?? 'guest-device'}',
  );

  final String scope;
  final Future<SharedPreferences> Function() _preferences;
  String get _key => 'customer_order_documents_v1:$scope';
  static Future<void> _writes = Future.value();

  Future<List<String>> readIds() async {
    await _writes;
    final prefs = await _preferences();
    await prefs.reload();
    return List.unmodifiable(prefs.getStringList(_key) ?? <String>[]);
  }

  /// Call only after a successful server write and permitted server read.
  Future<void> rememberReadableOrder(String documentId) {
    if (documentId.isEmpty || documentId.contains('/')) {
      throw ArgumentError.value(documentId, 'documentId');
    }
    final write = _writes.then((_) async {
      final prefs = await _preferences();
      await prefs.reload();
      final ids = {...?prefs.getStringList(_key), documentId}.toList();
      if (!await prefs.setStringList(_key, ids)) {
        throw StateError('Could not save order tracking on this device.');
      }
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
