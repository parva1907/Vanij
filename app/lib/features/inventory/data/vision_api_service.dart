import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../common/config/app_config.dart';
import '../../../core/providers/firebase_providers.dart';
import 'models/vision_tag_draft.dart';

/// Client for `POST /v1/vision/tag` on the Vanij Python backend.
///
/// Security:
///   * Authorization is a short-lived Firebase ID token, forced to refresh
///     every call so a replayed stale token can't sneak through.
///   * Nothing is ever logged beyond the HTTP status + backend name.
///   * The caller is expected to pass an already-compressed WebP file —
///     we never re-compress here, and we honour the 5 MB server cap so
///     errors surface before the bytes leave the device.
class VisionApiService {
  VisionApiService({
    required FirebaseAuth auth,
    required String backendUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
  }) : _auth = auth,
       _backendUrl = backendUrl,
       _client = client ?? http.Client(),
       _timeout = timeout;

  final FirebaseAuth _auth;
  final String _backendUrl;
  final http.Client _client;
  final Duration _timeout;

  /// Matches `Settings.max_image_bytes` on the backend.
  static const int maxImageBytes = 5 * 1024 * 1024;

  Future<String> _requireIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('VisionApiService requires a signed-in user.');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('Firebase returned an empty ID token.');
    }
    return token;
  }

  /// Calls the tagger and returns the draft candidates.
  ///
  /// [imageFile] should be the compressed WebP on disk. [contentType]
  /// defaults to `image/webp` because that's what `ImageUploadService`
  /// produces — override for tests.
  Future<VisionTagDraft> tagImage({
    required File imageFile,
    String contentType = 'image/webp',
  }) async {
    final length = await imageFile.length();
    if (length == 0) {
      throw ArgumentError('Cannot tag an empty image.');
    }
    if (length > maxImageBytes) {
      throw ArgumentError(
        'Image is $length bytes — exceeds the $maxImageBytes-byte cap.',
      );
    }

    final token = await _requireIdToken();
    final uri = Uri.parse('$_backendUrl/v1/vision/tag');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType.parse(contentType),
        ),
      );

    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Unexpected response shape from vision tagger.',
          response.body,
        );
      }
      return VisionTagDraft.fromJson(decoded);
    }

    throw VisionApiException(
      statusCode: response.statusCode,
      message: _extractDetail(response.body) ?? 'vision tagger error',
    );
  }

  String? _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      // FastAPI not in the loop (e.g. a plain-text gateway error) —
      // fall through to the default.
    }
    return null;
  }
}

class VisionApiException implements Exception {
  VisionApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'VisionApiException($statusCode): $message';
}

final visionApiServiceProvider = Provider<VisionApiService>((ref) {
  AppConfig.instance.assertConfigured();
  return VisionApiService(
    auth: ref.watch(firebaseAuthProvider),
    backendUrl: AppConfig.instance.pythonBackendUrl,
  );
});
