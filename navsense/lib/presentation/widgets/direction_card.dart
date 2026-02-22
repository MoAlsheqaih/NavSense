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
    return Card(
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              instruction,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color get _cardColor {
    switch (direction) {
      case TurnDirection.left:
        return AppTheme.primaryColor;
      case TurnDirection.right:
        return AppTheme.primaryColor;
      case TurnDirection.straight:
        return AppTheme.accentColor;
      case TurnDirection.arrived:
        return AppTheme.successColor;
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
