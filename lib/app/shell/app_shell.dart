import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/features/alerts/application/alerts_providers.dart';

/// One bottom-navigation destination.
typedef _Destination = ({IconData icon, IconData selectedIcon, String label});

/// The five-tab frame around the main screens: Home, Explore, Alerts, Saved,
/// Profile. Each tab keeps its own navigation stack.
///
/// - Compact windows (< 600dp) get a bottom [NavigationBar]; wider ones a
///   [NavigationRail], per the Material window classes.
/// - Re-selecting the current tab returns it to its first screen.
/// - System back on any other tab goes to Home first, then leaves the app.
class AppShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const railBreakpoint = 600.0;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  List<_Destination> _destinations(AppLocalizations l10n) => [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: l10n.navHome),
    (
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: l10n.navExplore,
    ),
    (
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: l10n.navAlerts,
    ),
    (
      icon: Icons.bookmark_border,
      selectedIcon: Icons.bookmark,
      label: l10n.navSaved,
    ),
    (
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: l10n.navProfile,
    ),
  ];

  /// The Alerts tab's icon, with a badge for alerts not yet seen.
  static Widget _icon(
    _Destination d,
    int index,
    int badge, {
    bool selected = false,
  }) {
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (index != 2 || badge == 0) return icon;
    return Badge(label: Text(badge > 99 ? '99+' : '$badge'), child: icon);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _destinations(context.l10n);
    final badge = ref.watch(alertsBadgeProvider).value ?? 0;
    final index = navigationShell.currentIndex;
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;

    final Widget body;
    if (wide) {
      body = Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (i, d) in destinations.indexed)
                    NavigationRailDestination(
                      icon: _icon(d, i, badge),
                      selectedIcon: _icon(d, i, badge, selected: true),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    } else {
      body = Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          destinations: [
            for (final (i, d) in destinations.indexed)
              NavigationDestination(
                icon: _icon(d, i, badge),
                selectedIcon: _icon(d, i, badge, selected: true),
                label: d.label,
                // The count is read with the tab: "Alerts, 3 new alerts".
                tooltip: i == 2 && badge > 0
                    ? '${d.label}, ${context.l10n.alertsBadge(badge)}'
                    : null,
              ),
          ],
        ),
      );
    }

    return PopScope(
      // Predictive back: decided up front, never during the gesture.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: body,
    );
  }
}
