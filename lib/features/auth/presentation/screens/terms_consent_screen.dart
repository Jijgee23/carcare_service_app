import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carservice_business/app/router.dart';
import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/navigation/app_nav.dart';
import 'package:carservice_business/core/services/auth_storage.dart';
import 'package:carservice_business/core/services/legal_consent_store.dart';
import 'package:carservice_business/features/auth/presentation/controllers/auth_controller.dart';
import 'package:carservice_business/features/settings/presentation/screens/terms_of_service_screen.dart';

/// Shown after a successful login until this user accepts the current terms
/// (see the router's redirect). Accepting is saved in [LegalConsentStore];
/// declining signs out, since the terms say not to use the service
/// without accepting them.
class TermsConsentScreen extends StatefulWidget {
  const TermsConsentScreen({super.key});

  @override
  State<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends State<TermsConsentScreen> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _accept() async {
    final userId = Authenticator.user?.id;
    if (userId == null) return;
    setState(() => _busy = true);
    // The router listens to the store and moves on by itself.
    await LegalConsentStore.instance.accept(userId);
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    await context.read<AuthController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back would only bounce here again; decline is the way out.
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Үйлчилгээний нөхцөл'),
        ),
        body: Column(
          children: [
            const Expanded(child: TermsOfServiceBody()),
            _ConsentBar(
              agreed: _agreed,
              busy: _busy,
              onAgreedChanged: (v) => setState(() => _agreed = v),
              onAccept: _accept,
              onDecline: _decline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentBar extends StatelessWidget {
  const _ConsentBar({
    required this.agreed,
    required this.busy,
    required this.onAgreedChanged,
    required this.onAccept,
    required this.onDecline,
  });

  final bool agreed;
  final bool busy;
  final ValueChanged<bool> onAgreedChanged;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final link = context.textStyles.body.copyWith(
      color: context.colors.accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.accent,
    );
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    key: const ValueKey('terms_consent_checkbox'),
                    onTap: busy ? null : () => onAgreedChanged(!agreed),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: agreed,
                          onChanged: busy
                              ? null
                              : (v) => onAgreedChanged(v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                style: context.textStyles.body,
                                children: [
                                  const TextSpan(text: 'Би '),
                                  TextSpan(
                                    text: 'Үйлчилгээний нөхцөл',
                                    style: link,
                                  ),
                                  const TextSpan(text: ' болон '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () => AppNav.toNamed<void>(
                                        AppPages.privacy,
                                      ),
                                      child: Text(
                                        'Нууцлалын бодлого',
                                        style: link,
                                      ),
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        '-той танилцаж, хүлээн зөвшөөрч '
                                        'байна.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('terms_consent_decline'),
                          onPressed: busy ? null : onDecline,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Татгалзаж гарах'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('terms_consent_accept'),
                          onPressed: agreed && !busy ? onAccept : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Зөвшөөрөх'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
