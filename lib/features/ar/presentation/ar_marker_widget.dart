import 'package:flutter/material.dart';

import '../../hud/domain/hud_warning_item.dart';

class ArMarkerWidget extends StatelessWidget {
  const ArMarkerWidget({required this.warning, super.key});

  final HudWarningItem warning;

  @override
  Widget build(BuildContext context) {
    final color = switch (warning.type) {
      WarningType.speedCamera => const Color(0xFFFF7B72),
      WarningType.speedLimit => const Color(0xFFFFC857),
      WarningType.roadwork => const Color(0xFFFFA94D),
      WarningType.weather => const Color(0xFF74C0FC),
      WarningType.chargingStation => const Color(0xFF63E6BE),
      WarningType.notice => const Color(0xFFD0BFFF),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: 14, color: color.withValues(alpha: 0.7)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.1),
            color: Colors.black.withValues(alpha: 0.35),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${warning.title} · ${warning.distanceMeters} m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
