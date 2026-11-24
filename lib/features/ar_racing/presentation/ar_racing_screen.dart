import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/motion_steering_service.dart';
import 'caravan_palette.dart';

typedef ArRaceBackgroundBuilder = Widget Function(BuildContext context);

class ArRacingScreen extends StatefulWidget {
  const ArRacingScreen({
    this.motionService = const MockMotionSteeringService(),
    this.accountEntryPoint,
    this.backgroundBuilder,
    super.key,
  });

  final MotionSteeringService motionService;
  final Widget? accountEntryPoint;
  final ArRaceBackgroundBuilder? backgroundBuilder;

  @override
  State<ArRacingScreen> createState() => _ArRacingScreenState();
}

class _ArRacingScreenState extends State<ArRacingScreen> {
  int _selected = 0;
  bool _racing = false;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startRace() => setState(() => _racing = true);
  void _finishRace() => setState(() => _racing = false);

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _racing
          ? _RaceView(
              onClose: _finishRace,
              vehicleID: caravanModels[_selected].id,
              backgroundBuilder: widget.backgroundBuilder,
            )
          : _GarageView(
              selected: _selected,
              onSelect: (value) => setState(() => _selected = value),
              onStart: _startRace,
              accountEntryPoint: widget.accountEntryPoint,
            ),
    ),
  );
}

class _GarageView extends StatefulWidget {
  const _GarageView({
    required this.selected,
    required this.onSelect,
    required this.onStart,
    this.accountEntryPoint,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final Widget? accountEntryPoint;
  @override
  State<_GarageView> createState() => _GarageViewState();
}

class _GarageViewState extends State<_GarageView> {
  static const pink = Color(0xffff4ca6);
  static const cardCrops = {
    'compact': Rect.fromLTRB(72, 292, 154, 333),
    'sport': Rect.fromLTRB(184, 291, 265, 332),
    'offroad': Rect.fromLTRB(296, 291, 380, 332),
  };
  double drag = 0;

  void step(int direction) =>
      widget.onSelect((widget.selected + direction) % caravanModels.length);

  @override
  Widget build(BuildContext context) {
    final model = caravanModels[widget.selected];
    return Stack(
      key: const Key('ar-racing-garage'),
      fit: StackFit.expand,
      children: [
        const _SunsetBackdrop(key: Key('static-showroom-art')),
        GestureDetector(
          key: ValueKey(model.id),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => drag = 0,
          onHorizontalDragUpdate: (event) => drag += event.delta.dx,
          onHorizontalDragEnd: (event) {
            final delta = drag.abs() >= 32
                ? drag
                : (event.primaryVelocity ?? 0);
            if (delta.abs() >= 32) step(delta < 0 ? 1 : -1);
          },
        ),
        SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              final cards = Row(
                children: [
                  for (final id in ['compact', 'sport', 'offroad'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _angledChoice(
                          id,
                          model.id,
                          (box.maxHeight * .16).clamp(44.0, 72.0),
                        ),
                      ),
                    ),
                ],
              );
              final start = FilledButton.icon(
                key: const Key('start-ar-race'),
                onPressed: widget.onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: pink,
                  foregroundColor: const Color(0xff251021),
                  shape: const BeveledRectangleBorder(),
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.play_circle_fill),
                label: const FittedBox(
                  child: Text(
                    'MIT DIESEM AUTO STARTEN',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
              return Stack(
                children: [
                  if (widget.accountEntryPoint != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: widget.accountEntryPoint!,
                    ),
                  for (final dir in [-1, 1])
                    Align(
                      alignment: Alignment(dir.toDouble(), -.17),
                      child: IconButton.filledTonal(
                        tooltip: dir < 0
                            ? 'Vorheriges Fahrzeug'
                            : 'Nächstes Fahrzeug',
                        onPressed: () => step(dir),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x66321a30),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          dir < 0 ? Icons.chevron_left : Icons.chevron_right,
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        model.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 25,
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      model.subtitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _meter('TEMPO', model.speed),
                                    _meter('HANDLING', model.handling),
                                    _meter('ROBUSTHEIT', model.durability),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (wide)
                            Row(
                              children: [
                                Expanded(flex: 3, child: cards),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: start),
                              ],
                            )
                          else ...[
                            cards,
                            const SizedBox(height: 6),
                            start,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _meter(String label, int value) => Row(
    children: [
      SizedBox(
        width: 52,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      Expanded(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 250),
          tween: Tween(end: value / 100),
          builder: (context, fraction, _) => LinearProgressIndicator(
            value: fraction,
            color: pink,
            backgroundColor: Colors.white12,
            minHeight: 4,
          ),
        ),
      ),
      SizedBox(
        width: 22,
        child: Text(
          '$value',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
    ],
  );

  Widget _angledChoice(String id, String current, double height) {
    final index = caravanModels.indexWhere((car) => car.id == id);
    final car = caravanModels[index];
    return Semantics(
      button: true,
      selected: id == current,
      label: car.name,
      child: GestureDetector(
        key: Key('caravan-$id'),
        onTap: () => widget.onSelect(index),
        child: Transform(
          transform: Matrix4.skewX(-.13),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xff211827),
              border: Border.all(
                color: id == current ? pink : Colors.white38,
                width: id == current ? 2 : 1,
              ),
              boxShadow: id == current
                  ? [const BoxShadow(color: Color(0x80ff288b), blurRadius: 8)]
                  : [],
            ),
            child: Column(
              children: [
                Expanded(child: _ArtCrop(cardCrops[id]!)),
                Text(
                  car.name
                      .toLowerCase()
                      .split(' ')
                      .map((w) => w[0].toUpperCase() + w.substring(1))
                      .join(' '),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: id == current ? pink : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Source rectangles use the reference artwork's 700-unit design grid.
class _SunsetBackdrop extends StatelessWidget {
  const _SunsetBackdrop({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // The JPEG also contains a mock HUD. Sample only the illustrated landscape.
      const scene = Rect.fromLTRB(24, 0, 676, 238);
      final artHeight = box.maxWidth * scene.height / scene.width;
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff2e1929)),
          Positioned(
            top: artHeight,
            left: 0,
            right: 0,
            height: artHeight,
            child: Transform.flip(flipY: true, child: const _ArtCrop(scene)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: artHeight,
            child: const _ArtCrop(scene),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0x98221223),
                  Color(0xee201421),
                ],
                stops: [0, .49, .74, 1],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ArtCrop extends StatelessWidget {
  const _ArtCrop(this.region, {this.alignment = Alignment.center});
  final Rect region;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      alignment: alignment,
      child: SizedBox(
        width: region.width,
        height: region.height,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -region.left,
                top: -region.top,
                width: 700,
                height: 367.5,
                child: Image.asset(
                  'assets/showroom/sunset.jpg',
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RaceView extends StatelessWidget {
  const _RaceView({
    required this.onClose,
    required this.vehicleID,
    this.backgroundBuilder,
  });

  final VoidCallback onClose;
  final String vehicleID;
  final ArRaceBackgroundBuilder? backgroundBuilder;

  @override
  Widget build(BuildContext context) => Stack(
    key: const Key('ar-race-view'),
    fit: StackFit.expand,
    children: [
      if (backgroundBuilder != null)
        backgroundBuilder!(context)
      else
        UiKitView(
          key: const Key('native-ar-racing-view'),
          viewType: 'drivebot/ar_racing_view',
          creationParams: <String, Object>{'vehicleID': vehicleID},
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
          },
        ),
      SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filledTonal(
              key: const Key('close-ar-race'),
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Rennen schließen',
            ),
          ),
        ),
      ),
    ],
  );
}
