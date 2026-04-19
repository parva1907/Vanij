/// Runtime configuration read from `--dart-define` flags.
///
/// Security: we NEVER hardcode backend URLs or secrets in source. The Python
/// backend URL must be supplied at build time:
///
///     flutter run --dart-define=PYTHON_BACKEND_URL=http://10.0.2.2:8000
class AppConfig {
  AppConfig._();
  static final AppConfig instance = AppConfig._();

  static const String _pythonBackendUrl = String.fromEnvironment(
    'PYTHON_BACKEND_URL',
    defaultValue: '',
  );

  String get pythonBackendUrl => _pythonBackendUrl;

  /// Verifies `PYTHON_BACKEND_URL` was provided at build time. Runs in every
  /// mode (debug, profile, release) — never wrap this in `assert()` because
  /// `assert` is stripped in release builds.
  void assertConfigured() {
    if (_pythonBackendUrl.isEmpty) {
      throw StateError(
        'PYTHON_BACKEND_URL was not supplied. Pass it via '
        '--dart-define=PYTHON_BACKEND_URL=<url>.',
      );
    }
  }
}
