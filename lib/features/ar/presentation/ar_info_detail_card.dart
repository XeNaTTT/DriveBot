import 'package:flutter/material.dart';

import '../../hud/domain/hud_warning_item.dart';
import '../domain/ar_info_object.dart';

class ArInfoDetailCard extends StatelessWidget {
  const ArInfoDetailCard({
    required this.infoObject,
    required this.onClose,
    super.key,
  });

  final ArInfoObject infoObject;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 230),
          child: Container(
            key: const Key('ar-info-detail-card'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xAA57E3FF), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconFor(infoObject.type),
                        color: _colorFor(infoObject.type),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              infoObject.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              infoObject.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onClose,
                        child: const Text('Schließen'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _detailRows(infoObject)
                        .map(
                          (row) =>
                              _DetailPill(label: row.label, value: row.value),
                        )
                        .toList(growable: false),
                  ),
                  if (infoObject.description != null &&
                      infoObject.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      infoObject.description!,
                      key: const Key('ar-detail-description'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (infoObject.actionButtons.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: infoObject.actionButtons
                          .map(
                            (action) => OutlinedButton(
                              onPressed: action.enabled ? () {} : null,
                              child: Text(action.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_DetailRow> _detailRows(ArInfoObject object) {
    final rows = <_DetailRow>[
      _DetailRow('Typ', object.typeLabel),
      _DetailRow('Entfernung', object.formattedDistance),
      _DetailRow('Quelle', object.sourceLabel),
    ];

    switch (object.type) {
      case WarningType.speedCamera:
        if (object.validityLabel != null) {
          rows.add(_DetailRow('Gültig bis', object.validityLabel!));
        }
        if (object.createdAtLabel != null) {
          rows.add(_DetailRow('Gemeldet am', object.createdAtLabel!));
        }
        if (object.confidenceLabel != null) {
          rows.add(_DetailRow('Genauigkeit', object.confidenceLabel!));
        }
        rows.add(_DetailRow('Vertrauen', _confidenceText(object)));
        if (object.syncStatusLabel != null) {
          rows.add(_DetailRow('Status', object.syncStatusLabel!));
        }
      case WarningType.roadwork || WarningType.speedLimit || WarningType.notice:
        if (object.warning.roadId != null) {
          rows.add(_DetailRow('Autobahn / Straße', object.warning.roadId!));
        }
        if (object.validityLabel != null) {
          rows.add(_DetailRow('Gültigkeit', object.validityLabel!));
        }
      case WarningType.chargingStation:
        rows.add(_DetailRow('Verfügbarkeit', 'unbekannt'));
      case WarningType.weather:
        rows.add(_DetailRow('Risiko', 'Stufe ${object.warning.severity}'));
        if (object.validityLabel != null) {
          rows.add(_DetailRow('Gültigkeit', object.validityLabel!));
        }
    }
    return rows;
  }

  String _confidenceText(ArInfoObject object) =>
      switch (object.distanceConfidence.name) {
        'high' => 'hoch',
        'medium' => 'mittel',
        'low' => 'niedrig',
        _ => 'unbekannt',
      };

  IconData _iconFor(WarningType type) => switch (type) {
    WarningType.speedCamera => Icons.photo_camera_outlined,
    WarningType.speedLimit => Icons.speed_outlined,
    WarningType.roadwork => Icons.construction_outlined,
    WarningType.weather => Icons.thunderstorm_outlined,
    WarningType.chargingStation => Icons.ev_station_outlined,
    WarningType.notice => Icons.info_outline,
  };

  Color _colorFor(WarningType type) => switch (type) {
    WarningType.speedCamera => const Color(0xFFFF7B72),
    WarningType.speedLimit => const Color(0xFFFFC857),
    WarningType.roadwork => const Color(0xFFFFA94D),
    WarningType.weather => const Color(0xFF74C0FC),
    WarningType.chargingStation => const Color(0xFF63E6BE),
    WarningType.notice => const Color(0xFFD0BFFF),
  };
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 36, maxWidth: 190),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}
