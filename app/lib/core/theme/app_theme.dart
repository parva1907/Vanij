import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vanij design tokens.
class VanijColors {
  VanijColors._();

  /// Deep forest green — primary brand colour.
  static const Color primary = Color(0xFF1B5E20);

  /// Gold / amber — rupee-coin accent.
  static const Color accent = Color(0xFFF9A825);

  /// Default background (white).
  static const Color background = Color(0xFFFFFFFF);

  /// Secondary background — light green tint.
  static const Color backgroundTint = Color(0xFFF1F8E9);

  /// Inline error banner tint.
  static const Color errorTint = Color(0xFFFEE4E2);

  /// Neutral text on light backgrounds.
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF555555);
  static const Color divider = Color(0xFFE0E0E0);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: VanijColors.primary,
        primary: VanijColors.primary,
        secondary: VanijColors.accent,
        surface: VanijColors.background,
      ),
      scaffoldBackgroundColor: VanijColors.background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.tiroDevanagariSanskrit(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          color: VanijColors.textPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VanijColors.background,
        foregroundColor: VanijColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VanijColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VanijColors.primary,
          side: const BorderSide(color: VanijColors.primary, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VanijColors.backgroundTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VanijColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VanijColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VanijColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: VanijColors.divider),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: VanijColors.primary,
        unselectedItemColor: VanijColors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/// Cards in Vanij always carry a subtle primary-coloured left accent.
class VanijCard extends StatelessWidget {
  const VanijCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: VanijColors.primary, width: 3),
          top: BorderSide(color: VanijColors.divider),
          right: BorderSide(color: VanijColors.divider),
          bottom: BorderSide(color: VanijColors.divider),
        ),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// Inline error banner. Never use a full-screen error page.
class VanijErrorBanner extends StatelessWidget {
  const VanijErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VanijColors.errorTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF97066)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42318), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple green shimmer-style skeleton loader — no spinners.
class VanijSkeleton extends StatelessWidget {
  const VanijSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = 6,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: VanijColors.backgroundTint,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
