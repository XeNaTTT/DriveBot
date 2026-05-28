import 'package:flutter/material.dart';

import '../domain/ar_marker_model.dart';
import 'ar_marker_widget.dart';

class ArMarkerLayer extends StatelessWidget {
  const ArMarkerLayer({required this.markers, super.key});

  final List<ArMarkerModel> markers;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const markerWidth = 170.0;
            const edgePadding = 8.0;
            return Stack(
              children: markers.map((marker) {
                final rawLeft = (marker.normalizedX * constraints.maxWidth) -
                    (markerWidth / 2);
                final left = rawLeft.clamp(edgePadding,
                    constraints.maxWidth - markerWidth - edgePadding);
                final top = (marker.top * constraints.maxHeight)
                    .clamp(24.0, constraints.maxHeight - 72.0);
                return Positioned(
                  left: left,
                  top: top,
                  width: markerWidth,
                  child: KeyedSubtree(
                    key: Key('ar-marker-${marker.warning.type.name}'),
                    child: ArMarkerWidget(warning: marker.warning),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}
