import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CrediLink “Tidal Trust” design tokens — teal primary, cool mist surfaces.
class CredTheme {
  CredTheme._();

  // Brand
  static const Color primary = Color(0xFF0E7490);
  static const Color primaryDark = Color(0xFF155E75);

  // Surfaces
  static const Color scaffoldBackground = Color(0xFFF0F9FB);
  static const Color authBackground = Color(0xFFE8F6F9);
  static const Color cardBackground = Colors.white;
  static const Color inputBackground = Color(0xFFF5FBFC);

  // Text
  static const Color titleText = Color(0xFF0F172A);
  static const Color subtitleText = Color(0xFF64748B);
  static const Color placeholder = Color(0xFF94A3B8);
  static const Color bodyMuted = Color(0xFF64748B);

  // Borders
  static const Color border = Color(0xFFCDE7EE);
  static const Color borderHover = Color(0xFFA5D4E0);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0E7490);

  // Role selector / info boxes
  static const Color roleInactiveBg = Color(0xFFF5FBFC);
  static const Color infoBoxBg = Color(0xFFE8F6F9);

  // Spacing
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // Radii
  static const double radiusCard = 14;
  static const double radiusInput = 10;
  static const double radiusChip = 12;
  static const double radiusRole = 10;
  static const double radiusLogo = 18;

  // Auth layout
  static const double authMaxWidth = 440;
  static const double logoSize = 88;
  static const EdgeInsets authCardPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 32);

  // Page layout
  static const EdgeInsets pagePadding = EdgeInsets.all(spaceMd);

  static TextStyle brandWordmark(BuildContext context, {double fontSize = 36}) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: titleText,
        height: 1.1,
        letterSpacing: -0.5,
      );

  static TextStyle pageTitle(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: titleText,
      );

  static TextStyle sectionTitle(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: titleText,
        letterSpacing: 0.15,
      );

  static TextStyle bodyMutedStyle(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: bodyMuted,
      );

  static TextStyle metricValue(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: titleText,
      );

  static TextStyle metricAmountStyle(BuildContext context) =>
      metricValue(context).copyWith(fontSize: 28, letterSpacing: -0.4);

  static TextStyle listAmountStyle(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: titleText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle appBarContextStyle(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      );
}

/// Theme extension for accessing CredTheme via [Theme.of(context).extension].
class CredThemeExtension extends ThemeExtension<CredThemeExtension> {
  const CredThemeExtension({
    this.success = CredTheme.success,
    this.warning = CredTheme.warning,
    this.danger = CredTheme.danger,
    this.info = CredTheme.info,
    this.subtitleText = CredTheme.subtitleText,
    this.cardBackground = CredTheme.cardBackground,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color subtitleText;
  final Color cardBackground;

  static CredThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<CredThemeExtension>() ??
      const CredThemeExtension();

  @override
  CredThemeExtension copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? subtitleText,
    Color? cardBackground,
  }) {
    return CredThemeExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      subtitleText: subtitleText ?? this.subtitleText,
      cardBackground: cardBackground ?? this.cardBackground,
    );
  }

  @override
  CredThemeExtension lerp(ThemeExtension<CredThemeExtension>? other, double t) {
    if (other is! CredThemeExtension) return this;
    return CredThemeExtension(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
      subtitleText: Color.lerp(subtitleText, other.subtitleText, t) ?? subtitleText,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
    );
  }
}
