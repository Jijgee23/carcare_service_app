import 'dart:async' show unawaited;

import 'package:carcare_service/core/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

// import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────
// P0-F3 (TENANT_MOBILE_SLICES.md): ports the web dashboard's "Ops Console"
// palette (`.landing-ops` in carcare.mn/app/globals.css) onto this theme.
//
// Source of truth read directly for this port: `carcare.mn/app/globals.css`
// lines 243–289 (the `.landing-ops` block and its `html.light .landing-ops`
// override). The accent has already changed once without the parity-plan
// table being updated (amber -> cyan, web commit `f15b477`), so every
// `--oc-*` value below was copied from that CSS, not from
// `TENANT_MOBILE_PARITY_PLAN.md` §5.1. Cross-checked against that table
// after the fact: no disagreement found — every value in §5.1 matches the
// CSS exactly as read on 2026-09-17.
//
// Structure follows `carcare_customer_mobile/lib/app/theme/app_theme.dart`
// (`AppColors`, `AppRadii`, `CarCareTheme extends ThemeExtension`), but
// deliberately drops that app's glass (`BackdropFilter`) surfaces — the
// dashboard is a dense data tool, not a consumer marketing surface. Panels
// here are flat with a 1px border, matching `.landing-ops` (10px radius on
// panels / `rounded-[10px]`, 8px on compact controls, per the slice spec).
// ─────────────────────────────────────────────────────────────────────────

/// Persists the user's theme choice across launches.
///
/// Uses its own small Hive box rather than [Authenticator]'s pattern
/// (`lib/core/services/auth_storage.dart`) verbatim: that box stores a typed
/// `User` object and needs a generated `TypeAdapter`; a single theme-mode
/// string needs neither, so a plain `Box<String>` is the right-sized version
/// of the same box/key convention. `Hive.initFlutter()` already runs in
/// `main.dart` before this provider is constructed, so opening the box here
/// (rather than adding another `await X.init()` call to `main.dart`) is
/// enough — this keeps the change inside the files this slice owns.
class ThemeProvider extends ChangeNotifier {
  static const _boxName = 'settings';
  static const _key = 'themeMode';

  ThemeProvider() {
    unawaited(_restore());
  }

  ThemeMode mode = ThemeMode.light;
  bool get userChoosedSystem => mode == ThemeMode.system;

  Future<void> _restore() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final restored = _decode(box.get(_key));
      if (restored != null && restored != mode) {
        mode = restored;
        notifyListeners();
      }
    } catch (_) {
      // No persisted box yet, or Hive isn't available in this environment
      // (e.g. a unit test with no plugin bindings) — keep the ThemeMode.light
      // default rather than throwing out of a constructor.
    }
  }

  /// Was previously unreachable: the missing `return` after the `if` branch
  /// meant every call fell through and unconditionally set `mode = dark`, so
  /// starting from dark could never get back to light. Fixed by making this
  /// a plain toggle, and persisting the result.
  ///
  /// The in-memory toggle is synchronous and always completes immediately;
  /// persistence is dispatched with [unawaited] rather than `await`ed here,
  /// so a slow or stuck disk/box can never delay (or, worse, hang) the
  /// caller — toggling the theme must never be gated on I/O.
  Future<void> toggleTheme() async {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    unawaited(_persist(mode));
  }

  Future<void> _persist(ThemeMode value) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_key, _encode(value));
    } catch (_) {
      // Persistence is best-effort; the in-memory toggle already happened
      // and must not be rolled back if the disk write fails.
    }
  }

  static String _encode(ThemeMode m) => m == ThemeMode.dark ? 'dark' : 'light';

  static ThemeMode? _decode(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return null;
    }
  }
}

