import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  int currentPage = 0;

  final List<OnboardingItem> pages = const [
    OnboardingItem(
      icon: Icons.receipt_long_rounded,
      eyebrow: 'SIMPLE TRACKING',
      title: 'Know where your\nmoney goes.',
      description:
          'Quickly record your everyday expenses and keep everything organized without any complicated setup.',
      accent: Color(0xFFFFA558),
      secondaryIcon: Icons.restaurant_rounded,
    ),
    OnboardingItem(
      icon: Icons.donut_large_rounded,
      eyebrow: 'SMART OVERVIEW',
      title: 'Understand your\nspending habits.',
      description:
          'See daily and monthly totals, explore categories and understand how you spend your money.',
      accent: Color(0xFF5C9EFF),
      secondaryIcon: Icons.bar_chart_rounded,
    ),
    OnboardingItem(
      icon: Icons.shield_rounded,
      eyebrow: 'PRIVATE & OFFLINE',
      title: 'Your data stays\nwith you.',
      description:
          'Spend Smart works completely offline. Your expense records stay on your phone without cloud accounts or internet.',
      accent: AppColors.primary,
      secondaryIcon: Icons.phone_android_rounded,
    ),
  ];

  bool get isLastPage => currentPage == pages.length - 1;

  Future<void> _next() async {
    if (isLastPage) {
      await _finish();
      return;
    }

    await _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await context.read<SettingsProvider>().completeOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(item: pages[index], pageIndex: index);
                },
              ),
            ),

            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 10),

              const Text(
                'Spend Smart',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          if (!isLastPage)
            TextButton(
              onPressed: _finish,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (index) {
              final active = currentPage == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 26 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : const Color(0xFFD8E5E1),
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }),
          ),

          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'Get Started' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(width: 9),

                  Icon(
                    isLastPage
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 13),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 5),

              Text(
                'No account • No internet • No cloud',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: .85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final IconData secondaryIcon;

  final String eyebrow;
  final String title;
  final String description;

  final Color accent;

  const OnboardingItem({
    required this.icon,
    required this.secondaryIcon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.accent,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final int pageIndex;

  const _OnboardingPage({required this.item, required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                _buildVisual(),

                const SizedBox(height: 50),

                Text(
                  item.eyebrow,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: item.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    height: 1.12,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 18),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisual() {
    return SizedBox(
      width: 290,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: .06),
              shape: BoxShape.circle,
            ),
          ),

          Positioned(
            top: 26,
            right: 15,
            child: _smallDecoration(
              icon: Icons.add_rounded,
              color: item.accent,
              size: 48,
            ),
          ),

          Positioned(
            bottom: 33,
            left: 14,
            child: _smallDecoration(
              icon: item.secondaryIcon,
              color: item.accent,
              size: 58,
            ),
          ),

          Container(
            width: 185,
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .07),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(item.icon, size: 38, color: item.accent),
                ),

                const SizedBox(height: 23),

                Container(
                  height: 10,
                  width: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  height: 8,
                  width: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  height: 38,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallDecoration({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 20),
        ],
      ),
      child: Icon(icon, size: size * .43, color: color),
    );
  }
}
