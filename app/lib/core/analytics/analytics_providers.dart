import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

/// ``FirebaseAnalytics`` singleton.
final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

/// Call-site-facing wrapper. Screens read this provider and call the
/// named helpers (``logInventoryCreated`` etc.) — never raw
/// ``logEvent`` with a free-form string, to keep the event catalogue
/// bounded and PII-free.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final analytics = ref.watch(firebaseAnalyticsProvider);
  return AnalyticsService(analytics);
});
