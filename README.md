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

The MVP uses real gyroscope input on iOS and Android. ARKit supplies camera
tracking on supported iOS devices; Android currently uses the live camera rather
than world anchors. LiDAR room meshing, physics-based mesh collisions and
persistent vehicle deformation remain represented by deterministic collision
controls. A production mesh adapter can implement those capabilities without
leaking native details into presentation code.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use a physical iOS or Android device for motion sensors. LiDAR support requires
a compatible device and a future native room-mesh adapter.
