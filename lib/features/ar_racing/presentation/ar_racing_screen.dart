import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/motion_steering_service.dart';
import '../domain/caravan_model.dart';
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
