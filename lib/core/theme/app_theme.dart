import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_spacing.dart';

class AppColors {
  AppColors._();

  // Dark — refined developer aesthetic
  static const Color darkBg = Color(0xFF0B0F14);
  static const Color darkSurface = Color(0xFF131920);
  static const Color darkSurfaceElevated = Color(0xFF1A222D);
  static const Color darkBorder = Color(0xFF2A3441);
  static const Color darkTextPrimary = Color(0xFFE8EDF4);
  static const Color darkTextSecondary = Color(0xFF8B9BB0);
  static const Color darkTextTertiary = Color(0xFF5C6B7E);

  // Light
  static const Color lightBg = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF8FAFC);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Brand
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentDeep = Color(0xFF2563EB);
  static const Color accentSoft = Color(0xFF60A5FA);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color star = Color(0xFFFBBF24);

  static const Map<String, Color> languageColors = {
    'Dart': Color(0xFF00B4AB),
    'Python': Color(0xFF3572A5),
    'JavaScript': Color(0xFFF7DF1E),
    'TypeScript': Color(0xFF3178C6),
    'Java': Color(0xFFB07219),
    'Kotlin': Color(0xFFA97BFF),
    'Swift': Color(0xFFF05138),
    'C++': Color(0xFFF34B7D),
    'C': Color(0xFF555555),
    'C#': Color(0xFF178600),
    'Go': Color(0xFF00ADD8),
    'Rust': Color(0xFFDEA584),
    'Ruby': Color(0xFFCC342D),
    'HTML': Color(0xFFE34C26),
    'CSS': Color(0xFF563D7C),
  };

  static Color colorForLanguage(String? language) {
    if (language == null) return darkTextTertiary;
    return languageColors[language] ?? const Color(0xFF8B949E);
  }
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration pageGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                AppColors.darkBg,
                const Color(0xFF0E1420),
                AppColors.darkBg,
              ]
            : [
                AppColors.lightBg,
                const Color(0xFFEEF2F7),
                AppColors.lightBg,
              ],
      ),
    );
  }

  static BoxDecoration splashGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B0F14),
          Color(0xFF111827),
          Color(0xFF0F172A),
        ],
      ),
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      displayColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE),
      onPrimaryContainer: isDark ? AppColors.accentSoft : AppColors.accentDeep,
      secondary: AppColors.accentDeep,
      onSecondary: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      onSurfaceVariant: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      outline: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      outlineVariant: isDark ? AppColors.darkBorder.withValues(alpha: 0.6) : AppColors.lightBorder,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      colorScheme: colorScheme,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        selectedColor: AppColors.accent.withValues(alpha: isDark ? 0.22 : 0.14),
        disabledColor: isDark ? AppColors.darkSurface : AppColors.lightSurfaceElevated,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        indicatorColor: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.accent
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected
                ? AppColors.accent
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent.withValues(alpha: isDark ? 0.22 : 0.14);
            }
            return isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.accent;
            return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        iconColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? AppColors.darkTextPrimary : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.accent,
        textColor: Colors.white,
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class AdaptiveIcons {
  AdaptiveIcons._();

  static IconData get back => _isIOS ? CupertinoIcons.back : Icons.arrow_back_rounded;
  static IconData get search => _isIOS ? CupertinoIcons.search : Icons.search_rounded;
  static IconData get settings => _isIOS ? CupertinoIcons.settings : Icons.tune_rounded;
  static IconData get history => _isIOS ? CupertinoIcons.clock : Icons.history_rounded;
  static IconData get star => _isIOS ? CupertinoIcons.star_fill : Icons.star_rounded;
  static IconData get starOutline => _isIOS ? CupertinoIcons.star : Icons.star_outline_rounded;
  static IconData get share => _isIOS ? CupertinoIcons.share : Icons.ios_share_rounded;
  static IconData get filter => _isIOS ? CupertinoIcons.slider_horizontal_3 : Icons.tune_rounded;
  static IconData get fork => _isIOS ? CupertinoIcons.arrow_branch : Icons.call_split_rounded;
  static IconData get person => _isIOS ? CupertinoIcons.person : Icons.person_rounded;
  static IconData get code => _isIOS ? CupertinoIcons.chevron_left_slash_chevron_right : Icons.code_rounded;
  static IconData get home => _isIOS ? CupertinoIcons.square_grid_2x2_fill : Icons.dashboard_rounded;
  static IconData get delete => _isIOS ? CupertinoIcons.delete : Icons.delete_outline_rounded;
  static IconData get bookmark => _isIOS ? CupertinoIcons.bookmark_fill : Icons.bookmark_rounded;
  static IconData get bookmarkOutline => _isIOS ? CupertinoIcons.bookmark : Icons.bookmark_border_rounded;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
}