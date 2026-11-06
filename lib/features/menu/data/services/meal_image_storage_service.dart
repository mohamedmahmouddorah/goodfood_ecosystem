import 'dart:convert';
import 'dart:typed_data';

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
}

class ImgBbMealImageStorageService implements MealImageStorageService {
  ImgBbMealImageStorageService({
    String? apiKey,
    Uri? endpoint,
    http.Client? client,
  }) : _apiKey = apiKey ?? _configuredApiKey,
       _endpoint = endpoint ?? Uri.https('api.imgbb.com', '/1/upload'),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const maxImageSize = 5 * 1024 * 1024;
  static const uploadTimeout = Duration(seconds: 60);
  static const _configuredApiKey = String.fromEnvironment('IMGBB_API_KEY');
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final String _apiKey;
  final Uri _endpoint;
  final http.Client _client;
  final bool _ownsClient;

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
        'ImgBB API key is missing. Run with --dart-define=IMGBB_API_KEY=your_key.',
      );
    }

    final uploadUri = _endpoint.replace(
      queryParameters: {..._endpoint.queryParameters, 'key': _apiKey.trim()},
    );
    final request = http.MultipartRequest('POST', uploadUri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          image.bytes,
          filename: image.fileName ?? 'meal.$extension',
        ),
      );
    final response = await _client.send(request).timeout(uploadTimeout);
    final responseBody = await response.stream.bytesToString().timeout(
      uploadTimeout,
    );
    final decoded = _decodeResponse(responseBody);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded?['success'] != true) {
      throw ImgBbUploadException(
        _errorMessage(decoded) ??
            'Image upload failed with status ${response.statusCode}.',
      );
    }

    final data = decoded?['data'];
    final url = data is Map<String, dynamic> ? data['url'] : null;
    if (url is! String) {
      throw const ImgBbUploadException('ImgBB returned an invalid image URL.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !uri.hasAuthority) {
      throw const ImgBbUploadException('ImgBB returned an invalid image URL.');
    }
    return url;
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

  void close() {
    if (_ownsClient) _client.close();
  }
}
