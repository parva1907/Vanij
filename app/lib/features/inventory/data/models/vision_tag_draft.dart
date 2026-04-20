/// Draft tag suggestions returned by the Python vision tagger.
///
/// These are *candidates* — per the Vanij absolute security rule they
/// are never auto-committed to Firestore. The `TagConfirmScreen`
/// surfaces them for merchant review; only after explicit confirmation
/// do they flow into an `InventoryItem`.
class VisionTagDraft {
  const VisionTagDraft({
    required this.category,
    required this.colors,
    required this.pattern,
    required this.nameSuggestion,
    required this.backend,
    required this.modelVersion,
  });

  final TagCandidate category;
  final List<TagCandidate> colors;
  final TagCandidate? pattern;
  final String? nameSuggestion;
  final String backend;
  final String modelVersion;

  factory VisionTagDraft.fromJson(Map<String, dynamic> json) {
    return VisionTagDraft(
      category: TagCandidate.fromJson(
        Map<String, dynamic>.from(json['category'] as Map),
      ),
      colors: [
        for (final c in (json['colors'] as List? ?? const []))
          TagCandidate.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
      pattern: json['pattern'] == null
          ? null
          : TagCandidate.fromJson(
              Map<String, dynamic>.from(json['pattern'] as Map),
            ),
      nameSuggestion: json['name_suggestion'] as String?,
      backend: (json['backend'] as String?) ?? 'unknown',
      modelVersion: (json['model_version'] as String?) ?? 'unknown',
    );
  }
}

class TagCandidate {
  const TagCandidate({required this.value, required this.confidence});

  final String value;
  final double confidence;

  factory TagCandidate.fromJson(Map<String, dynamic> json) {
    return TagCandidate(
      value: (json['value'] as String?) ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
