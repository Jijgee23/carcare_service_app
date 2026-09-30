import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/widgets/common/common_widgets.dart';

// Building blocks shared by the legal documents (Нууцлалын бодлого,
// Үйлчилгээний нөхцөл) so both read as one set.

const legalContactEmail = 'contact@infosystems.mn';
const legalDeletionUrl = 'https://carservice.mn/account-deletion';

/// Best-effort: with no mail/phone/browser app there is nothing to open.
Future<void> openLegalLink(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Uri legalMailto([String email = legalContactEmail]) =>
    Uri(scheme: 'mailto', path: email);

/// A document's scroll view: a readable measure on tablets, selectable text,
/// title and effective-date badge on top.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    super.key,
    required this.title,
    required this.effectiveDate,
    required this.children,
  });

  final String title;
  final String effectiveDate;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gutter = ((constraints.maxWidth - 720) / 2).clamp(
        AppDimens.paddingMD,
        double.infinity,
      );
      return SelectionArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 40),
          children: [
            Text(title, style: context.textStyles.h1),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Text(
                  'Хүчин төгөлдөр болсон: $effectiveDate',
                  style: context.textStyles.captionMedium.copyWith(
                    color: context.colors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );
    },
  );
}

/// Инфосистемс ХХК's contact block, identical in both documents.
class LegalContactCard extends StatelessWidget {
  const LegalContactCard({super.key});

  static const _phones = ['8870116399', '70126399', '91916549'];

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Инфосистемс ХХК', style: context.textStyles.h3),
        const SizedBox(height: 8),
        LegalLinkRow(
          icon: Icons.mail_outline_rounded,
          label: legalContactEmail,
          onTap: () => openLegalLink(legalMailto()),
        ),
        for (final phone in _phones)
          LegalLinkRow(
            icon: Icons.phone_outlined,
            label: phone,
            onTap: () => openLegalLink(Uri(scheme: 'tel', path: phone)),
          ),
        const LegalLinkRow(
          icon: Icons.place_outlined,
          label:
              'Улаанбаатар хот, Чингэлтэй дүүрэг, 5-р хороо, '
              'Баянбогд плаза, 402 тоот',
        ),
      ],
    ),
  );
}

class LegalSection extends StatelessWidget {
  const LegalSection({
    super.key,
    required this.number,
    required this.title,
    required this.children,
  });

  final int number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: context.textStyles.captionMedium.copyWith(
                  color: context.colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: context.textStyles.h2)),
          ],
        ),
        const SizedBox(height: 12),
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          child,
        ],
      ],
    ),
  );
}

class LegalPara extends StatelessWidget {
  const LegalPara(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.textStyles.body.copyWith(
      height: 1.6,
      color: context.colors.textPrimary,
    ),
  );
}

class LegalSubHeading extends StatelessWidget {
  const LegalSubHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: context.textStyles.h3),
  );
}

class LegalBullets extends StatelessWidget {
  const LegalBullets(this.items, {super.key});
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 9, right: 10, left: 2),
                decoration: BoxDecoration(
                  color: context.colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: LegalPara(item)),
            ],
          ),
        ),
    ],
  );
}

/// A titled card: an optional icon, then either [body] text or labelled
/// [rows] (the policy's table columns, stacked for phone widths).
class LegalItemCard extends StatelessWidget {
  const LegalItemCard({
    super.key,
    required this.title,
    this.icon,
    this.body,
    this.rows = const [],
    this.onTap,
  });

  final String title;
  final IconData? icon;
  final String? body;
  final List<(String, String)> rows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: Icon(icon, size: 20, color: context.colors.accent),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textStyles.bodyMedium),
              if (body != null) ...[
                const SizedBox(height: 4),
                Text(
                  body!,
                  style: context.textStyles.body.copyWith(
                    height: 1.5,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
              for (final (label, value) in rows) ...[
                const SizedBox(height: 8),
                Text(label.toUpperCase(), style: context.textStyles.label),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: context.textStyles.body.copyWith(height: 1.5),
                ),
              ],
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.open_in_new_rounded,
            size: 18,
            color: context.colors.textHint,
          ),
        ],
      ],
    ),
  );
}

class LegalNote extends StatelessWidget {
  const LegalNote({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? context.colors.warning : context.colors.good;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: LegalPara(text)),
        ],
      ),
    );
  }
}

class LegalKeyValue extends StatelessWidget {
  const LegalKeyValue({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.textStyles.bodyMedium),
      const SizedBox(height: 2),
      Text(
        value,
        style: context.textStyles.body.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ],
  );
}

class LegalLinkRow extends StatelessWidget {
  const LegalLinkRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final link = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: context.textStyles.body.copyWith(
                  color: link ? context.colors.accent : null,
                  fontWeight: link ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
