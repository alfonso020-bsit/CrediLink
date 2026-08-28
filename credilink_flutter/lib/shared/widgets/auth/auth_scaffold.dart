import 'package:flutter/material.dart';

import '../../../core/theme/auth_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.appBarTitle,
    required this.welcomeTitle,
    required this.child,
    this.welcomeSubtitle,
    this.showBack = false,
    this.onBack,
    this.formFooter,
  });

  /// App bar label: "Login", "Registration", etc.
  final String appBarTitle;
  final String welcomeTitle;
  final String? welcomeSubtitle;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  /// Optional content below the form inside the white card (login role footer).
  final Widget? formFooter;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AuthTheme.background,
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AuthTheme.maxWidth),
              child: Column(
                children: [
                  _LogoHeader(
                    welcomeTitle: welcomeTitle,
                    welcomeSubtitle: welcomeSubtitle,
                  ),
                  const SizedBox(height: 24),
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
                          const SizedBox(height: 24),
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
            errorBuilder: (_, __, ___) => Icon(
              Icons.storefront_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
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
