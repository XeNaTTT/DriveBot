import 'package:flutter/material.dart';

import '../../hud/domain/hud_warning_item.dart';
import '../domain/ar_info_object.dart';

class ArMarkerWidget extends StatelessWidget {
  const ArMarkerWidget({
    required this.infoObject,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final ArInfoObject infoObject;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = switch (infoObject.type) {
      WarningType.speedCamera => const Color(0xFFFF7B72),
      WarningType.speedLimit => const Color(0xFFFFC857),
      WarningType.roadwork => const Color(0xFFFFA94D),
      WarningType.weather => const Color(0xFF74C0FC),
      WarningType.chargingStation => const Color(0xFF63E6BE),
      WarningType.notice => const Color(0xFFD0BFFF),
    };

    return Semantics(
      button: true,
      label: '${infoObject.title}, ${infoObject.formattedDistance}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 1,
              height: 14,
              color: color.withValues(alpha: 0.7),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: selected ? 1.8 : 1.1),
                color: Colors.black.withValues(alpha: selected ? 0.52 : 0.35),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(infoObject.type), size: 16, color: color),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayTitle(infoObject),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _compactSubtitle(infoObject),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WarningType type) => switch (type) {
    WarningType.speedCamera => Icons.photo_camera_outlined,
    WarningType.speedLimit => Icons.speed_outlined,
    WarningType.roadwork => Icons.construction_outlined,
    WarningType.weather => Icons.thunderstorm_outlined,
    WarningType.chargingStation => Icons.ev_station_outlined,
    WarningType.notice => Icons.info_outline,
  };

  String _displayTitle(ArInfoObject object) => switch (object.type) {
    WarningType.speedLimit => 'Tempolimit',
    WarningType.roadwork => object.typeLabel,
    WarningType.weather => 'Wetterwarnung',
    WarningType.chargingStation => 'Ladestation',
    WarningType.notice => 'Hinweis',
    WarningType.speedCamera => object.title,
  };

  String _compactSubtitle(ArInfoObject object) {
    final source = object.sourceLabel.isEmpty ? '' : ' · ${object.sourceLabel}';
    return '${object.formattedDistance}$source';
  }
}
