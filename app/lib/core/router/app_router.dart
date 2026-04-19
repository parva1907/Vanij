import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/crm/presentation/customers_screen.dart';
import '../../features/finance/presentation/add_ledger_entry_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/finance/presentation/ledger_list_screen.dart';
import '../../features/inventory/presentation/inventory_form_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/tag_confirm_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/main_shell.dart';

/// Routes used across the app. Screens use `context.go(VanijRoutes.xxx)` —
/// we never call `Navigator.push` directly.
class VanijRoutes {
  VanijRoutes._();

  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const inventory = '/inventory';
  static const inventoryNew = '/inventory/new';
  static const inventoryTagConfirm = '/inventory/tag-confirm';
  static const customers = '/customers';
  static const finance = '/finance';
  static const financeNew = '/finance/new';
  static const financeLedger = '/finance/ledger';
  static const settings = '/settings';
}

final _rootNavKey = GlobalKey<NavigatorState>();
final _shellNavKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  // Reactively rebuild the router when the auth state flips. We listen to
  // the stream directly so GoRouter redirects immediately on sign-in /
  // sign-out without waiting for a widget rebuild.
  final authListenable = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (prev, next) => authListenable.value++);
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: VanijRoutes.inventory,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final goingToAuth =
          state.matchedLocation == VanijRoutes.signIn ||
          state.matchedLocation == VanijRoutes.signUp;
      if (!signedIn && !goingToAuth) return VanijRoutes.signIn;
      if (signedIn && goingToAuth) return VanijRoutes.inventory;
      return null;
    },
    routes: [
      GoRoute(
        path: VanijRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: VanijRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: VanijRoutes.inventory,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryScreen()),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavKey,
                builder: (context, state) {
                  final extra = state.extra;
                  return InventoryFormScreen(
                    initialSeed: extra is InventoryDraftSeed ? extra : null,
                  );
                },
              ),
              GoRoute(
                path: 'tag-confirm',
                parentNavigatorKey: _rootNavKey,
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is! File) {
                    // Defensive: tag-confirm without a picked image is
                    // unreachable through the UI; fall back to the plain
                    // form so the merchant can still add an item.
                    return const InventoryFormScreen();
                  }
                  return TagConfirmScreen(imageFile: extra);
                },
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavKey,
                builder: (context, state) =>
                    InventoryFormScreen(itemId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: VanijRoutes.customers,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CustomersScreen()),
          ),
          GoRoute(
            path: VanijRoutes.finance,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FinanceScreen()),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavKey,
                builder: (context, state) => const AddLedgerEntryScreen(),
              ),
              GoRoute(
                path: 'ledger',
                parentNavigatorKey: _rootNavKey,
                builder: (context, state) => const LedgerListScreen(),
              ),
            ],
          ),
          GoRoute(
            path: VanijRoutes.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
