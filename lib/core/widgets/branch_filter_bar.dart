import 'package:carcare_service/core/widgets/filter_pill.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/branch_service.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/branch.dart';
import 'package:flutter/material.dart';

/// Owner эрхтэй үед салбараар шүүх chip мөр.
/// isOwner биш бол юу ч харуулахгүй.
class BranchFilterBar extends StatefulWidget {
  final String? selectedBranchId;
  final ValueChanged<String?> onChanged;

  const BranchFilterBar({
    super.key,
    required this.selectedBranchId,
    required this.onChanged,
  });

  @override
  State<BranchFilterBar> createState() => _BranchFilterBarState();
}

class _BranchFilterBarState extends State<BranchFilterBar> {
  List<Branch> _branches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branches = await BranchService.instance.getBranches();
    if (mounted) setState(() => _branches = branches);
  }

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;
    if (user == null || !user.isOwner || _branches.length < 2) {
      return const SizedBox.shrink();
    }

    return Container(
      // Full width: inside a centred Column it otherwise shrinks to its chips
      // and sits misaligned against the full-width filter rows around it.
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: 'Бүгд',
              active: widget.selectedBranchId == null,
              onTap: () => widget.onChanged(null),
            ),
            ..._branches.map(
              (b) => _Chip(
                label: b.name,
                active: widget.selectedBranchId == b.id,
                onTap: () => widget.onChanged(
                  widget.selectedBranchId == b.id ? null : b.id,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterPill(label: label, selected: active, onTap: onTap),
  );
}
