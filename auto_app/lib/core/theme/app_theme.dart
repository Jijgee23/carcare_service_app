import 'package:flutter/material.dart';

// ─────────────────────────────────────────
//  COLOR PALETTE
// ─────────────────────────────────────────
class AppColors {
  AppColors._();

  // Primary – dark navy (header, bottom bar)
  static const Color primary = Color(0xFF1A2340);
  static const Color primaryLight = Color(0xFF243057);

  // Accent blue (buttons, active tab)
  static const Color accent = Color(0xFF3B6FF5);
  static const Color accentLight = Color(0xFF5B87FF);

  // Status colors
  static const Color good = Color(0xFF22C55E);      // Хэвийн
  static const Color warning = Color(0xFFF59E0B);   // Анхаарах
  static const Color danger = Color(0xFFEF4444);    // Засвар шаарддагатай

  // Neutral
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8ECF2);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Badge backgrounds (soft)
  static const Color goodBg = Color(0xFFDCFCE7);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color dangerBg = Color(0xFFFEE2E2);
}

// ─────────────────────────────────────────
//  TEXT STYLES
// ─────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Roboto';

  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle captionMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle bigNumber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnDark,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnDark,
  );
}

// ─────────────────────────────────────────
//  DIMENSIONS
// ─────────────────────────────────────────
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

// ─────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          secondary: AppColors.primary,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDark,
          ),
          iconTheme: IconThemeData(color: AppColors.textOnDark),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.primary,
          selectedItemColor: AppColors.textOnDark,
          unselectedItemColor: Color(0xFF8896B3),
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 10),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: AppColors.cardBg,
          elevation: AppDimens.cardElevation,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLG),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textOnDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingLG,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            textStyle: AppTextStyles.buttonText,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.divider),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingLG,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            textStyle: AppTextStyles.buttonText.copyWith(color: AppColors.textSecondary),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingMD,
            vertical: 14,
          ),
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
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 13),
        ),
      );
}
