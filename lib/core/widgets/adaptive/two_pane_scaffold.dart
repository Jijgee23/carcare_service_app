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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(padding: padding, child: list);
        if (constraints.maxWidth < AdaptiveBreakpoints.expanded) {
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
