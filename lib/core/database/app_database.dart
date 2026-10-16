import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _factoryReady = false;

Future<Database> openAppDatabase({
  required String fileName,
  required OnDatabaseCreateFn onCreate,
  String? path,
}) async {
  _initFactory();
  final databasePath = path ?? await _defaultPath(fileName);
  return databaseFactory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(version: 1, onCreate: onCreate),
  );
}

void _initFactory() {
  if (_factoryReady) return;
  if (kIsWeb) {
    throw UnsupportedError('SQLite storage is not supported on web.');
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else if (Platform.isAndroid || Platform.isIOS) {
    databaseFactory = sqflite.databaseFactorySqflitePlugin;
  }
  _factoryReady = true;
}

Future<String> _defaultPath(String fileName) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return p.join(directory.path, fileName);
}