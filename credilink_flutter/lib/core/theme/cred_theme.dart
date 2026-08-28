import 'package:flutter/material.dart';

/// Unified design tokens — v1 Ionic baseline (#3880FF primary, grey surfaces).
class CredTheme {
  CredTheme._();

  // Brand
  static const Color primary = Color(0xFF3880FF);
  static const Color primaryDark = Color(0xFF3171E0);

  // Surfaces
  static const Color scaffoldBackground = Color(0xFFF4F5F8);
  static const Color authBackground = Color(0xFFF8F9FA);
  static const Color cardBackground = Colors.white;
  static const Color inputBackground = Color(0xFFF8F9FA);

  // Text
  static const Color titleText = Color(0xFF212529);
  static const Color subtitleText = Color(0xFF6C757D);
  static const Color placeholder = Color(0xFFADB5BD);
  static const Color bodyMuted = Color(0xFF6C757D);

  // Borders
  static const Color border = Color(0xFFE9ECEF);
  static const Color borderHover = Color(0xFFDEE2E6);

  // Semantic (v1 Ionic)
  static const Color success = Color(0xFF2DD36F);
  static const Color warning = Color(0xFFFFC409);
  static const Color danger = Color(0xFFEB445A);
  static const Color info = Color(0xFF3880FF);

  // Role selector / info boxes
  static const Color roleInactiveBg = Color(0xFFF8F9FA);
  static const Color infoBoxBg = Color(0xFFF8F9FA);

  // Spacing
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // Radii
  static const double radiusCard = 12;
  static const double radiusInput = 8;
  static const double radiusChip = 12;
  static const double radiusRole = 8;
  static const double radiusLogo = 16;

  // Auth layout
  static const double authMaxWidth = 440;
  static const double logoSize = 80;
  static const EdgeInsets authCardPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 32);

  // Page layout
  static const EdgeInsets pagePadding = EdgeInsets.all(spaceMd);

  static TextStyle pageTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: titleText,
          ) ??
      const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: titleText);

  static TextStyle sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: titleText,
          ) ??
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleText);

  static TextStyle bodyMutedStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(color: bodyMuted) ??
      const TextStyle(fontSize: 14, color: bodyMuted);

  static TextStyle metricValue(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: titleText,
          ) ??
      const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: titleText);
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