/// IBM Plex family names, as registered in `pubspec.yaml`'s `fonts:` block.
///
/// Bundled binaries: IBM Plex Sans 400/500/600/700 and IBM Plex Mono 400/500,
/// fetched from IBM's official `IBM/plex` GitHub repo (SIL Open Font License
/// 1.1 — redistribution permitted; license copies live alongside the font
/// files at `asset/fonts/IBMPlexSans/OFL.txt` and
/// `asset/fonts/IBMPlexMono/OFL.txt`).
///
/// Poppins stays the app's default `fontFamily` for this slice — every
/// existing screen relies on it implicitly (none hardcode a
/// family), and flipping the app-wide default is a typography-wide visual
/// change to 40+ read-only feature files, not a theme-definition change.
/// That migration is explicitly out of this slice's scope (see the slice
/// spec: "Keep Poppins bundled — feature screens still reference it;
/// removing it is a later slice's job"). IBM Plex Mono is wired here and
/// ready to use — `CarCareTheme.monoFontFamily` — for tabular content order
/// numbers, plates, money) the next time those widgets are touched; no
/// existing screen was edited to adopt it in this slice (that would be
/// restyling a read-only file).
abstract final class AppFonts {
  static const sans = 'IBM Plex Sans';
  static const mono = 'IBM Plex Mono';
}

/// Legacy, brightness-agnostic palette. Every field name below is unchanged
/// from the pre-P0-F3 navy/blue theme — over 300 call sites across 40+
/// feature files (read-only for this slice) reference these as literal
/// `Color` constants, not through `Theme.of(context)`, so renaming or
/// removing any of them would break compilation in files this slice must
/// not touch. What changed is only the *value* each name maps to: every
/// entry now carries the Ops Console token it plays the equivalent role
/// for (see the class-level comment above for the source line range).
///
/// Because these are static consts, not `Theme.of(context)` lookups, they
/// can react to [ThemeMode] through the runtime palette and typography
/// accessors below.
/// Runtime aliases for the legacy palette names used by the pre-parity
/// widgets. Unlike [AppColors], these resolve through the active
/// [CarCareTheme] so switching brightness updates existing presentation code.
/// New widgets should prefer the semantic [CarCareTheme] fields directly.
class ThemePalette {
  const ThemePalette(this.theme);
  final CarCareTheme theme;

  // These aliases remain for compatibility only. New call sites should use
  // `accent` for chips/icons and the explicit fixed dark brand surfaces.
  Color get primary => theme.accent;
  Color get primaryLight => theme.accentHi;
  Color get brandSurface => OpsColors.darkCarbon;
  Color get brandSurface2 => OpsColors.darkPanel2;
  Color get accent => theme.accent;
  Color get accentLight => theme.accentHi;
  Color get good => theme.ok;
  Color get warning => theme.warn;
  Color get danger => theme.danger;
  Color get background => theme.shellBackground;
  Color get surface => theme.panel;
  Color get cardBg => theme.panel;
  Color get divider => theme.border;
  Color get textPrimary => theme.ink;
  Color get textSecondary => theme.mutedText;
  Color get textHint => theme.mutedText3;
  Color get textOnDark => Colors.white;
  Color get goodBg => theme.ok.withValues(alpha: 0.12);
  Color get warningBg => theme.warn.withValues(alpha: 0.12);
  Color get dangerBg => theme.danger.withValues(alpha: 0.12);
}

extension ThemePaletteContext on BuildContext {
  ThemePalette get colors => ThemePalette(CarCareTheme.of(this));

  Color checkStatusColor(CheckStatus status) => switch (status) {
    CheckStatus.good => colors.good,
    CheckStatus.warning => colors.warning,
    CheckStatus.danger => colors.danger,
  };

  Color checkStatusBackground(CheckStatus status) =>
      checkStatusColor(status).withValues(alpha: 0.12);
}

/// Full dual-brightness Ops Console tokens, transcribed 1:1 from
/// `carcare.mn/app/globals.css` lines 243–289 (`--oc-*` custom properties).
/// This is the palette [AppTheme] builds `ThemeData`/[CarCareTheme] from for
/// both brightnesses.
abstract final class OpsColors {
  static const darkCarbon = Color(0xFF0B0D10); // --oc-carbon
  static const darkPanel = Color(0xFF0E1116); // --oc-panel
  static const darkPanel2 = Color(0xFF101318); // --oc-panel2
  static const darkLine = Color(0xFF23272E); // --oc-line
  static const darkLine2 = Color(0xFF191D23); // --oc-line2
  static const darkInk = Color(0xFFF4F5F7); // --oc-ink
  static const darkInk2 = Color(0xFFEDEEF0); // --oc-ink2
  static const darkMuted = Color(0xFFA7ADB6); // --oc-muted
  static const darkMuted2 = Color(0xFF8A8F98); // --oc-muted2
  static const darkMuted3 = Color(0xFF6E747E); // --oc-muted3
  static const darkMuted4 = Color(0xFF4A4D54); // --oc-muted4
  static const darkAccent = Color(0xFF22D3EE); // --oc-accent
  static const darkAccentHi = Color(0xFF67E8F9); // --oc-accent-hi
  static const darkOk = Color(0xFF3DDC97); // --oc-ok
  static const darkWarn = Color(0xFFDC7F4F); // --oc-warn
  // Plan §5.1 "Danger" dark row; not an --oc-* token.
  static const darkDanger = Color(0xFFEF4444);

