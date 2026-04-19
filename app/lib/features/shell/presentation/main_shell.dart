import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';

/// Bottom navigation scaffold — exactly 4 tabs, per spec.
///
/// Riverpod providers consumed: none directly (child routes consume their own).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_TabSpec>[
    _TabSpec(
      VanijRoutes.inventory,
      Icons.inventory_2_outlined,
      Icons.inventory_2,
    ),
    _TabSpec(VanijRoutes.customers, Icons.forum_outlined, Icons.forum),
    _TabSpec(
      VanijRoutes.finance,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
    _TabSpec(VanijRoutes.settings, Icons.settings_outlined, Icons.settings),
  ];

  int _indexForLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = <String>[
      l.navInventory,
      l.navCustomers,
      l.navFinance,
      l.navSettings,
    ];
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => context.go(_tabs[i].route),
        items: [
          for (var i = 0; i < _tabs.length; i++)
            BottomNavigationBarItem(
              icon: Icon(_tabs[i].icon),
              activeIcon: Icon(_tabs[i].activeIcon),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.route, this.icon, this.activeIcon);
  final String route;
  final IconData icon;
  final IconData activeIcon;
}
