import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Sprint 1 stub. Chat UI arrives in Sprint 6; LLM agent in Sprint 7.
///
/// Riverpod providers consumed: none yet.
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navCustomers)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 48,
                color: VanijColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l.emptyCustomersTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.emptyCustomersSubtitle,
                style: const TextStyle(color: VanijColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
