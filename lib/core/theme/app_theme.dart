import 'package:carcare_service/features/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  bool get userChoosedSystem => mode == ThemeMode.system;
  void toggleTheme() {
    if (mode == ThemeMode.dark) {
      mode = ThemeMode.light;
      notifyListeners();
    }
    mode = ThemeMode.dark;
    notifyListeners();
  }
}

class AppColors {
  AppColors._();
  static const Color primary = Color(0xFF1A2340);
  static const Color primaryLight = Color(0xFF243057);
  static const Color accent = Color(0xFF3B6FF5);
  static const Color accentLight = Color(0xFF5B87FF);
  static const Color good = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8ECF2);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color goodBg = Color(0xFFDCFCE7);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color dangerBg = Color(0xFFFEE2E2);
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const TextStyle captionMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );
  static const TextStyle bigNumber = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnDark,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnDark,
  );
}

class AppDimens {
  AppDimens._();
  static const double radiusXS = 4;
  static const double radiusSM = 8;
  static const double radiusMD = 12;
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
  static const double cardElevation = 2;
  static const double bottomNavHeight = 64;
}

extension CheckStatusTheme on CheckStatus {
  Color get color {
    switch (this) {
      case CheckStatus.good:
        return AppColors.good;
      case CheckStatus.warning:
        return AppColors.warning;
      case CheckStatus.danger:
        return AppColors.danger;
    }
  }

  Color get bgColor {
    switch (this) {
      case CheckStatus.good:
        return AppColors.goodBg;
      case CheckStatus.warning:
        return AppColors.warningBg;
      case CheckStatus.danger:
        return AppColors.dangerBg;
    }
  }

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

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    // textTheme: GoogleFonts.poppinsTextTheme(),
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      secondary: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.textOnDark),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: AppDimens.cardElevation,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLG)),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLG, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMD)),
        textStyle: AppTextStyles.buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLG, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMD)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMD, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: AppTextStyles.caption,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      indicatorColor: Colors.white,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
    ),
  );
}
