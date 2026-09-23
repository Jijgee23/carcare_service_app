import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';

/// List row + load-more footer for the Customers list — P3-F2. Mirrors
/// `appointment_list_widgets.dart`'s shape, minus selection (the customer
/// list has none).

class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = customer.displayName;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.colors.accent.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.textStyles.bodyMedium),
                const SizedBox(height: 2),
                if (customer.phone != null)
                  Text(customer.phone!, style: context.textStyles.caption),
                if (customer.email != null)
                  Text(customer.email!, style: context.textStyles.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textHint),
        ],
      ),
    );
  }
}

class CustomerListFooter extends StatelessWidget {
  const CustomerListFooter({
    super.key,
    required this.loadingMore,
    required this.loadMoreError,
    required this.hasNext,
    required this.total,
    required this.onLoadMore,
  });

  final bool loadingMore;
  final String? loadMoreError;
  final bool hasNext;
  final int total;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.refresh),
          label: Text('Дахин оролдох: $loadMoreError'),
        ),
      );
    }
    if (hasNext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Дараагийн хуудас'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Нийт $total үйлчлүүлэгч',
          style: context.textStyles.caption,
        ),
      ),
    );
  }
}
