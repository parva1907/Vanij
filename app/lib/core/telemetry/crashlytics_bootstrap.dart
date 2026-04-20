/// Crashlytics wiring (Sprint 8).
///
/// - Flutter fatal errors → `recordFlutterFatalError`.
/// - Uncaught async / platform errors → `recordError`.
/// - Disabled in debug so local stack-traces don't pollute the Firebase
///   console.
library;

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Install global error hooks. Call once, right after
/// `Firebase.initializeApp`, wrapping `runApp` in the returned
/// `runZonedGuarded`. In debug (`kDebugMode == true`) Crashlytics
/// collection is disabled — uncaught errors still print to the console
/// via `FlutterError.onError`'s default handler.
Future<void> installCrashlytics(VoidCallback runnerBody) async {
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      crashlytics.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (!kDebugMode) {
      crashlytics.recordError(error, stack, fatal: true);
    }
    return true;
  };

  runZonedGuarded<void>(
    () {
      runnerBody();
    },
    (Object error, StackTrace stack) {
      if (!kDebugMode) {
        crashlytics.recordError(error, stack, fatal: true);
      }
    },
  );
}
