import 'package:carcare_service/core/services/branch_service.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/subscription.dart';
import 'package:carcare_service/features/models/user.dart';
import 'package:carcare_service/features/presentation/controllers/auth_controller.dart';
import 'package:carcare_service/features/presentation/data/repository/me_repository.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';
import 'package:carcare_service/shared/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Staff profile & account screen.
///
/// Refreshes the authoritative profile from `GET /api/v1/me`, resolves the
/// assigned branch name, and surfaces subscription status from
/// `GET /api/v1/subscription`. All network work is best-effort; the screen
/// renders from stored state if any call fails.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _meRepo = MeRepository();
  bool _loading = true;
  String? _branchName;
  SubscriptionStatus? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Refresh profile (updates Hive-stored user), subscription and branch name.
    await _meRepo.refresh();
    _sub = await SubscriptionService.instance.getStatus();
    final branchId = Authenticator.user?.branchId;
    if (branchId != null) {
      final branches = await BranchService.instance.getBranches();
      _branchName = branches
          .where((b) => b.id == branchId)
          .map((b) => b.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);
    } else {
      _branchName = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Гарах уу?',
      message: 'Та системээс гарахдаа итгэлтэй байна уу?',
      confirmLabel: 'Гарах',
      icon: Icons.logout_rounded,
      isDangerous: true,
    );
    if (ok && mounted) context.read<AuthController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профайл'),
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Хэрэглэгчийн мэдээлэл байхгүй'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppDimens.paddingMD),
                children: [
                  _Header(user: user),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Хувийн мэдээлэл',
                    rows: [
                      ('Утас', user.phone.isNotEmpty ? user.phone : '—'),
                      ('Байгууллага', user.tenant.name),
                      ('Салбар', _branchName ?? (user.branchId == null ? 'Бүх салбар' : '—')),
                      ('Эрх', user.role?.name ?? (user.isOwner ? 'Эзэмшигч' : 'Ажилтан')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SubscriptionCard(loading: _loading, sub: _sub),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: 'Аппликейшн',
                    rows: const [('Хувилбар', '1.0.0 (1)')],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Гарах',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final User user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.accent,
            child: Text(
              user.firstName.isNotEmpty ? user.firstName[0] : '?',
              style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(user.email, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 110, child: Text(r.$1, style: AppTextStyles.caption)),
                    Expanded(
                      child: Text(r.$2,
                          style: AppTextStyles.bodyMedium, textAlign: TextAlign.right),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final bool loading;
  final SubscriptionStatus? sub;
  const _SubscriptionCard({required this.loading, required this.sub});

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Захиалгын багц', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          if (loading && s == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (s == null)
            Text('Мэдээлэл авах боломжгүй', style: AppTextStyles.caption)
          else ...[
            Row(
              children: [
                SizedBox(width: 110, child: Text('Багц', style: AppTextStyles.caption)),
                Expanded(
                  child: Text(s.plan ?? '—',
                      style: AppTextStyles.bodyMedium, textAlign: TextAlign.right),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 110, child: Text('Төлөв', style: AppTextStyles.caption)),
                const Spacer(),
                _StatusPill(sub: s),
              ],
            ),
            if (s.expiresAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(width: 110, child: Text('Дуусах', style: AppTextStyles.caption)),
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(s.expiresAt!) +
                          (s.daysLeft != null ? ' • ${s.daysLeft} хоног' : ''),
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SubscriptionStatus sub;
  const _StatusPill({required this.sub});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = sub.locked
        ? ('Хаагдсан', AppColors.danger, AppColors.dangerBg)
        : sub.expiringSoon
            ? ('Удахгүй дуусна', AppColors.warning, AppColors.warningBg)
            : sub.isTrial
                ? ('Туршилт', AppColors.accent, const Color(0xFFEEF3FF))
                : ('Идэвхтэй', AppColors.good, AppColors.goodBg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimens.radiusFull)),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
