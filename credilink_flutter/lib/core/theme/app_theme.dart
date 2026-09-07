import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cred_theme.dart';

class AppTheme {
  static const Color primary = CredTheme.primary;
  static const Color primaryDark = CredTheme.primaryDark;

  static ThemeData get light {
    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: CredTheme.primary,
      onPrimary: Colors.white,
      secondary: CredTheme.primaryDark,
      onSecondary: Colors.white,
      error: CredTheme.danger,
      onError: Colors.white,
      surface: CredTheme.cardBackground,
      onSurface: CredTheme.titleText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CredTheme.scaffoldBackground,
      extensions: const [CredThemeExtension()],
      textTheme: baseText.apply(
        bodyColor: CredTheme.titleText,
        displayColor: CredTheme.titleText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CredTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: CredTheme.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CredTheme.radiusCard),
          side: const BorderSide(color: CredTheme.border),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CredTheme.inputBackground,
        selectedColor: CredTheme.primary.withValues(alpha: 0.14),
        checkmarkColor: CredTheme.primary,
        deleteIconColor: CredTheme.subtitleText,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: CredTheme.titleText),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CredTheme.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CredTheme.radiusChip),
          side: const BorderSide(color: CredTheme.border),
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: CredTheme.primary.withValues(alpha: 0.4));
          }
          return const BorderSide(color: CredTheme.border);
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CredTheme.cardBackground,
        indicatorColor: CredTheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CredTheme.primary,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: CredTheme.subtitleText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: CredTheme.primary, size: 24);
          }
          return const IconThemeData(color: CredTheme.subtitleText, size: 24);
        }),
        height: 68,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: CredTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(CredTheme.radiusCard)),
        ),
        showDragHandle: true,
      ),
      dividerTheme: const DividerThemeData(color: CredTheme.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CredTheme.radiusCard),
          borderSide: const BorderSide(color: CredTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CredTheme.radiusCard),
          borderSide: const BorderSide(color: CredTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CredTheme.radiusCard),
          borderSide: const BorderSide(color: CredTheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd, vertical: 14),
        hintStyle: GoogleFonts.plusJakartaSans(color: CredTheme.placeholder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CredTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CredTheme.radiusInput),
          ),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CredTheme.primary,
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: CredTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CredTheme.radiusInput),
          ),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
