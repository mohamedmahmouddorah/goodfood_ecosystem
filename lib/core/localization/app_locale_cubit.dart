import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleCubit extends Cubit<Locale> {
  AppLocaleCubit(this._preferences)
    : super(
        Locale(_preferences.getString(preferenceKey) == 'ar' ? 'ar' : 'en'),
      );

  static const preferenceKey = 'goodfood_language';
  final SharedPreferences _preferences;
  Future<void> _pendingSave = Future.value();

  Future<void> select(String code) async {
    if (code != 'ar' && code != 'en') return;
    emit(Locale(code));
    // Serialize rapid taps so the last choice also wins on disk.
    final save = _pendingSave.then((_) async {
      if (!await _preferences.setString(preferenceKey, code)) {
        throw StateError('Could not save language preference');
      }
    });
    _pendingSave = save.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await save;
  }
}
