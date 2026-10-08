import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../main/main_screen.dart';
import '../onboarding/onboarding_screen.dart';

class AppLaunchScreen extends StatelessWidget {
  const AppLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (!settings.initialized) {
      return const _OfflineSplash();
    }

    if (!settings.onboardingCompleted) {
      return const OnboardingScreen();
    }

    return const MainScreen();
  }
}

class _OfflineSplash extends StatelessWidget {
  const _OfflineSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF078B67), Color(0xFF04684E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 45,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Spend Smart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Track less. Understand more.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 36),

              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
