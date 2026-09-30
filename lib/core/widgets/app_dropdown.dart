import 'package:flutter/material.dart';

import 'package:carservice_business/app/theme/app_theme.dart';

/// One option of an [AppDropdown].
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.leading,
    this.enabled = true,
    this.key,
  });

  final T value;
  final String label;

  /// Icon or avatar ahead of [label], in the menu and on the picked field.
  final Widget? leading;
  final bool enabled;

  /// Key for the option's menu row.
  final Key? key;
}

enum AppDropdownVariant {
  /// Looks like a text field (label, hint, border from the input theme).
  field,

  /// A 32px bordered pill for dense settings rows.
  compact,

  /// Borderless value + chevron, for a row that already has its own label.
  inline,
}

/// The app's single-select dropdown: a rounded, bordered [MenuAnchor] panel
/// as wide as the field, the picked option checked. Use it instead of
/// Material's [DropdownButton]/[DropdownButtonFormField].
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.prefixIcon,
    this.decoration,
    this.variant = AppDropdownVariant.field,
    this.expand = true,
    this.menuMaxHeight = 320,
  });

  final T? value;
  final List<AppDropdownItem<T>> items;

  /// Null disables the dropdown.
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;

  /// [AppDropdownVariant.field] only: replaces the default decoration built
  /// from [label]/[hint]/[prefixIcon].
  final InputDecoration? decoration;
  final AppDropdownVariant variant;

  /// [AppDropdownVariant.compact]/[AppDropdownVariant.inline]: fill the
  /// available width instead of hugging the value.
  final bool expand;
  final double menuMaxHeight;

  /// The shared menu panel look, also used by menus with a custom anchor
  /// (e.g. the order detail's status and assignee rows).
  static MenuStyle menuStyle(
    BuildContext context, {
    double? width,
    double maxHeight = double.infinity,
  }) {
    final theme = CarserviceTheme.of(context);
    return MenuStyle(
      minimumSize: WidgetStatePropertyAll(Size(width ?? 180, 0)),
      maximumSize: WidgetStatePropertyAll(Size(width ?? double.infinity, maxHeight)),
      backgroundColor: WidgetStatePropertyAll(theme.panel),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(6),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLG),
          side: BorderSide(color: theme.border),
        ),
      ),
    );
  }

  bool get _enabled => onChanged != null && items.isNotEmpty;

  AppDropdownItem<T>? get _selected {
    for (final item in items) {
      if (item.value == value) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedWidth;
        // The panel matches a trigger that fills its width; a hugging
        // compact/inline trigger gets a panel as wide as its widest option.
        final fills = variant == AppDropdownVariant.field || expand;
        final width = bounded && fills ? constraints.maxWidth : null;
        return MenuAnchor(
          alignmentOffset: const Offset(0, 6),
          // Lets the min width reach the panel; by default MenuAnchor sizes
          // the panel to its widest item.
          crossAxisUnconstrained: false,
          style: menuStyle(context, width: width, maxHeight: menuMaxHeight),
          menuChildren: [for (final item in items) _option(context, item)],
          builder: (context, menu, _) {
            final onTap = _enabled
                ? () {
                    if (menu.isOpen) return menu.close();
                    // Close the keyboard first, as Material's dropdown route
                    // did: `AppNav.sheet` strips the keyboard inset, so a
                    // menu opened in a sheet would land behind the keyboard.
                    FocusManager.instance.primaryFocus?.unfocus();
                    menu.open();
                  }
                : null;
            return switch (variant) {
              AppDropdownVariant.field => _field(context, menu, onTap),
              AppDropdownVariant.compact => _compact(context, menu, onTap, bounded),
              AppDropdownVariant.inline => _inline(context, menu, onTap, bounded),
            };
          },
        );
      },
    );
  }

  Widget _option(BuildContext context, AppDropdownItem<T> item) {
    final theme = CarserviceTheme.of(context);
    final selected = item.value == value;
    return MenuItemButton(
      key: item.key,
      onPressed: item.enabled
          ? () {
              if (!selected) onChanged?.call(item.value);
            }
          : null,
      style: MenuItemButton.styleFrom(
        minimumSize: Size.fromHeight(variant == AppDropdownVariant.compact ? 40 : 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: selected ? theme.accent.withOpacity(.06) : null,
      ),
      leadingIcon: item.leading,
      trailingIcon: selected ? Icon(Icons.check_rounded, size: 20, color: theme.accent) : null,
      child: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (variant == AppDropdownVariant.compact
                    ? context.textStyles.caption
                    : context.textStyles.bodyMedium)
                .copyWith(
                  color: item.enabled ? theme.ink : theme.mutedText3,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
      ),
    );
  }

  Widget _chevron(BuildContext context, MenuController menu, {double? size}) => Icon(
    menu.isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
    size: size,
    color: _enabled ? CarserviceTheme.of(context).mutedText : CarserviceTheme.of(context).mutedText3,
  );

  Widget _field(BuildContext context, MenuController menu, VoidCallback? onTap) {
    final selected = _selected;
    final base =
        decoration ?? InputDecoration(labelText: label, hintText: hint, prefixIcon: prefixIcon);
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: InputDecorator(
          decoration: base.copyWith(
            enabled: _enabled,
            suffixIcon: base.suffixIcon ?? _chevron(context, menu),
          ),
          isFocused: menu.isOpen,
          isEmpty: selected == null,
          child: selected == null
              ? null
              : _value(
                  context,
                  selected,
                  context.textStyles.body.copyWith(
                    color: _enabled
                        ? CarserviceTheme.of(context).ink
                        : CarserviceTheme.of(context).mutedText3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, MenuController menu, VoidCallback? onTap, bool bounded) {
    final theme = CarserviceTheme.of(context);
    final selected = _selected;
    return Material(
      color: theme.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
        side: BorderSide(color: menu.isOpen ? theme.accent.withOpacity(.6) : theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                _flex(
                  bounded,
                  _value(
                    context,
                    selected,
                    context.textStyles.caption.copyWith(color: theme.ink2),
                    bounded: bounded,
                  ),
                ),
                const SizedBox(width: 2),
                _chevron(context, menu, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inline(BuildContext context, MenuController menu, VoidCallback? onTap, bool bounded) {
    final theme = CarserviceTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _flex(
              bounded,
              _value(
                context,
                _selected,
                context.textStyles.bodyMedium.copyWith(
                  color: menu.isOpen ? theme.accent : theme.ink,
                ),
                bounded: bounded,
                alignEnd: expand,
              ),
            ),
            const SizedBox(width: 2),
            _chevron(context, menu, size: 20),
          ],
        ),
      ),
    );
  }

  /// Flex children throw in an unbounded row, so a hugging trigger there
  /// lays its value out at natural width.
  Widget _flex(bool bounded, Widget child) {
    if (!bounded) return child;
    return expand ? Expanded(child: child) : Flexible(child: child);
  }

  /// The picked option (or [hint]) as leading + ellipsized label.
  Widget _value(
    BuildContext context,
    AppDropdownItem<T>? selected,
    TextStyle style, {
    bool bounded = true,
    bool alignEnd = false,
  }) {
    final text = Text(
      selected?.label ?? hint ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignEnd ? TextAlign.end : null,
      style: selected == null ? style.copyWith(color: CarserviceTheme.of(context).mutedText3) : style,
    );
    final leading = selected?.leading;
    if (leading == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 10),
        bounded ? Flexible(child: text) : text,
      ],
    );
  }
}
