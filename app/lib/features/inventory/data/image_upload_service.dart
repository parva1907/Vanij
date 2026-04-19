import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/firebase_providers.dart';

/// Compresses a raw camera/gallery image to WebP (per the spec's
/// "compress to WebP before upload" rule) and uploads it to
/// `merchants/{uid}/inventory/{filename}.webp`.
///
/// The Cloud Storage rules (owner-scoped, `image/.*` content type,
/// <5 MB) are enforced server-side regardless of this code.
class ImageUploadService {
  ImageUploadService({
    required FirebaseStorage storage,
    required FirebaseAuth auth,
  }) : _storage = storage,
       _auth = auth;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  /// Max dimension (in logical pixels) for stored photos. 1280 is ample
  /// for a product card thumbnail while keeping the APK + bandwidth
  /// budget tight.
  static const int _maxEdgePx = 1280;

  /// WebP quality (0–100). 75 is a well-established sweet spot for
  /// photographs — visibly lossless, ~5–10× smaller than JPEG Q85.
  static const int _webpQuality = 75;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('ImageUploadService requires a signed-in user.');
    }
    return uid;
  }

  /// Compresses [sourceFile] to WebP, writes a temp copy, and returns
  /// the compressed file. The caller is responsible for deleting it
  /// once the upload succeeds or fails.
  Future<File> _compress(File sourceFile) async {
    final tmpDir = await getTemporaryDirectory();
    final outPath =
        '${tmpDir.path}/vanij_${DateTime.now().microsecondsSinceEpoch}.webp';
    final result = await FlutterImageCompress.compressAndGetFile(
      sourceFile.absolute.path,
      outPath,
      format: CompressFormat.webp,
      quality: _webpQuality,
      minWidth: _maxEdgePx,
      minHeight: _maxEdgePx,
    );
    if (result == null) {
      throw StateError('Image compression failed.');
    }
    return File(result.path);
  }

  /// Uploads [sourceFile] and returns a public download URL.
  ///
  /// [itemId] is reused across edits so a replacement image overwrites
  /// the previous one (avoids orphaned blobs).
  Future<String> uploadInventoryImage({
    required File sourceFile,
    required String itemId,
  }) async {
    final uid = _requireUid();
    final compressed = await _compress(sourceFile);
    try {
      final ref = _storage.ref().child('merchants/$uid/inventory/$itemId.webp');
      final task = await ref.putFile(
        compressed,
        SettableMetadata(
          contentType: 'image/webp',
          cacheControl: 'public,max-age=2592000',
        ),
      );
      return task.ref.getDownloadURL();
    } finally {
      // Best-effort cleanup of the WebP temp file. Leaving it behind
      // would leak ~100 KB–1 MB per upload on a device with limited
      // storage. Failures here are ignored — the temp dir is pruned by
      // the OS anyway.
      try {
        if (await compressed.exists()) {
          await compressed.delete();
        }
      } on Object {
        // ignore
      }
    }
  }
}

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(
    storage: ref.watch(firebaseStorageProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
