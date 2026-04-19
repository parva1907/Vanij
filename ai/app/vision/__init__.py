"""Clothing vision tagger package.

Owns the image → draft tag pipeline consumed by the Flutter
``TagConfirmScreen``. The public surface is intentionally narrow:

* :class:`~app.vision.tagger.VisionTagger` — protocol every backend
  implements.
* :class:`~app.vision.tagger.HeuristicVisionTagger` — deterministic
  stub used by CI, tests, and local dev when no PyTorch model is
  available.
* :func:`~app.vision.tagger.load_tagger` — factory picked at startup
  based on ``VISION_BACKEND``.
"""