  static const lightCarbon = Color(0xFFF6F5F2); // --oc-carbon (light)
  static const lightPanel = Color(0xFFFFFFFF); // --oc-panel (light)
  static const lightPanel2 = Color(0xFFFAF9F8); // --oc-panel2 (light)
  static const lightLine = Color(0xFFE3E0DA); // --oc-line (light)
  static const lightLine2 = Color(0xFFEAE7E1); // --oc-line2 (light)
  static const lightInk = Color(0xFF16171B); // --oc-ink (light)
  static const lightInk2 = Color(0xFF1E1F24); // --oc-ink2 (light)
  static const lightMuted = Color(0xFF5C6067); // --oc-muted (light)
  static const lightMuted2 = Color(0xFF74787F); // --oc-muted2 (light)
  static const lightMuted3 = Color(0xFF90949B); // --oc-muted3 (light)
  static const lightMuted4 = Color(0xFFB7BABF); // --oc-muted4 (light)
  static const lightAccent = Color(0xFF0E7490); // --oc-accent (light)
  static const lightAccentHi = Color(0xFF0891B2); // --oc-accent-hi (light)
  static const lightOk = Color(0xFF1E9F6E); // --oc-ok (light)
  static const lightWarn = Color(0xFFB45309); // --oc-warn (light)
  // Plan §5.1 "Danger" light row; not an --oc-* token.
  static const lightDanger = Color(0xFFDC2626);

  // `html.light .landing-ops` does not redefine `--oc-on-accent`, so the
  // light theme inherits the dark value too — one constant for both.
  static const onAccent = Color(0xFF14120C); // --oc-on-accent
}

/// Ops Console geometry (slice spec): 10px on panels (web's `rounded-[10px]`),
/// 8px on compact controls (inputs, chips, small buttons).
abstract final class AppRadii {
  static const panel = 10.0;
  static const control = 8.0;
}

@immutable
class CarCareTheme extends ThemeExtension<CarCareTheme> {
  const CarCareTheme({
    required this.shellBackground,
    required this.panel,
    required this.panel2,
    required this.border,
    required this.borderSubtle,
    required this.ink,
    required this.ink2,
    required this.mutedText,
    required this.mutedText2,
    required this.mutedText3,
    required this.accent,
    required this.accentHi,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.monoFontFamily,
  });

  final Color shellBackground;
  final Color panel;
  final Color panel2;
  final Color border;
  final Color borderSubtle;
  final Color ink;
  final Color ink2;
  final Color mutedText;
  final Color mutedText2;
  final Color mutedText3;
  final Color accent;
  final Color accentHi;
  final Color onAccent;
  final Color ok;
  final Color warn;
  final Color danger;

  /// Order numbers, plate numbers, money — anything tabular. Read this
  /// instead of hardcoding `'IBM Plex Mono'` in a widget.
  final String monoFontFamily;

