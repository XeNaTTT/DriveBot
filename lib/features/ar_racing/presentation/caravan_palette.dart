import 'dart:ui';

import '../domain/caravan_model.dart';
export '../domain/caravan_model.dart';

extension CaravanPalette on CaravanModel {
  Color get color => switch (id) {
    'sport' => const Color(0xFFE3DCCC),
    'offroad' => const Color(0xFF455440),
    _ => const Color(0xFF188F90),
  };

  Color get accent => switch (id) {
    'sport' => const Color(0xFFFF976B),
    'offroad' => const Color(0xFFD8E893),
    _ => const Color(0xFF63E6CD),
  };
}
