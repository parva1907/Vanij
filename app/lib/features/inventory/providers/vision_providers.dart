import 'dart:async';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/vision_tag_draft.dart';
import '../data/vision_api_service.dart';

/// Compresses [raw] to WebP on the caller's behalf before handing it
/// to the vision tagger. Mirrors `ImageUploadService._compress` so the
/// server sees the same byte budget regardless of flow.
///
/// Kept as a top-level helper so tests can override it by injecting a
/// stub ``VisionApiService``.
Future<File> compressForTagging(File raw) async {
  final tmpDir = await getTemporaryDirectory();
  final outPath =
      '${tmpDir.path}/vanij_tag_${DateTime.now().microsecondsSinceEpoch}.webp';
  final result = await FlutterImageCompress.compressAndGetFile(
    raw.absolute.path,
    outPath,
    format: CompressFormat.webp,
    quality: 75,
    minWidth: 1280,
    minHeight: 1280,
  );
  if (result == null) {
    throw StateError('Image compression failed.');
  }
  return File(result.path);
}

/// Controller that tags [arg] once and publishes the draft via
/// [AsyncValue]. Consumers bind to this to show skeleton loaders →
/// tag chips → error banner without any manual setState.
class VisionTagController extends AsyncNotifier<VisionTagDraft> {
  VisionTagController(this.arg);
  final File arg;

  @override
  Future<VisionTagDraft> build() async {
    final service = ref.watch(visionApiServiceProvider);
    final compressed = await compressForTagging(arg);
    try {
      return await service.tagImage(imageFile: compressed);
    } finally {
      // Best-effort cleanup: the tagger only needs the bytes for the
      // duration of one HTTP call. Leaving WebP temp files behind
      // would leak ~100 KB per scan.
      unawaited(_safeDelete(compressed));
    }
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) {
        await f.delete();
      }
    } on Object {
      // ignore
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(visionApiServiceProvider);
      final compressed = await compressForTagging(arg);
      try {
        return await service.tagImage(imageFile: compressed);
      } finally {
        unawaited(_safeDelete(compressed));
      }
    });
  }
}

final visionTagControllerProvider = AsyncNotifierProvider.autoDispose
    .family<VisionTagController, VisionTagDraft, File>(VisionTagController.new);
