import 'dart:async';

import 'package:flutter/material.dart';

import '../application/motion_steering_service.dart';
import '../domain/caravan_model.dart';
import '../domain/race_session.dart';
import 'ar_race_background.dart';
import 'caravan_art.dart';
import 'racing_caravan_art.dart';

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
  RaceSession _session = const RaceSession();
  StreamSubscription<double>? _motionSubscription;
  Timer? _driveTimer;

  CaravanModel get _model => caravanModels[_selected];

  @override
  void dispose() {
    _motionSubscription?.cancel();
    _driveTimer?.cancel();
    super.dispose();
  }

  void _startRace() {
    setState(() {
      _racing = true;
      _session = const RaceSession(speedKmh: 34);
    });
    _motionSubscription = widget.motionService.steering.listen((value) {
      if (mounted) setState(() => _session = _session.steer(value));
    });
    _driveTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (mounted) setState(() => _session = _session.accelerate());
    });
  }

  void _finishRace() {
    _motionSubscription?.cancel();
    _driveTimer?.cancel();
    setState(() => _racing = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _racing
          ? _RaceView(
              model: _model,
              session: _session,
              onImpact: () =>
                  setState(() => _session = _session.collide(impact: .8)),
              onClose: _finishRace,
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
    return Container(
      key: const Key('ar-racing-garage'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF171A22), Color(0xFF07080C)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 12, 0),
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
                        'ROOM RALLY',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'AR CARAVAN RACING',
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
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'WÄHLE DEINEN',
                          style: TextStyle(
                            color: Color(0xFFA5A7B0),
                            fontSize: 13,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'WOHNWAGEN',
                          style: TextStyle(
                            fontSize: 31,
                            letterSpacing: .5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF20232B),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: model.accent.withValues(alpha: .5),
                            ),
                          ),
                          child: Column(
                            children: [
                              CaravanArt(model: model),
                              const SizedBox(height: 2),
                              Text(
                                model.name,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                model.subtitle,
                                style: TextStyle(
                                  color: model.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
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
                                    label: 'PANZERUNG',
                                    value: model.durability,
                                    color: model.accent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: List.generate(
                            caravanModels.length,
                            (index) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == 2 ? 0 : 8,
                                ),
                                child: _ModelChoice(
                                  model: caravanModels[index],
                                  selected: selected == index,
                                  onTap: () => onSelect(index),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 62,
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
                                    'RAUM SCANNEN & STARTEN',
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
                        const SizedBox(height: 12),
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
        child: FractionallySizedBox(
          widthFactor: value / 100,
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
  });
  final CaravanModel model;
  final bool selected;
  final VoidCallback onTap;
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
        height: 72,
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
    required this.model,
    required this.session,
    required this.onImpact,
    required this.onClose,
    this.backgroundBuilder,
  });
  final CaravanModel model;
  final RaceSession session;
  final VoidCallback onImpact;
  final VoidCallback onClose;
  final ArRaceBackgroundBuilder? backgroundBuilder;
  @override
  Widget build(BuildContext context) => Stack(
    key: const Key('ar-race-view'),
    fit: StackFit.expand,
    children: [
      backgroundBuilder?.call(context) ?? const ArRaceBackground(),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = session.perspectiveScale;
          final travel = session.runProgress * constraints.maxHeight * .42;
          return Stack(
            children: [
              AnimatedPositioned(
                key: const Key('fleeing-caravan'),
                duration: const Duration(milliseconds: 760),
                curve: Curves.easeInCubic,
                left:
                    (constraints.maxWidth - (190 * scale)) / 2 +
                    (session.steering * 38),
                bottom: 190 + travel,
                width: 190 * scale,
                height: 132 * scale,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0015)
                    ..rotateY(session.steering * -.22),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RacingCaravanArt(model: model),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  const SizedBox(width: 150, height: 42),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xE6111319),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${session.speedKmh.round()}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: .9,
                          ),
                        ),
                        const Text(
                          'KM/H',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'SCHADEN  ${session.damage}%',
                          style: TextStyle(
                            color: session.damage > 40
                                ? const Color(0xFFFF5A36)
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: 120,
                          height: 7,
                          child: LinearProgressIndicator(
                            value: session.damage / 100,
                            backgroundColor: Colors.white12,
                            color: const Color(0xFFFF5A36),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  key: const Key('simulate-impact'),
                  onPressed: onImpact,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('KOLLISION SIMULIEREN'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: model.accent.withValues(alpha: .55),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