  static CarCareTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<CarCareTheme>() ?? _fallback(theme);
  }

  /// Keeps shared widgets safe in previews, isolated tests, and host apps
  /// that provide a plain [ThemeData] rather than installing our extension.
  /// The fallback deliberately follows Material's active color scheme so it
  /// still tracks the host brightness and custom theme colors.
  static CarCareTheme _fallback(ThemeData theme) {
    final scheme = theme.colorScheme;
    return CarCareTheme(
      shellBackground: theme.scaffoldBackgroundColor,
      panel: scheme.surface,
      panel2: scheme.surface,
      border: scheme.outline,
      borderSubtle: scheme.outlineVariant,
      ink: scheme.onSurface,
      ink2: scheme.onSurface,
      mutedText: scheme.onSurfaceVariant,
      mutedText2: scheme.onSurfaceVariant,
      mutedText3: scheme.onSurfaceVariant,
      accent: scheme.primary,
      accentHi: scheme.secondary,
      onAccent: scheme.onPrimary,
      ok: scheme.tertiary,
      warn: scheme.secondary,
      danger: scheme.error,
      monoFontFamily: AppFonts.mono,
    );
  }

  @override
  CarCareTheme copyWith({
    Color? shellBackground,
    Color? panel,
    Color? panel2,
    Color? border,
    Color? borderSubtle,
    Color? ink,
    Color? ink2,
    Color? mutedText,
    Color? mutedText2,
    Color? mutedText3,
    Color? accent,
    Color? accentHi,
    Color? onAccent,
    Color? ok,
    Color? warn,
    Color? danger,
    String? monoFontFamily,
  }) => CarCareTheme(
    shellBackground: shellBackground ?? this.shellBackground,
    panel: panel ?? this.panel,
    panel2: panel2 ?? this.panel2,
    border: border ?? this.border,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    mutedText: mutedText ?? this.mutedText,
    mutedText2: mutedText2 ?? this.mutedText2,
    mutedText3: mutedText3 ?? this.mutedText3,
    accent: accent ?? this.accent,
    accentHi: accentHi ?? this.accentHi,
    onAccent: onAccent ?? this.onAccent,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    danger: danger ?? this.danger,
    monoFontFamily: monoFontFamily ?? this.monoFontFamily,
  );

  @override
  CarCareTheme lerp(CarCareTheme? other, double t) {
    if (other == null) return this;
    return CarCareTheme(
      shellBackground: Color.lerp(shellBackground, other.shellBackground, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panel2: Color.lerp(panel2, other.panel2, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      mutedText2: Color.lerp(mutedText2, other.mutedText2, t)!,
      mutedText3: Color.lerp(mutedText3, other.mutedText3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHi: Color.lerp(accentHi, other.accentHi, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      // Not interpolable — snap over at the halfway point like other
      // discrete (non-Color) ThemeExtension fields conventionally do.
      monoFontFamily: t < 0.5 ? monoFontFamily : other.monoFontFamily,
    );
  }
}

/// Typography resolved from the active [CarCareTheme]. The metrics match the
/// former static styles exactly; only their semantic foreground colors now
/// follow brightness. `bigNumber` stays white because it is used on an
/// explicit dark dashboard surface.
class ThemeTextStyles {
  const ThemeTextStyles(this.theme);

  final CarCareTheme theme;

  TextStyle get h1 => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: theme.ink,
    height: 1.3,
  );
  TextStyle get h2 => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: theme.ink,
    height: 1.3,
  );
  TextStyle get h3 =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.ink);
  TextStyle get body =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: theme.ink);
  TextStyle get bodyMedium =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.ink);
  TextStyle get caption => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: theme.mutedText,
  );
  TextStyle get captionMedium => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: theme.mutedText,
  );
  TextStyle get label => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: theme.mutedText,
  );
  TextStyle get bigNumber => const TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );
  TextStyle get buttonText => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: theme.onAccent,
  );
}

extension ThemeTextStylesContext on BuildContext {
  ThemeTextStyles get textStyles => ThemeTextStyles(CarCareTheme.of(this));
}

class AppDimens {
  AppDimens._();
  static const double radiusXS = 4;
  static const double radiusSM = 8; // AppRadii.control — compact controls
  // Panel radius, per the slice spec: 10px, matching web's `rounded-[10px]`.
  // Was 12 under the navy/blue theme.
  static const double radiusMD = 10;
  static const double radiusLG = 16;
  static const double radiusXL = 20;
  static const double radiusFull = 999;
  static const double paddingXS = 4;
  static const double paddingSM = 8;
  static const double paddingMD = 16;
  static const double paddingLG = 20;
  static const double paddingXL = 24;
  static const double iconSM = 16;
  static const double iconMD = 20;
  static const double iconLG = 24;
  // Ops Console panels are flat (1px border, no shadow) — was 2.
  static const double cardElevation = 0;
  static const double bottomNavHeight = 64;
}

