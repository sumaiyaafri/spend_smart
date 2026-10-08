import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({super.key, required this.category, this.size = 44});

  static IconData getIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant_rounded;

      case 'Transport':
        return Icons.directions_bus_rounded;

      case 'Shopping':
        return Icons.shopping_bag_rounded;

      case 'Bills':
        return Icons.receipt_long_rounded;

      case 'Health':
        return Icons.favorite_rounded;

      case 'Education':
        return Icons.menu_book_rounded;

      case 'Entertainment':
        return Icons.movie_rounded;

      default:
        return Icons.more_horiz_rounded;
    }
  }

  static Color getColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return const Color(0xFFFF9F43);

      case 'Transport':
        return const Color(0xFF4A90E2);

      case 'Shopping':
        return const Color(0xFFFF6B6B);

      case 'Bills':
        return const Color(0xFF8E67E8);

      case 'Health':
        return const Color(0xFFE74C6F);

      case 'Education':
        return const Color(0xFF10A37F);

      case 'Entertainment':
        return const Color(0xFF7950F2);

      default:
        return const Color(0xFF78909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(getIcon(category), color: color, size: size * .52),
    );
  }
}
