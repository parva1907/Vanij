import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/features/inventory/data/models/vision_tag_draft.dart';

void main() {
  group('VisionTagDraft.fromJson', () {
    test('parses the full schema returned by /v1/vision/tag', () {
      final json = {
        'category': {'value': 'Saree', 'confidence': 0.82},
        'colors': [
          {'value': 'Red', 'confidence': 0.71},
          {'value': 'Gold', 'confidence': 0.44},
        ],
        'pattern': {'value': 'Paisley', 'confidence': 0.35},
        'name_suggestion': 'Red Saree',
        'backend': 'heuristic',
        'model_version': 'stub-1',
      };

      final draft = VisionTagDraft.fromJson(json);

      expect(draft.category.value, 'Saree');
      expect(draft.category.confidence, closeTo(0.82, 0.0001));
      expect(draft.colors.map((c) => c.value), ['Red', 'Gold']);
      expect(draft.pattern?.value, 'Paisley');
      expect(draft.nameSuggestion, 'Red Saree');
      expect(draft.backend, 'heuristic');
      expect(draft.modelVersion, 'stub-1');
    });

    test('tolerates a null pattern and empty colours', () {
      final draft = VisionTagDraft.fromJson({
        'category': {'value': 'Shirt', 'confidence': 0.5},
        'colors': [],
        'pattern': null,
        'name_suggestion': null,
        'backend': 'heuristic',
        'model_version': 'stub-1',
      });

      expect(draft.pattern, isNull);
      expect(draft.colors, isEmpty);
      expect(draft.nameSuggestion, isNull);
    });

    test('falls back to safe defaults on missing backend metadata', () {
      final draft = VisionTagDraft.fromJson({
        'category': {'value': 'Kurta', 'confidence': 0.6},
        'colors': [],
        'pattern': null,
        'name_suggestion': null,
      });

      expect(draft.backend, 'unknown');
      expect(draft.modelVersion, 'unknown');
    });
  });
}
