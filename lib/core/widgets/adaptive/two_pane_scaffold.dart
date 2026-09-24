import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Shared list/detail layout. At tablet width the detail is rendered beside
/// the list; on narrower screens only the list is rendered. A feature can use
/// [onSelect] to push its detail route on phone without duplicating layout
/// rules in every list screen.
class TwoPaneScaffold<T> extends StatelessWidget {
  const TwoPaneScaffold({
    super.key,
    required this.list,
    this.detail,
    this.selected,
    this.onSelect,
    this.emptyDetail,
    this.listFlex = 2,
    this.detailFlex = 3,
    this.divider = true,
    this.padding = EdgeInsets.zero,
    this.alwaysSplit = true,
  });

  final Widget list;
  final Widget? detail;
  final T? selected;
  final ValueChanged<T>? onSelect;
  final Widget? emptyDetail;
  final int listFlex;
  final int detailFlex;
  final bool divider;
  final EdgeInsetsGeometry padding;

  /// When false, the list keeps the full width until [detail] is non-null —
  /// there is no permanent empty-state pane. Boards that need their full
  /// width by default (e.g. a multi-column kanban) set this to false so the
  /// pane only appears once something is selected.
  final bool alwaysSplit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(padding: padding, child: list);
        if (constraints.maxWidth < AdaptiveBreakpoints.expanded) {
          return content;
        }
        if (!alwaysSplit && detail == null) {
          return content;
        }
        final detailPane =
            detail ??
            emptyDetail ??
            const Center(child: Text('Дэлгэрэнгүй мэдээлэл сонгоно уу'));
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: listFlex, child: content),
            if (divider) const VerticalDivider(width: 1),
            Expanded(flex: detailFlex, child: detailPane),
          ],
        );
      },
    );
  }
}
