import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/motion_steering_service.dart';
import 'caravan_palette.dart';
import 'caravan_art.dart';

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

class _GarageView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final model = caravanModels[selected];
    double dragDistance = 0;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Container(
      key: const Key('ar-racing-garage'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF153538), Color(0xFF091416)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(22, landscape ? 4 : 10, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: model.accent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.sports_motorsports_rounded,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROOM RALLYE',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'AR OPEN WORLD',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9DA1AD),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (accountEntryPoint != null) accountEntryPoint!,
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    landscape ? 4 : 22,
                    20,
                    landscape ? 4 : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - (landscape ? 8 : 42))
                          .clamp(0.0, double.infinity),
                    ),
                    child: Column(
                      children: [
                        if (!landscape)
                          const Text(
                            'WÄHLE DEINEN',
                            style: TextStyle(
                              color: Color(0xFFA5A7B0),
                              fontSize: 13,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (!landscape)
                          const Text(
                            'CAMPER',
                            style: TextStyle(
                              fontSize: 31,
                              letterSpacing: .5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        SizedBox(height: landscape ? 2 : 10),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            landscape ? 4 : 20,
                            16,
                            landscape ? 4 : 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.6, -0.8),
                              radius: 1.7,
                              colors: [
                                Color.alphaBlend(
                                  model.accent.withValues(alpha: .18),
                                  const Color(0xFF183438),
                                ),
                                const Color(0xFF101C20),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: model.accent.withValues(alpha: .5),
                            ),
                          ),
                          child: Flex(
                            direction: landscape
                                ? Axis.horizontal
                                : Axis.vertical,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: KeyedSubtree(
                                  key: ValueKey(model.id),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: (_) =>
                                        dragDistance = 0,
                                    onHorizontalDragUpdate: (details) =>
                                        dragDistance += details.delta.dx,
                                    onHorizontalDragEnd: (details) {
                                      final speed =
                                          details.primaryVelocity ?? 0;
                                      if (dragDistance.abs() >= 32 ||
                                          speed.abs() > 80) {
                                        onSelect(
                                          (selected +
                                                  ((dragDistance.abs() >= 32
                                                              ? dragDistance
                                                              : speed) <
                                                          0
                                                      ? 1
                                                      : -1)) %
                                              caravanModels.length,
                                        );
                                      }
                                    },
                                    child:
                                        !kIsWeb &&
                                            defaultTargetPlatform ==
                                                TargetPlatform.iOS
                                        ? SizedBox(
                                            width: landscape ? 160 : 250,
                                            height: landscape ? 90 : 138,
                                            child: IgnorePointer(
                                              child: UiKitView(
                                                viewType:
                                                    'drivebot/rally_showroom',
                                                creationParams: {
                                                  'vehicleID': model.id,
                                                },
                                                creationParamsCodec:
                                                    const StandardMessageCodec(),
                                              ),
                                            ),
                                          )
                                        : CaravanArt(
                                            model: model,
                                            compact: landscape,
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(width: landscape ? 12 : 0, height: 2),
                              Flexible(
                                flex: landscape ? 1 : 0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      model.name,
                                      textAlign: TextAlign.center,
                                      maxLines: landscape ? 1 : null,
                                      overflow: landscape
                                          ? TextOverflow.ellipsis
                                          : null,
                                      style: TextStyle(
                                        fontSize: landscape ? 18 : 25,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      model.subtitle,
                                      textAlign: TextAlign.center,
                                      maxLines: landscape ? 1 : null,
                                      overflow: landscape
                                          ? TextOverflow.ellipsis
                                          : null,
                                      style: TextStyle(
                                        color: model.accent,
                                        fontSize: landscape ? 12 : null,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: landscape ? 4 : 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _Stat(
                                          label: 'TEMPO',
                                          value: model.speed,
                                          color: model.accent,
                                        ),
                                        _Stat(
                                          label: 'HANDLING',
                                          value: model.handling,
                                          color: model.accent,
                                        ),
                                        _Stat(
                                          label: 'ROBUSTHEIT',
                                          value: model.durability,
                                          color: model.accent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: landscape ? 6 : 15),
                        Row(
                          children: List.generate(
                            caravanModels.length,
                            (index) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == caravanModels.length - 1
                                      ? 0
                                      : 8,
                                ),
                                child: _ModelChoice(
                                  model: caravanModels[index],
                                  selected: selected == index,
                                  onTap: () => onSelect(index),
                                  compact: landscape,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: landscape ? 6 : 18),
                        SizedBox(
                          width: double.infinity,
                          height: landscape ? 48 : 62,
                          child: FilledButton(
                            key: const Key('start-ar-race'),
                            onPressed: onStart,
                            style: FilledButton.styleFrom(
                              backgroundColor: model.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.view_in_ar_rounded),
                                  SizedBox(width: 10),
                                  Text(
                                    'MIT DIESEM AUTO STARTEN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!landscape) const SizedBox(height: 12),
                        if (!landscape)
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.screen_rotation_rounded,
                                size: 17,
                                color: Color(0xFF8D919B),
                              ),
                              SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'Smartphone neigen wie ein Lenkrad',
                                  style: TextStyle(
                                    color: Color(0xFF8D919B),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Container(
        width: 56,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value / 100),
          duration: const Duration(milliseconds: 320),
          builder: (context, fraction, child) =>
              FractionallySizedBox(widthFactor: fraction, child: child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9296A0),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _ModelChoice extends StatelessWidget {
  const _ModelChoice({
    required this.model,
    required this.selected,
    required this.onTap,
    required this.compact,
  });
  final CaravanModel model;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: model.name,
    child: InkWell(
      key: Key('caravan-${model.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: compact ? 48 : 72,
        decoration: BoxDecoration(
          color: selected
              ? model.accent.withValues(alpha: .14)
              : const Color(0xFF17191F),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? model.accent : Colors.white10,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.airport_shuttle_rounded,
              size: compact ? 18 : 24,
              color: selected ? model.accent : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              model.name.split(' ').first,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ],
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
