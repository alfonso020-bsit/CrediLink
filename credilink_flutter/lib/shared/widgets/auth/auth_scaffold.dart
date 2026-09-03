import 'package:flutter/material.dart';

import '../../../core/theme/auth_theme.dart';
import '../../../core/theme/cred_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.welcomeTitle,
    required this.child,
    this.welcomeSubtitle,
    this.showBack = false,
    this.onBack,
    this.formFooter,
  });

  final String welcomeTitle;
  final String? welcomeSubtitle;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? formFooter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.background,
      appBar: showBack
          ? AppBar(
              backgroundColor: AuthTheme.background,
              foregroundColor: AuthTheme.titleText,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: CredTheme.spaceMd, vertical: CredTheme.spaceMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AuthTheme.maxWidth),
              child: Column(
                children: [
                  _LogoHeader(
                    welcomeTitle: welcomeTitle,
                    welcomeSubtitle: welcomeSubtitle,
                  ),
                  const SizedBox(height: CredTheme.spaceLg),
                  Container(
                    width: double.infinity,
                    padding: AuthTheme.cardPadding,
                    decoration: BoxDecoration(
                      color: AuthTheme.cardBackground,
                      borderRadius: BorderRadius.circular(AuthTheme.cardRadius),
                      border: Border.all(color: AuthTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        child,
                        if (formFooter != null) ...[
                          const SizedBox(height: CredTheme.spaceLg),
                          formFooter!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({
    required this.welcomeTitle,
    this.welcomeSubtitle,
  });

  final String welcomeTitle;
  final String? welcomeSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: AuthTheme.logoSize,
          height: AuthTheme.logoSize,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AuthTheme.logoRadius),
            border: Border.all(color: AuthTheme.border),
          ),
          child: Image.asset(
            'assets/images/logo.jpg',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.storefront_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: CredTheme.spaceMd),
        Text(
          welcomeTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AuthTheme.titleText,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (welcomeSubtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            welcomeSubtitle!,
            style: const TextStyle(
              fontSize: 14,
              color: AuthTheme.subtitleText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
