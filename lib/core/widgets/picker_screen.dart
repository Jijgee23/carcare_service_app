import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class PickerScreen<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T) label;
  final String? Function(T)? subtitle;

  const PickerScreen({
    super.key,
    required this.title,
    required this.items,
    required this.label,
    this.selected,
    this.subtitle,
  });

  static Future<T?> push<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T) label,
    T? selected,
    String? Function(T)? subtitle,
  }) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => PickerScreen<T>(
          title: title,
          items: items,
          label: label,
          selected: selected,
          subtitle: subtitle,
        ),
      ),
    );
  }

  @override
  State<PickerScreen<T>> createState() => _PickerScreenState<T>();
}

class _PickerScreenState<T> extends State<PickerScreen<T>> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _query = q;
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
                .where(
                  (item) =>
                      widget.label(item).toLowerCase().contains(q) ||
                      (widget.subtitle?.call(item)?.toLowerCase().contains(q) ??
                          false),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Хайх...',
                  hintStyle: TextStyle(
                    color: context.colors.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: context.colors.textHint,
                    size: 18,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: Icon(
                            Icons.close,
                            color: context.colors.textHint,
                            size: 18,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: context.colors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    borderSide: BorderSide(color: context.colors.accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? Center(
              child: Text(
                _query.isEmpty ? 'Жагсаалт хоосон байна' : 'Илэрц олдсонгүй',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final isSelected = item == widget.selected;
                final sub = widget.subtitle?.call(item);
                return ListTile(
                  tileColor: context.colors.surface,
                  title: Text(
                    widget.label(item),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? context.colors.accent
                          : context.colors.textPrimary,
                    ),
                  ),
                  subtitle: sub != null && sub.isNotEmpty
                      ? Text(
                          sub,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        )
                      : null,
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: context.colors.accent)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
    );
  }
}
