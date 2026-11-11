import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

class ImgBbUploadException implements Exception {
  const ImgBbUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PickedMealImage {
  const PickedMealImage({
    required this.bytes,
    required this.extension,
    this.fileName,
  });

  final Uint8List bytes;
  final String extension;
  final String? fileName;
}

abstract interface class MealImageStorageService {
  Future<String> upload(PickedMealImage image);
  Future<String> uploadLocalMealImage(String localPath, {String? fileName});
}

class ImgBbMealImageStorageService implements MealImageStorageService {
  ImgBbMealImageStorageService({
    String? apiKey,
    Uri? endpoint,
    http.Client? client,
  })  : _apiKey = apiKey ?? _resolveApiKey(),
        _endpoint = endpoint ?? Uri.https('api.imgbb.com', '/1/upload'),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const maxImageSize = 5 * 1024 * 1024;
  static const uploadTimeout = Duration(seconds: 10); // تقليل الـ Timeout لسرعة الاستجابة في الأوفلاين

  static const _configuredApiKey = String.fromEnvironment(
    'IMGBB_API_KEY',
    defaultValue: '9b770d5cddd9e2ca343330a61f11437c',
  );
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final String _apiKey;
  final Uri _endpoint;
  final http.Client _client;
  final bool _ownsClient;

  static String _resolveApiKey() {
    final fromDotEnv = dotenv.env['IMGBB_API_KEY'];
    if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
      return fromDotEnv;
    }
    return _configuredApiKey;
  }

  @override
  Future<String> upload(PickedMealImage image) async {
    final extension = image.extension.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
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
    if (_apiKey.trim().isEmpty) {
      throw const ImgBbUploadException(
        'ImgBB API key is missing. Add IMGBB_API_KEY to your .env or run with --dart-define=IMGBB_API_KEY=your_key.',
      );
    }

    final compressedBytes = await _compressImageBytes(image.bytes, extension);

    return _uploadWithRetry(
      compressedBytes: compressedBytes,
      fileName: image.fileName ?? 'meal.$extension',
    );
  }

  @override
  Future<String> uploadLocalMealImage(
    String localPath, {
    String? fileName,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const ImgBbUploadException('Local image file was not found.');
    }

    final bytes = await file.readAsBytes();
    final ext = _imageExtension(localPath) ?? 'jpg';
    final name = fileName ?? _fileNameFromPath(localPath);

    return upload(
      PickedMealImage(
        bytes: bytes,
        extension: ext,
        fileName: name,
      ),
    );
  }

  Future<Uint8List> _compressImageBytes(
    Uint8List bytes,
    String extension,
  ) async {
    try {
      if (bytes.length < 300 * 1024) return bytes;

      final format = _getCompressFormat(extension);
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: format,
      );
      return compressed;
    } catch (e) {
      debugPrint('Image compression skipped: $e');
      return bytes;
    }
  }

  CompressFormat _getCompressFormat(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg;
    }
  }

  Future<String> _uploadWithRetry({
    required Uint8List compressedBytes,
    required String fileName,
    int maxRetries = 2, // تقليل المحاولات إلى مرتين فقط لتسريع الحفظ الأوفلاين
  }) async {
    int retryCount = 0;
    int delaySeconds = 1;

    while (retryCount < maxRetries) {
      try {
        retryCount++;
        final uploadUri = _endpoint.replace(
          queryParameters: {
            ..._endpoint.queryParameters,
            'key': _apiKey.trim(),
          },
        );

        final request = http.MultipartRequest('POST', uploadUri)
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              compressedBytes,
              filename: fileName,
            ),
          );

        final response = await _client.send(request).timeout(uploadTimeout);
        final responseBody = await response.stream
            .bytesToString()
            .timeout(uploadTimeout);
        final decoded = _decodeResponse(responseBody);

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded?['success'] == true) {
          final data = decoded?['data'];
          final url = data is Map<String, dynamic> ? data['url'] : null;
          if (url is String && url.isNotEmpty) {
            final uri = Uri.tryParse(url);
            if (uri != null &&
                uri.scheme == 'https' &&
                uri.host.isNotEmpty &&
                uri.hasAuthority) {
              return url;
            }
          }
          throw const ImgBbUploadException(
            'ImgBB returned an invalid image URL.',
          );
        }

        final errorMsg = _errorMessage(decoded) ??
            'Image upload failed with status ${response.statusCode}.';

        if (response.statusCode == 400 &&
            errorMsg.toLowerCase().contains('invalid api')) {
          throw ImgBbUploadException(errorMsg);
        }

        if (retryCount >= maxRetries) {
          throw ImgBbUploadException(errorMsg);
        }
      } catch (e) {
        if (e is ImgBbUploadException) rethrow;

        // تنظيف وحجب أي تسريب للـ API Key أو تفاصيل الـ Socket
        if (e is SocketException || e is http.ClientException || e.toString().contains('SocketException')) {
          throw const ImgBbUploadException(
            'No internet connection. Image saved locally and will upload automatically when online.',
          );
        }

        if (retryCount >= maxRetries) {
          throw const ImgBbUploadException(
            'Network error while uploading image. Saved locally.',
          );
        }
      }

      await Future.delayed(Duration(seconds: delaySeconds));
      delaySeconds *= 2;
    }

    throw const ImgBbUploadException(
      'No internet connection. Image saved locally.',
    );
  }

  Map<String, dynamic>? _decodeResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _errorMessage(Map<String, dynamic>? response) {
    final error = response?['error'];
    if (error is String) return error;
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return null;
  }

  String? _imageExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return path.substring(dot + 1).toLowerCase();
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}