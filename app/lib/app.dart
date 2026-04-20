import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/analytics_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'l10n/app_localizations.dart';

class VanijApp extends ConsumerWidget {
  const VanijApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sprint 8: bind/unbind the analytics user id as auth state flips.
    // Analytics payloads never carry any other PII (see
    // core/analytics/events.dart); the uid is hashed device-side by
    // Firebase Analytics.
    ref.listen(authStateProvider, (prev, next) {
      final uid = next.asData?.value?.uid;
      ref.read(analyticsServiceProvider).setUserId(uid);
      if (prev?.asData?.value == null && uid != null) {
        ref.read(analyticsServiceProvider).logSignInSuccess(method: 'auto');
      }
    });

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Vanij',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
