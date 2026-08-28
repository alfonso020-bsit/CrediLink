import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';



import '../../core/theme/cred_theme.dart';

import '../../shared/widgets/auth/cred_buttons.dart';



class LandingScreen extends StatelessWidget {

  const LandingScreen({super.key});



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: CredTheme.authBackground,

      appBar: AppBar(title: const Text('CrediLink')),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(CredTheme.spaceLg),

          child: Column(

            children: [

              const Spacer(),

              Container(

                width: CredTheme.logoSize,

                height: CredTheme.logoSize,

                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(

                  color: CredTheme.cardBackground,

                  borderRadius: BorderRadius.circular(CredTheme.radiusLogo),

                  border: Border.all(color: CredTheme.border),

                ),

                child: Image.asset(

                  'assets/images/logo.jpg',

                  fit: BoxFit.contain,

                  errorBuilder: (_, __, ___) => Icon(

                    Icons.storefront,

                    size: 48,

                    color: Theme.of(context).colorScheme.primary,

                  ),

                ),

              ),

              const SizedBox(height: CredTheme.spaceMd),

              Text(

                'CrediLink',

                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),

              ),

              const SizedBox(height: CredTheme.spaceXs),

              Text(

                'Sari-Sari Store Management System',

                textAlign: TextAlign.center,

                style: CredTheme.bodyMutedStyle(context),

              ),

              const SizedBox(height: CredTheme.spaceXl),

              _feature(context, Icons.receipt, 'POS System', 'Fast point-of-sale transactions'),

              _feature(context, Icons.people, 'Debt Tracking', 'Monitor customer debts'),

              _feature(context, Icons.inventory_2, 'Inventory', 'Real-time stock levels'),

              _feature(context, Icons.bar_chart, 'Reports', 'Sales and analytics'),

              const Spacer(),

              CredPrimaryButton(label: 'Login', onPressed: () => context.go('/login')),

              const SizedBox(height: CredTheme.spaceSm),

              CredOutlineButton(label: 'Register', onPressed: () => context.go('/register')),

              const SizedBox(height: CredTheme.spaceMd),

              Text(

                '© ${DateTime.now().year} CrediLink',

                style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 12),

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _feature(BuildContext context, IconData icon, String title, String desc) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: CredTheme.spaceXs),

      child: Row(

        children: [

          Icon(icon, color: CredTheme.primary),

          const SizedBox(width: CredTheme.spaceMd),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

                Text(desc, style: CredTheme.bodyMutedStyle(context).copyWith(fontSize: 13)),

              ],

            ),

          ),

        ],

      ),

    );

  }

}


