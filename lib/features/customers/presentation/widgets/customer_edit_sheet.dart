import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:carcare_service/features/customers/presentation/controllers/customer_detail_controller.dart';

/// Edit form for a [Customer] — P3-F4.
///
/// `PATCH /customers/[id]` is a whole-record replace: an omitted field
/// clears the column server-side. This form therefore always sends all four
/// of fullName/phone/email/note explicitly (empty string where the field is
/// blank), never a subset — there is no "only changed fields" diff logic to
/// accidentally reintroduce the omission hazard the contract warns about.
class CustomerEditSheet extends StatefulWidget {
  const CustomerEditSheet({
    super.key,
    required this.customer,
    required this.controller,
  });

  final Customer customer;
  final CustomerDetailController controller;

  static Future<bool> show(
    BuildContext context, {
    required Customer customer,
    required CustomerDetailController controller,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CustomerEditSheet(customer: customer, controller: controller),
    );
    return result ?? false;
  }

  @override
  State<CustomerEditSheet> createState() => _CustomerEditSheetState();
}

class _CustomerEditSheetState extends State<CustomerEditSheet> {
  late final _nameCtrl = TextEditingController(
    text: widget.customer.fullName ?? '',
  );
  late final _phoneCtrl = TextEditingController(
    text: widget.customer.phone ?? '',
  );
  late final _emailCtrl = TextEditingController(
    text: widget.customer.email ?? '',
  );
  late final _noteCtrl = TextEditingController(
    text: widget.customer.note ?? '',
  );

  bool _saving = false;
  String? _generalError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _generalError = null;
      _fieldErrors = const {};
    });
    // All four fields explicitly, always — see the class doc comment.
    final result = await widget.controller.update(
      fullName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text,
      note: _noteCtrl.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context, true);
      case Err(:final error):
        setState(() {
          _saving = false;
          _fieldErrors = error.fieldErrors ?? const {};
          _generalError =
              (error.fieldErrors == null || error.fieldErrors!.isEmpty)
              ? error.display
              : null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Үйлчлүүлэгч засах', style: context.textStyles.h3),
              const SizedBox(height: 16),
              if (_generalError != null) ...[
                Text(
                  _generalError!,
                  style: context.textStyles.body.copyWith(
                    color: context.colors.danger,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Нэр',
                  errorText: _fieldErrors['fullName'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Утас',
                  errorText: _fieldErrors['phone'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Имэйл',
                  errorText: _fieldErrors['email'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Тэмдэглэл',
                  errorText: _fieldErrors['note'],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Болих'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const AppLoading(size: 18)
                          : const Text('Хадгалах'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
