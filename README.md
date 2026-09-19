# Room Rally AR

Room Rally turns a real room into a playful augmented-reality race track. Pick
one of three caravans, scan the room and steer by tilting the phone like a
wheel. Detected furniture becomes a virtual obstacle; impacts slow the caravan
and increase its visible damage value.

## MVP architecture

- `features/ar_racing/domain` contains UI-independent caravan and race state,
  including normalized forward progress and perspective scaling.
- `features/ar_racing/application` abstracts phone motion input behind
  `MotionSteeringService`; widget tests use the mock implementation.
- `features/ar_racing/presentation` contains the garage, model selection and AR
  race composition. A rear three-quarter vehicle view shrinks and travels toward
  the room's vanishing point as it accelerates. The race now uses ARKit world
  tracking on supported iOS hardware and a live rear-camera view on other
  devices, with a high-contrast fallback when no camera is available.
- Authentication remains optional and wraps the game through `AuthGate`.

The race uses real accelerometer tilt input on iOS and Android and integrates it
into the caravan's lateral track position. Large hold-to-drive brake and gas
pedals control speed independently. On supported iOS devices ARKit enables
classified scene reconstruction and displays the detected room mesh; devices
without scene-reconstruction support still use plane detection and the live
camera fallback. Physics-based mesh collisions and persistent vehicle
deformation remain represented by deterministic collision controls.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use a physical iOS or Android device for motion sensors. Detailed classified
room meshes require a scene-reconstruction-capable iOS device (typically LiDAR).
