# Room Rally AR

Room Rally turns a real room into a playful augmented-reality race track. Pick
one of three caravans, scan the room and steer by tilting the phone like a
wheel. Detected furniture becomes a virtual obstacle; impacts slow the caravan
and increase its visible damage value.

## MVP architecture

- `features/ar_racing/domain` contains UI-independent caravan and race state.
- `features/ar_racing/application` abstracts phone motion input behind
  `MotionSteeringService`; widget tests use the mock implementation.
- `features/ar_racing/presentation` contains the garage, model selection and AR
  race composition. The current room mesh is a high-contrast mock visualization.
- Authentication remains optional and wraps the game through `AuthGate`.

The MVP uses real gyroscope input on iOS and Android. LiDAR room meshing,
physics-based mesh collisions and persistent vehicle deformation are currently
represented by deterministic mock visuals and collision controls. A production
adapter can implement the platform AR mesh API without leaking native details
into presentation code.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use a physical iOS or Android device for motion sensors. LiDAR support requires
a compatible device and a future native room-mesh adapter.