extension CheckStatusTheme on CheckStatus {
  IconData get icon {
    switch (this) {
      case CheckStatus.good:
        return Icons.check_circle;
      case CheckStatus.warning:
        return Icons.warning_amber_rounded;
      case CheckStatus.danger:
        return Icons.cancel;
    }
  }

  String get label {
    switch (this) {
      case CheckStatus.good:
        return 'Хэвийн';
      case CheckStatus.warning:
        return 'Анхаарах';
      case CheckStatus.danger:
        return 'Засвар шаарддагатай';
    }
  }
}

extension InspectionTypeTheme on InspectionType {
  String get label {
    switch (this) {
      case InspectionType.technical:
        return 'Техникийн оношилгоо';
      case InspectionType.routine:
        return 'Ердийн үзлэг';
      case InspectionType.repair:
        return 'Засварын дараах';
    }
  }
}

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final shellBackground = dark ? OpsColors.darkCarbon : OpsColors.lightCarbon;
    final panel = dark ? OpsColors.darkPanel : OpsColors.lightPanel;
    final panel2 = dark ? OpsColors.darkPanel2 : OpsColors.lightPanel2;
    final border = dark ? OpsColors.darkLine : OpsColors.lightLine;
    final borderSubtle = dark ? OpsColors.darkLine2 : OpsColors.lightLine2;
    final ink = dark ? OpsColors.darkInk : OpsColors.lightInk;
    final ink2 = dark ? OpsColors.darkInk2 : OpsColors.lightInk2;
    final mutedText = dark ? OpsColors.darkMuted : OpsColors.lightMuted;
    final mutedText2 = dark ? OpsColors.darkMuted2 : OpsColors.lightMuted2;
    final mutedText3 = dark ? OpsColors.darkMuted3 : OpsColors.lightMuted3;
    final accent = dark ? OpsColors.darkAccent : OpsColors.lightAccent;
    final accentHi = dark ? OpsColors.darkAccentHi : OpsColors.lightAccentHi;
    final ok = dark ? OpsColors.darkOk : OpsColors.lightOk;
    final warn = dark ? OpsColors.darkWarn : OpsColors.lightWarn;
    final danger = dark ? OpsColors.darkDanger : OpsColors.lightDanger;

    final extension = CarCareTheme(
      shellBackground: shellBackground,
      panel: panel,
      panel2: panel2,
      border: border,
      borderSubtle: borderSubtle,
      ink: ink,
      ink2: ink2,
      mutedText: mutedText,
      mutedText2: mutedText2,
      mutedText3: mutedText3,
      accent: accent,
      accentHi: accentHi,
      onAccent: OpsColors.onAccent,
      ok: ok,
      warn: warn,
      danger: danger,
      monoFontFamily: AppFonts.mono,
    );

    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: shellBackground,
    );
    final scheme = base.copyWith(
      primary: accent,
      onPrimary: OpsColors.onAccent,
      primaryContainer: dark ? panel2 : const Color(0xFFCFFAFE),
      onPrimaryContainer: dark ? accentHi : OpsColors.lightAccent,
      secondary: accentHi,
      onSecondary: OpsColors.onAccent,
      tertiary: ok,
      error: danger,
      surface: panel,
      onSurface: ink,
      onSurfaceVariant: mutedText,
      outline: border,
      outlineVariant: borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // See AppFonts' doc comment: Poppins stays the app-wide default this
      // slice, IBM Plex Sans is not force-applied to existing screens.
      fontFamily: 'Poppins',
      colorScheme: scheme,
      scaffoldBackgroundColor: shellBackground,
      canvasColor: shellBackground,
      extensions: [extension],
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: border)),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        iconTheme: IconThemeData(color: ink),
        systemOverlayStyle: dark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
      ),
      // Flat panel + 1px line, per the slice spec ("no glass surfaces",
      // matching `.landing-ops`) — no elevation/shadow, 10px radius.
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimens.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: OpsColors.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingLG,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: accent,
          foregroundColor: OpsColors.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mutedText,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingLG,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: mutedText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMD,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: accentHi, width: 1.5),
        ),
        hintStyle: TextStyle(color: mutedText),
        prefixIconColor: mutedText,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      dividerColor: border,
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: mutedText,
        indicatorColor: accent,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accentHi),
    );
  }
}
