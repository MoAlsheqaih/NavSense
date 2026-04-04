import 'package:flutter/material.dart';

import '../../domain/entities/route_plan.dart';
import '../../core/theme/app_theme.dart';

class DirectionCard extends StatelessWidget {
  final TurnDirection direction;
  final String instruction;

  const DirectionCard({
    Key? key,
    required this.direction,
    required this.instruction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = _gradientColors;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            instruction,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Color> get _gradientColors {
    switch (direction) {
      case TurnDirection.left:
        return [const Color(0xFF1A3A8F), AppTheme.primaryColor];
      case TurnDirection.right:
        return [AppTheme.primaryColor, const Color(0xFF1A3A8F)];
      case TurnDirection.straight:
        return [const Color(0xFF0D47A1), AppTheme.accentColor];
      case TurnDirection.arrived:
        return [const Color(0xFF1B5E20), AppTheme.successColor];
    }
  }

  IconData get _icon {
    switch (direction) {
      case TurnDirection.left:
        return Icons.turn_left;
      case TurnDirection.right:
        return Icons.turn_right;
      case TurnDirection.straight:
        return Icons.straight;
      case TurnDirection.arrived:
        return Icons.flag;
    }
  }
}
