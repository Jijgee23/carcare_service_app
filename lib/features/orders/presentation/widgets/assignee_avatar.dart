import 'package:flutter/material.dart';

import 'package:carservice_business/features/orders/presentation/feature_theme.dart';

/// Initials circle; an unassigned slot shows a muted person-off glyph.
class AssigneeAvatar extends StatelessWidget {
  const AssigneeAvatar({super.key, required this.name, this.size = 32});

  final String? name;
  final double size;

  String get _initials => (name ?? '')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final initials = _initials;
    final color = initials.isEmpty
        ? context.opsTextSecondary
        : context.opsAccent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        shape: BoxShape.circle,
      ),
      child: initials.isEmpty
          ? Icon(Icons.person_off_outlined, size: size * .55, color: color)
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * .38,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
    );
  }
}
