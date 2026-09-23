import 'dart:async';

import 'package:flutter/material.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/vehicles/presentation/controllers/vehicle_list_controller.dart';
import 'package:carcare_service/features/vehicles/presentation/screens/vehicle_detail_screen.dart';
import 'package:carcare_service/features/vehicles/presentation/widgets/vehicle_list_widgets.dart';

/// The vehicle tab of `search_screen.dart`'s `SearchScreen`, split into its
/// own file to mirror [CustomerSearchTab] — the follow-up to `P3-F3`, which
/// built the list but was deliberately kept out of `search_screen.dart` while
/// `P3-F2` held exclusive ownership of that file.
///
/// Migrated onto [VehicleListController] and [VehicleListView]: server-side
/// pagination, the `q` filter and the controller's own debounce replace the
/// legacy tab's hand-rolled `Timer` and its direct
/// `DiagnosticService.searchVehicles` call.
///
/// [showFilters] is `false`: the search tab keeps the plain search-box
/// affordance staff already know, rather than growing the standalone
/// screen's `assigned`/`postpaid` filter chips. `VehicleListScreen` remains
/// the place with the full filter chrome.
///
/// Navigation opens the rebuilt `VehicleDetailScreen` (`P3-F5`) by id — the
/// private legacy-summary adapter this tab used to carry for that call site
/// is gone along with the legacy screen it fed.
class VehicleSearchTab extends StatefulWidget {
  const VehicleSearchTab({super.key, this.controller, this.user});

  /// Injectable for tests; defaults to a fresh [VehicleListController]
  /// (real repository) in production.
  final VehicleListController? controller;

  /// Injectable for tests, matching the customer tab and the detail screens.
  /// Null in production, where the gate reads `Authenticator.user`.
  final User? user;

  @override
  State<VehicleSearchTab> createState() => _VehicleSearchTabState();
}

class _VehicleSearchTabState extends State<VehicleSearchTab> {
  late final VehicleListController _controller;
  late final bool _ownsController;

  User? get _user => widget.user ?? Authenticator.user;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VehicleListController();
    _ownsController = widget.controller == null;
    unawaited(_controller.loadVehicles());
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // P3-X1: gate the surface, not just its actions — see the customer tab.
    if (!canSeeView(_user, 'vehicles.view')) {
      return const EmptyState(
        message: 'Танд машины жагсаалт харах эрх байхгүй байна.',
        icon: Icons.lock_outline,
      );
    }
    return VehicleListView(
      controller: _controller,
      showFilters: false,
      onTap: (vehicle) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id),
        ),
      ),
    );
  }
}
