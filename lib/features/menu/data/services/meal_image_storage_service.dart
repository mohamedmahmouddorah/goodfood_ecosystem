import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class PickedMealImage {
  const PickedMealImage({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

abstract interface class MealImageStorageService {
  Future<String> upload(PickedMealImage image);

  Future<void> deleteByUrl(String url);
}

class FirebaseMealImageStorageService implements MealImageStorageService {
  FirebaseMealImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static const maxImageSize = 5 * 1024 * 1024;
  static const uploadTimeout = Duration(seconds: 45);
  static const downloadUrlTimeout = Duration(seconds: 15);
  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  final FirebaseStorage _storage;
  final Random _random = Random.secure();

  @override
  Future<String> upload(PickedMealImage image) async {
    final extension = image.extension.toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) {
      throw ArgumentError.value(
        image.extension,
        'extension',
        'Unsupported image format.',
      );
    }
    if (image.bytes.isEmpty || image.bytes.length > maxImageSize) {
      throw ArgumentError.value(
        image.bytes.length,
        'bytes',
        'Invalid image size.',
      );
    }

    final nonce = List.generate(
      12,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final ref = _storage.ref().child(
      'meal-images/${DateTime.now().microsecondsSinceEpoch}_$nonce.$extension',
    );
    final uploadTask = ref.putData(
      image.bytes,
      SettableMetadata(contentType: contentType),
    );
    try {
      await uploadTask.timeout(uploadTimeout);
    } on TimeoutException {
      await uploadTask.cancel();
      rethrow;
    }
    return ref.getDownloadURL().timeout(downloadUrlTimeout);
  }

  @override
  Future<void> deleteByUrl(String url) => _storage.refFromURL(url).delete();
}
