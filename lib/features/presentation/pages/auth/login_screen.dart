import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/core/utils/validators.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // ─── Background blobs ──────────────────────────────────────────
          Positioned(top: -80, right: -60, child: _Blob(size: 240, opacity: 0.08)),
          Positioned(bottom: -100, left: -80, child: _Blob(size: 300, opacity: 0.06)),
          Positioned(top: 160, left: -40, child: _Blob(size: 160, opacity: 0.04)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // ─── Logo ────────────────────────────────────────────
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'carcare.mn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Автомашины үйлчилгээний систем',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
                    ),

                    const SizedBox(height: 48),

                    // ─── Step card ───────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _buildCard(auth),
                    ),

                    const SizedBox(height: 32),
                    Text(
                      '© 2025 carCare.mn — Бүх эрх хуулиар хамгаалагдсан',
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AuthController auth) {
    return Container(
      key: ValueKey(auth.step),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: switch (auth.step) {
        LoginStep.email => _EmailStep(auth: auth),
        LoginStep.password => _PasswordStep(
          auth: auth,
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        LoginStep.activate => _ActivateStep(
          auth: auth,
          obscureNew: _obscureNewPassword,
          onToggleNew: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
          obscureConfirm: _obscureConfirm,
          onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        LoginStep.notRegistered => _NotRegisteredStep(auth: auth),
      },
    );
  }
}

// ─── Email chip (shows current email + back button) ───────────────────────────

class _EmailChip extends StatelessWidget {
  final AuthController auth;
  const _EmailChip({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: auth.loading ? null : auth.resetToEmail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  auth.emailCtrl.text.trim(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 1: Email ────────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  final AuthController auth;
  const _EmailStep({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Нэвтрэх',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Бүртгэлтэй имэйл хаягаа оруулна уу',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        const _FieldLabel('Имэйл хаяг'),
        const SizedBox(height: 6),
        TextField(
          controller: auth.emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          autofocus: true,
          onSubmitted: (_) => auth.loading ? null : auth.checkEmail(),
          style: AppTextStyles.body,
          decoration: const InputDecoration(
            hintText: 'name@example.mn',
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textHint),
          ),
        ),
        const SizedBox(height: 20),

        _PrimaryButton(
          label: 'Үргэлжлүүлэх',
          loading: auth.loading,
          onPressed: auth.checkEmail,
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
  }
}

// ─── Step 2a: Password ────────────────────────────────────────────────────────

class _PasswordStep extends StatelessWidget {
  final AuthController auth;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordStep({required this.auth, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EmailChip(auth: auth),
        const SizedBox(height: 16),

        const Text(
          'Нэвтрэх',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Нууц үгээ оруулна уу',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        const _FieldLabel('Нууц үг'),
        const SizedBox(height: 6),
        TextField(
          controller: auth.passwordCtrl,
          obscureText: obscure,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => auth.loading ? null : auth.login(),
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textHint),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textHint,
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Нууц үг мартсан уу?'),
                content: const Text(
                  'Нууц үгээ өөрөө сэргээх боломжгүй. Байгууллагын админтайгаа '
                  'холбогдож нууц үгээ дахин тохируулж, шинээр идэвхжүүлнэ үү.',
                  style: TextStyle(height: 1.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Ойлголоо'),
                  ),
                ],
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Нууц үг мартсан уу?',
              style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 8),

        _PrimaryButton(label: 'Нэвтрэх', loading: auth.loading, onPressed: auth.login),
      ],
    );
  }
}

// ─── Step 2b: Activate (анхны нэвтрэлт) ─────────────────────────────────────

class _ActivateStep extends StatelessWidget {
  final AuthController auth;
  final bool obscureNew;
  final VoidCallback onToggleNew;
  final bool obscureConfirm;
  final VoidCallback onToggleConfirm;

  const _ActivateStep({
    required this.auth,
    required this.obscureNew,
    required this.onToggleNew,
    required this.obscureConfirm,
    required this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EmailChip(auth: auth),
        const SizedBox(height: 16),

        const Text(
          'Анхны нэвтрэлт',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Та анх удаа нэвтэрч байна. Нууц үгийн OTP кодыг тохируулсан утас руу илгээлээ.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),

        if (auth.maskedPhone != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_android_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  '${auth.maskedPhone} утас руу OTP илгээлээ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),

        // OTP
        const _FieldLabel('OTP код'),
        const SizedBox(height: 6),
        TextField(
          controller: auth.otpCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: AppTextStyles.body.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: '• • • • • •',
            hintStyle: TextStyle(letterSpacing: 6, color: AppColors.textHint),
            prefixIcon: Icon(Icons.pin_rounded, size: 18, color: AppColors.textHint),
          ),
        ),
        const SizedBox(height: 12),

        // New password
        const _FieldLabel('Шинэ нууц үг'),
        const SizedBox(height: 6),
        TextField(
          controller: auth.newPasswordCtrl,
          obscureText: obscureNew,
          textInputAction: TextInputAction.next,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Хамгийн багадаа 8 тэмдэгт',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textHint),
            suffixIcon: GestureDetector(
              onTap: onToggleNew,
              child: Icon(
                obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm password
        const _FieldLabel('Нууц үг давтах'),
        const SizedBox(height: 6),
        TextField(
          controller: auth.confirmPasswordCtrl,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => auth.loading ? null : auth.activate(),
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Нууц үгийг дахин оруулна уу',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textHint),
            suffixIcon: GestureDetector(
              onTap: onToggleConfirm,
              child: Icon(
                obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Resend OTP
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: auth.loading ? null : auth.requestOtp,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'OTP дахин авах',
              style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 8),

        _PrimaryButton(label: 'Идэвхжүүлэх', loading: auth.loading, onPressed: auth.activate),
      ],
    );
  }
}

// ─── Step 2c: Not registered ─────────────────────────────────────────────────

class _NotRegisteredStep extends StatelessWidget {
  final AuthController auth;
  const _NotRegisteredStep({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EmailChip(auth: auth),
        const SizedBox(height: 24),

        Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                child: const Icon(Icons.no_accounts_outlined, size: 26, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              const Text(
                'Бүртгэлгүй имэйл хаяг',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                auth.emailCtrl.text.trim(),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Энэ имэйл хаяг системд бүртгэлгүй байна.\nАдминтай холбогдоно уу.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: auth.resetToEmail,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Өөр имэйл оруулах',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.accent.withOpacity(0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(icon, size: 16, color: Colors.white),
                  ],
                ],
              ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withOpacity(opacity),
      ),
    );
  }
}
