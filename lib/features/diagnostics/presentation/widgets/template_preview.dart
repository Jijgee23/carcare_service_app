import 'package:flutter/material.dart';

import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostic.dart';

/// The template as a technician fills it, after the web's `TemplatePreview`.
/// Check answers can be tapped to try the `showWhen` dependencies; nothing
/// here is saved.
class TemplatePreview extends StatefulWidget {
  const TemplatePreview({super.key, required this.schema});

  final TemplateSchema schema;

  @override
  State<TemplatePreview> createState() => _TemplatePreviewState();
}

class _TemplatePreviewState extends State<TemplatePreview> {
  /// Check answers by item id — what `showWhen` reads.
  final _answers = <String, String>{};

  /// Answers to positioned check questions, by `<itemId>@<code>`; they drive
  /// no dependency, so they stay apart from [_answers].
  final _positioned = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final touched = _answers.isNotEmpty || _positioned.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Техникч бөглөх үед ингэж харагдана. Сонголт дарж хамаарлыг '
                'туршиж болно — хадгалагдахгүй.',
                style: context.textStyles.caption.copyWith(
                  color: theme.mutedText3,
                ),
              ),
            ),
            if (touched)
              TextButton(
                key: const ValueKey('template_preview_clear'),
                onPressed: () => setState(() {
                  _answers.clear();
                  _positioned.clear();
                }),
                child: const Text('Цэвэрлэх'),
              ),
          ],
        ),
        for (final section in widget.schema.sections)
          if (section.items.any((item) => item.isVisible(_answers)))
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.panel2,
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    section.title.isEmpty ? 'Нэргүй хэсэг' : section.title,
                    style: context.textStyles.bodyMedium.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final item in section.items)
                    if (item.isVisible(_answers))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _PreviewItem(
                          item: item,
                          answerOf: (key) =>
                              key == item.id ? _answers[key] : _positioned[key],
                          onAnswer: (key, value) => setState(() {
                            (key == item.id ? _answers : _positioned)[key] =
                                value;
                          }),
                        ),
                      ),
                ],
              ),
            ),
      ],
    );
  }
}

class _PreviewItem extends StatelessWidget {
  const _PreviewItem({
    required this.item,
    required this.answerOf,
    required this.onAnswer,
  });

  final TemplateItem item;
  final String? Function(String key) answerOf;
  final void Function(String key, String value) onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final positions = item.positionSet?.positions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: item.label.isEmpty ? 'Нэргүй асуулт' : item.label,
            children: [
              if (item.required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: theme.danger),
                ),
            ],
          ),
          style: context.textStyles.bodyMedium.copyWith(color: theme.ink2),
        ),
        const SizedBox(height: 8),
        if (positions == null)
          _PreviewInputs(
            item: item,
            selected: answerOf(item.id),
            onCheck: (value) => onAnswer(item.id, value),
          )
        else
          for (final position in positions)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.panel,
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    position.label,
                    style: context.textStyles.captionMedium.copyWith(
                      color: theme.mutedText2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _PreviewInputs(
                    item: item,
                    selected: answerOf(positionedKey(item.id, position.code)),
                    onCheck: (value) =>
                        onAnswer(positionedKey(item.id, position.code), value),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _PreviewInputs extends StatelessWidget {
  const _PreviewInputs({
    required this.item,
    required this.selected,
    required this.onCheck,
  });

  final TemplateItem item;
  final String? selected;
  final ValueChanged<String> onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final input = switch (item.type) {
      ItemType.check => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in item.effectiveOptions)
            _CheckOption(
              label: option,
              selected: selected == option,
              onTap: () => onCheck(option),
            ),
        ],
      ),
      ItemType.text => const TextField(
        maxLines: 2,
        decoration: InputDecoration(hintText: 'Текст бичих...', isDense: true),
      ),
      ItemType.number => const TextField(
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: '0', isDense: true),
      ),
      ItemType.photo => const _Placeholder(
        icon: Icons.photo_camera_outlined,
        label: 'Зураг оруулах талбар',
      ),
      ItemType.signature => const _Placeholder(
        icon: Icons.draw_outlined,
        label: 'Гарын үсгийн талбар',
      ),
      ItemType.unknown => const SizedBox.shrink(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        const SizedBox(height: 8),
        TextField(
          style: context.textStyles.caption.copyWith(color: theme.ink),
          decoration: const InputDecoration(
            hintText: 'Нэмэлт тэмдэглэл (заавал биш)...',
            isDense: true,
          ),
        ),
      ],
    );
  }
}

/// A check answer, tinted by what it says (`checkOptionTone`) once picked.
class _CheckOption extends StatelessWidget {
  const _CheckOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final tone = switch (checkOptionTone(label)) {
      CheckStatus.good => theme.ok,
      CheckStatus.warning => theme.warn,
      CheckStatus.danger => theme.danger,
    };
    final radius = BorderRadius.circular(AppDimens.radiusSM);
    return Material(
      color: selected ? tone.withValues(alpha: 0.15) : theme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? tone.withValues(alpha: 0.4) : theme.border,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? tone : null,
                  border: Border.all(color: selected ? tone : theme.mutedText3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.textStyles.caption.copyWith(
                  color: selected ? tone : theme.mutedText2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.mutedText3),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.textStyles.caption.copyWith(color: theme.mutedText3),
          ),
        ],
      ),
    );
  }
}
