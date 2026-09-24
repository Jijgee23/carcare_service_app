import 'package:flutter/material.dart';

import 'breakpoints.dart';

typedef RecordValueBuilder<T> = Widget Function(BuildContext context, T record);

class RecordColumn<T> {
  const RecordColumn({
    required this.label,
    required this.builder,
    this.flex = 1,
    this.numeric = false,
  });

  final String label;
  final RecordValueBuilder<T> builder;
  final int flex;
  final bool numeric;
}

/// Dense table rendering for tablet widths, backed by the same record/column
/// definition that [RecordCard] uses on a phone.
class DataTableView<T> extends StatelessWidget {
  const DataTableView({
    super.key,
    required this.records,
    required this.columns,
    this.onTap,
    this.onLongPress,
    this.empty,
    this.rowHeight = 56,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.selectedOf,
    this.forceTable = false,
  });

  final List<T> records;
  final List<RecordColumn<T>> columns;
  final ValueChanged<T>? onTap;
  final ValueChanged<T>? onLongPress;
  final Widget? empty;
  final double rowHeight;

  /// Skips the own-width phone/tablet check below and always renders the
  /// dense table format. Needed when this widget sits inside a narrower
  /// pane of a layout that is already known to be tablet-width overall
  /// (e.g. the list side of a [TwoPaneScaffold], whose own width can fall
  /// under [AdaptiveBreakpoints.expanded] even on a real tablet once the
  /// detail pane takes its share) — the caller has already made the
  /// phone/tablet decision at the full-screen level and does not want this
  /// widget to re-decide it against its own, narrower constraints.
  final bool forceTable;

  /// When non-null, the header renders a sort indicator on this column and
  /// taps on a header label with [onSort] set invoke it with the tapped
  /// column's index. Sorting the underlying [records] list is the caller's
  /// responsibility (matches `DataColumn.onSort`'s contract) — this widget
  /// never reorders data itself.
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int>? onSort;

  /// Optional per-row highlight (e.g. the row currently open in a detail
  /// pane). Returns true to apply a subtle selected background.
  final bool Function(T record)? selectedOf;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return empty ?? const Center(child: Text('Мэдээлэл алга'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!forceTable && constraints.maxWidth < AdaptiveBreakpoints.expanded) {
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => RecordCard<T>(
              record: records[index],
              columns: columns,
              onTap: onTap == null ? null : () => onTap!(records[index]),
            ),
          );
        }
        return ListView.separated(
          itemCount: records.length + 1,
          separatorBuilder: (_, index) =>
              index == 0 ? const Divider(height: 1) : const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _TableRow<T>(
                height: rowHeight,
                cells: [
                  for (var i = 0; i < columns.length; i++)
                    Expanded(
                      flex: columns[i].flex,
                      child: InkWell(
                        onTap: onSort == null ? null : () => onSort!(i),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                columns[i].label,
                                textAlign: columns[i].numeric
                                    ? TextAlign.right
                                    : TextAlign.left,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            if (sortColumnIndex == i)
                              Icon(
                                sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 14,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }
            final record = records[index - 1];
            final selected = selectedOf?.call(record) ?? false;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary.withValues(
                        alpha: 0.08,
                      )
                    : null,
              ),
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(record),
                onLongPress: onLongPress == null
                    ? null
                    : () => onLongPress!(record),
                child: _TableRow<T>(
                  height: rowHeight,
                  cells: [
                    for (final column in columns)
                      Expanded(
                        flex: column.flex,
                        child: Align(
                          alignment: column.numeric
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: column.builder(context, record),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TableRow<T> extends StatelessWidget {
  const _TableRow({required this.cells, required this.height});
  final List<Widget> cells;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [for (final cell in cells) cell]),
    ),
  );
}

class RecordCard<T> extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    required this.columns,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final T record;
  final List<RecordColumn<T>> columns;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < columns.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    columns[index].label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: columns[index].numeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: columns[index].builder(context, record),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
