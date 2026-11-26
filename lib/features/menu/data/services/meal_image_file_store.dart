import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MealImageFileStore {
  static const _directoryName = 'pending_meal_images';
  final Random _random = Random.secure();

  Future<String> save({
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(p.join(supportDirectory.path, _directoryName));
    await directory.create(recursive: true);
    final baseName = _safeBaseName(fileName);
    final nonce = _random.nextInt(1 << 32).toRadixString(16);
    final storedName =
        '${DateTime.now().microsecondsSinceEpoch}_${nonce}_$baseName.$extension';
    final file = File(p.join(directory.path, storedName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> delete(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final supportDirectory = await getApplicationSupportDirectory();
    final directoryPath = p.normalize(
      p.join(supportDirectory.path, _directoryName),
    );
    final normalizedFilePath = p.normalize(filePath);
    if (!p.isWithin(directoryPath, normalizedFilePath)) return;
    final file = File(normalizedFilePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteOrphans(Set<String> activePaths) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(p.join(supportDirectory.path, _directoryName));
    if (!await directory.exists()) return;
    final active = activePaths.map(p.normalize).toSet();
    await for (final entity in directory.list()) {
      if (entity is File && !active.contains(p.normalize(entity.path))) {
        await entity.delete();
      }
    }
  }

  String _safeBaseName(String fileName) {
    final selectedName = fileName
        .replaceAll(String.fromCharCode(92), '/')
        .split('/')
        .last
        .trim();
    final dot = selectedName.lastIndexOf('.');
    final baseName = dot > 0 ? selectedName.substring(0, dot) : selectedName;
    final safeBaseName = baseName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    return safeBaseName.isEmpty ? 'meal' : safeBaseName;
  }
}
