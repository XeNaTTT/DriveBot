import 'package:flutter/material.dart';

import '../../hud/domain/hud_warning_item.dart';
import '../../reports/presentation/speed_camera_ar_marker.dart';
import '../domain/ar_marker_model.dart';
import 'ar_marker_widget.dart';

class ArMarkerLayer extends StatelessWidget {
  const ArMarkerLayer({
    required this.markers,
    this.selectedInfoObjectId,
    this.onMarkerTap,
    super.key,
  });

  final List<ArMarkerModel> markers;
  final String? selectedInfoObjectId;
  final ValueChanged<String>? onMarkerTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const markerWidth = 170.0;
          const edgePadding = 8.0;
          return Stack(
            children: markers
                .map((marker) {
                  final object = marker.infoObject;
                  final rawLeft =
                      (marker.normalizedX * constraints.maxWidth) -
                      (markerWidth / 2);
                  final left = rawLeft.clamp(
                    edgePadding,
                    constraints.maxWidth - markerWidth - edgePadding,
                  );
                  final top = (marker.top * constraints.maxHeight).clamp(
                    24.0,
                    constraints.maxHeight - 72.0,
                  );
                  final selected = selectedInfoObjectId == object.id;
                  return Positioned(
                    left: left,
                    top: top,
                    width: markerWidth,
                    child: KeyedSubtree(
                      key: Key('ar-marker-${object.id}'),
                      child: object.type == WarningType.speedCamera
                          ? SpeedCameraArMarker(
                              key: Key('ar-marker-${object.type.name}'),
                              infoObject: object,
                              selected: selected,
                              onTap: () => onMarkerTap?.call(object.id),
                            )
                          : ArMarkerWidget(
                              key: Key('ar-marker-${object.type.name}'),
                              infoObject: object,
                              selected: selected,
                              onTap: () => onMarkerTap?.call(object.id),
                            ),
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }
}
