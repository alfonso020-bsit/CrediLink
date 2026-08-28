import 'package:flutter/material.dart';

import 'cred_theme.dart';

/// Auth layout tokens — delegates to [CredTheme] for backward compatibility.
class AuthTheme {
  AuthTheme._();

  static const Color background = CredTheme.authBackground;
  static const Color cardBackground = CredTheme.cardBackground;
  static const Color border = CredTheme.border;
  static const Color borderHover = CredTheme.borderHover;
  static const Color titleText = CredTheme.titleText;
  static const Color subtitleText = CredTheme.subtitleText;
  static const Color inputBackground = CredTheme.inputBackground;
  static const Color placeholder = CredTheme.placeholder;
  static const Color roleInactiveBg = CredTheme.roleInactiveBg;
  static const Color infoBoxBg = CredTheme.infoBoxBg;

  static const double maxWidth = CredTheme.authMaxWidth;
  static const double cardRadius = CredTheme.radiusCard;
  static const double inputRadius = CredTheme.radiusInput;
  static const double roleRadius = CredTheme.radiusRole;
  static const double logoSize = CredTheme.logoSize;
  static const double logoRadius = CredTheme.radiusLogo;

  static const EdgeInsets cardPadding = CredTheme.authCardPadding;
}
