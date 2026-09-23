import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// A shell scaffold that switches navigation chrome at the programme's three
/// width tiers. The body is intentionally supplied by the caller: feature
/// screens keep ownership of their app bars and scrolling state.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.scaffoldKey,
    this.drawer,
    this.header,
    this.branchSwitcher,
    this.notificationAction,
    this.floatingActionButton,
    this.backgroundColor,
    this.bottomNavigationBar,
  });

  final Widget body;
  final List<AdaptiveNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? drawer;
  final Widget? header;
  final Widget? branchSwitcher;
  final Widget? notificationAction;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;

  int get _safeIndex => destinations.isEmpty
      ? 0
      : selectedIndex.clamp(0, destinations.length - 1).toInt();

  List<NavigationDestination> get _bottomDestinations => [
    for (final destination in destinations)
      NavigationDestination(
        icon: Icon(destination.icon),
        selectedIcon: Icon(destination.selectedIcon ?? destination.icon),
        label: destination.label,
        enabled: destination.enabled,
      ),
  ];

  List<NavigationRailDestination> get _railDestinations => [
    for (final destination in destinations)
      NavigationRailDestination(
        icon: Icon(destination.icon),
        selectedIcon: Icon(destination.selectedIcon ?? destination.icon),
        label: Text(destination.label),
        disabled: !destination.enabled,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = AdaptiveBreakpoints.ofWidth(constraints.maxWidth);
        final rail = size != AdaptiveSize.phone;
        final extended = size == AdaptiveSize.tablet;
        // Keep the branch selector in the content column at every width. It
        // may be a full dropdown, which cannot safely fit in a compact rail.
        final persistentHeader = header ?? _defaultHeader();
        final content = persistentHeader == null
            ? body
            : Column(
                children: [
                  persistentHeader,
                  Expanded(child: body),
                ],
              );

        return Scaffold(
          key: scaffoldKey,
          drawer: drawer,
          backgroundColor: backgroundColor,
          floatingActionButton: floatingActionButton,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rail)
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: _safeIndex,
                      onDestinationSelected: (index) {
                        if (destinations[index].enabled) {
                          onDestinationSelected(index);
                        }
                      },
                      extended: extended,
                      // Compact tablets use the collapsed icon-only rail;
                      // extended tablets show labels beside the icons.
                      labelType: NavigationRailLabelType.none,
                      destinations: _railDestinations,
                    ),
                  ),
                ),
              Expanded(child: SafeArea(left: false, child: content)),
            ],
          ),
          bottomNavigationBar: rail
              ? null
              : (bottomNavigationBar ??
                    NavigationBar(
                      selectedIndex: _safeIndex,
                      onDestinationSelected: (index) {
                        if (destinations[index].enabled) {
                          onDestinationSelected(index);
                        }
                      },
                      destinations: _bottomDestinations,
                    )),
        );
      },
    );
  }

  Widget? _defaultHeader() {
    if (branchSwitcher == null && notificationAction == null) return null;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (branchSwitcher != null) Expanded(child: branchSwitcher!),
            if (notificationAction != null) notificationAction!,
          ],
        ),
      ),
    );
  }
}

class AdaptiveNavigationDestination {
  const AdaptiveNavigationDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.enabled = true,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final bool enabled;
  final String? tooltip;
}
