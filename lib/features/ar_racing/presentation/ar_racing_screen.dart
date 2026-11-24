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
  void _startRace() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _racing = true);
  }

  void _finishRace() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _racing = false);
  }

  @override
  void dispose() {
    if (_racing) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
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
  static const heroCrops = {
    'sport': Rect.fromLTRB(56, 0, 643, 239),
    'compact': Rect.fromLTRB(58, 74, 223, 236),
    'offroad': Rect.fromLTRB(502, 56, 642, 237),
  };
  static const cardCrops = {
    'compact': Rect.fromLTRB(72, 292, 154, 333),
    'sport': Rect.fromLTRB(184, 291, 265, 332),
    'offroad': Rect.fromLTRB(296, 291, 380, 332),
  };
  double drag = 0;
  bool preview = false;

  void step(int direction) =>
      widget.onSelect((widget.selected + direction) % caravanModels.length);

  @override
  Widget build(BuildContext context) {
    final model = caravanModels[widget.selected];
    final native = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return ColoredBox(
      key: const Key('ar-racing-garage'),
      color: const Color(0xff1d1424),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth > bounds.maxHeight;
            final heroHeight = wide
                ? (bounds.maxHeight - 126).clamp(64.0, bounds.maxHeight * .65)
                : bounds.maxHeight * .51;
            final controls = Row(
              children: [
                for (final id in ['compact', 'sport', 'offroad'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _angledChoice(id, model.id, wide ? 47 : 66),
                    ),
                  ),
              ],
            );
            final start = FilledButton.icon(
              key: const Key('start-ar-race'),
              style: FilledButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: const Color(0xff251021),
                shape: const BeveledRectangleBorder(),
                minimumSize: const Size(0, 44),
              ),
              onPressed: widget.onStart,
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
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: heroHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          key: ValueKey(model.id),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) => drag = 0,
                          onHorizontalDragUpdate: (e) => drag += e.delta.dx,
                          onHorizontalDragEnd: (e) {
                            final offset = drag.abs() >= 32
                                ? drag
                                : (e.primaryVelocity ?? 0);
                            if (offset.abs() >= 32) step(offset < 0 ? 1 : -1);
                          },
                          child: preview && native
                              ? IgnorePointer(
                                  child: UiKitView(
                                    key: ValueKey('preview-${model.id}'),
                                    viewType: 'drivebot/rally_showroom',
                                    creationParams: {'vehicleID': model.id},
                                    creationParamsCodec:
                                        const StandardMessageCodec(),
                                  ),
                                )
                              : _ArtCrop(
                                  heroCrops[model.id]!,
                                  alignment: model.id == 'sport' && !wide
                                      ? const Alignment(-.16, 0)
                                      : Alignment.center,
                                ),
                        ),
                        if (model.id != 'sport' || preview || !wide)
                          const Positioned(
                            top: 10,
                            left: 14,
                            child: Text(
                              'ROOM\nRALLYE',
                              style: TextStyle(
                                height: .86,
                                fontSize: 23,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(blurRadius: 8)],
                              ),
                            ),
                          ),
                        for (final direction in [-1, 1])
                          Align(
                            alignment: Alignment(direction.toDouble(), .42),
                            child: IconButton.filledTonal(
                              tooltip: direction < 0
                                  ? 'Vorheriges Fahrzeug'
                                  : 'Nächstes Fahrzeug',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x99321a30),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => step(direction),
                              icon: Icon(
                                direction < 0
                                    ? Icons.chevron_left
                                    : Icons.chevron_right,
                              ),
                            ),
                          ),
                        Positioned(
                          right: 8,
                          top: 4,
                          child: Row(
                            children: [
                              if (native)
                                IconButton.filledTonal(
                                  onPressed: () =>
                                      setState(() => preview = !preview),
                                  tooltip: '3D-Ansicht wechseln',
                                  icon: const Icon(Icons.view_in_ar),
                                ),
                              if (widget.accountEntryPoint != null)
                                widget.accountEntryPoint!,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 20 : 16,
                      vertical: wide ? 4 : 12,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff401f36), Color(0xff201722)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  model.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: wide ? 22 : 25,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              Text(
                                model.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xffe7cdd9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: wide ? 158 : 126,
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
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 15 : 12,
                      vertical: wide ? 4 : 12,
                    ),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: controls),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: start),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              controls,
                              const SizedBox(height: 12),
                              start,
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _meter(String label, int value) => Row(
    children: [
      SizedBox(
        width: 52,
        child: Text(
          label,
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
