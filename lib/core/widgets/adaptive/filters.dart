import 'package:flutter/material.dart';

@immutable
class FilterState {
  const FilterState([this.values = const <String, Object?>{}]);
  final Map<String, Object?> values;

  Object? operator [](String key) => values[key];
  bool has(String key) => values[key] != null;
  int get activeCount => values.values.where((value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }).length;

  FilterState copyWith(String key, Object? value) {
    final next = Map<String, Object?>.from(values);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return FilterState(Map.unmodifiable(next));
  }

  FilterState clear() => const FilterState();
}

typedef FilterFieldBuilder = Widget Function(
  BuildContext context,
  FilterState draft,
  ValueChanged<Object?> onChanged,
);

class FilterDefinition {
  const FilterDefinition({
    required this.key,
    required this.label,
    required this.builder,
  });
  final String key;
  final String label;
  final FilterFieldBuilder builder;
}

/// Inline filter controls for tablet layouts. The same [definitions] and
/// [FilterState] are passed to [FilterSheet] on a phone.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.state,
    required this.definitions,
    required this.onChanged,
    this.onClear,
    this.title,
  });
  final FilterState state;
  final List<FilterDefinition> definitions;
  final ValueChanged<FilterState> onChanged;
  final VoidCallback? onClear;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (title != null)
          Text(title!, style: Theme.of(context).textTheme.titleSmall),
        for (final definition in definitions)
          InputChip(
            label: Text(
              state[definition.key] == null
                  ? definition.label
                  : '${definition.label}: ${state[definition.key]}',
            ),
            selected: state.has(definition.key),
            onSelected: (_) => _edit(context, definition),
            onDeleted: state.has(definition.key)
                ? () => onChanged(state.copyWith(definition.key, null))
                : null,
          ),
        if (state.activeCount > 0)
          TextButton(
            onPressed: onClear ?? () => onChanged(state.clear()),
            child: const Text('Арилгах'),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, FilterDefinition definition) async {
    final result = await showModalBottomSheet<FilterState>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterSheet(
        state: state,
        definitions: [definition],
        onChanged: (value) => Navigator.of(context).pop(value),
      ),
    );
    if (result != null) onChanged(result);
  }
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.state,
    required this.definitions,
    required this.onChanged,
    this.title = 'Шүүлтүүр',
  });
  final FilterState state;
  final List<FilterDefinition> definitions;
  final ValueChanged<FilterState> onChanged;
  final String title;

  static Future<FilterState?> show({
    required BuildContext context,
    required FilterState state,
    required List<FilterDefinition> definitions,
    String title = 'Шүүлтүүр',
  }) => showModalBottomSheet<FilterState>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FilterSheet(
      state: state,
      definitions: definitions,
      title: title,
      onChanged: (value) => Navigator.of(context).pop(value),
    ),
  );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late FilterState _draft = widget.state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final definition in widget.definitions) ...[
              definition.builder(
                context,
                _draft,
                (value) => setState(() {
                  _draft = _draft.copyWith(definition.key, value);
                }),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: () => widget.onChanged(_draft),
              child: const Text('Хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
