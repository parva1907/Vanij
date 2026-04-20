import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'common/config/app_config.dart';
import 'core/telemetry/crashlytics_bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast if the caller forgot to pass --dart-define=PYTHON_BACKEND_URL=...
  AppConfig.instance.assertConfigured();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sprint 8: wire Crashlytics before runApp so the global error hooks
  // catch anything that blows up during `ProviderScope` bootstrap.
  // `installCrashlytics` wraps `runApp` in `runZonedGuarded` internally.
  await installCrashlytics(
    () => runApp(const ProviderScope(child: VanijApp())),
  );
}
