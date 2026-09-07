import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/cred_theme.dart';
import '../../shared/widgets/auth/cred_buttons.dart';
import '../../shared/widgets/layout/cred_fade_in.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CredTheme.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CredTheme.spaceLg,
            vertical: CredTheme.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              CredFadeIn(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CredTheme.cardBackground,
                        borderRadius: BorderRadius.circular(CredTheme.radiusLogo),
                        border: Border.all(color: CredTheme.border),
                      ),
                      child: Image.asset(
                        'assets/images/logo.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.storefront_rounded,
                          size: 48,
                          color: CredTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: CredTheme.spaceLg),
                    Text(
                      'CrediLink',
                      style: CredTheme.brandWordmark(context, fontSize: 42),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: CredTheme.spaceSm),
                    Text(
                      'Credit that keeps your sari-sari moving',
                      textAlign: TextAlign.center,
                      style: CredTheme.pageTitle(context).copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: CredTheme.spaceXs),
                    Text(
                      'POS, utang tracking, and inventory — built for neighborhood stores.',
                      textAlign: TextAlign.center,
                      style: CredTheme.bodyMutedStyle(context).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              CredFadeIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CredPrimaryButton(
                      label: 'Login',
                      onPressed: () => context.go('/login'),
                    ),
                    const SizedBox(height: CredTheme.spaceSm),
                    CredOutlineButton(
                      label: 'Create an account',
                      onPressed: () => context.go('/register'),
                    ),
                    const SizedBox(height: CredTheme.spaceLg),
                    Text(
                      '© ${DateTime.now().year} CrediLink',
                      textAlign: TextAlign.center,
                      style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
