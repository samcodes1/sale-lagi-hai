import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
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
    BuildContext context,
    _Destination d,
    int index,
    int badge, {
    bool selected = false,
  }) {
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (index != 2 || badge == 0) return icon;
    final l10n = context.l10n;
    // Heard with the tab as "Alerts, 3 new alerts", not "3 Alerts"
    // (QA 4.8 BUG-8).
    return Semantics(
      label: badge > 99 ? l10n.alertsBadgeMany : l10n.alertsBadge(badge),
      child: ExcludeSemantics(
        child: Badge(label: Text(badge > 99 ? '99+' : '$badge'), child: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Here, not at launch: any consent form waits until onboarding is over.
    ref.watch(adsStartupProvider);
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
                      icon: _icon(context, d, i, badge),
                      selectedIcon: _icon(context, d, i, badge, selected: true),
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
                icon: _icon(context, d, i, badge),
                selectedIcon: _icon(context, d, i, badge, selected: true),
                label: d.label,
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
      child: _AlertsSeenOnEnter(
        index: navigationShell.currentIndex,
        child: body,
      ),
    );
  }
}

/// Clears the Alerts badge each time the Alerts tab is entered, by a tap or
/// a link. The shell keeps the tab's state, so the screen itself can't
/// tell a second visit (QA 4.8 BUG-5).
class _AlertsSeenOnEnter extends ConsumerStatefulWidget {
  const new({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  ConsumerState<_AlertsSeenOnEnter> createState() => _AlertsSeenOnEnterState();
}

class _AlertsSeenOnEnterState extends ConsumerState<_AlertsSeenOnEnter> {
  @override
  void initState() {
    super.initState();
    if (widget.index == 2) _seen();
  }

  @override
  void didUpdateWidget(_AlertsSeenOnEnter old) {
    super.didUpdateWidget(old);
    if (widget.index == 2 && old.index != 2) _seen();
  }

  void _seen() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) unawaited(markAlertsSeen(ref));
  });

  @override
  Widget build(BuildContext context) => widget.child;
}
