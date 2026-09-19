# Native AR racing architecture

The race screen is a native iOS island embedded in Flutter as
`drivebot/ar_racing_view`. Flutter owns navigation only. AR tracking, input,
rendering and every fixed physics step remain on iOS; no per-frame transforms
cross a Flutter channel.

## Runtime pipeline

- `ArRacingView` runs `ARWorldTrackingConfiguration` with horizontal plane
  detection. On supported LiDAR hardware it additionally enables classified
  scene reconstruction and RealityKit occlusion. Other devices explicitly show
  that only floor collision is available.
- Confirmed horizontal planes become stable, thin Jolt meshes. AR mesh anchors
  are converted from anchor-local coordinates to AR world coordinates. Changes
  are coalesced for 350 ms, keyed by anchor UUID, and removals delete both the
  pending update and the Jolt body.
- A tap uses an existing-plane-geometry AR raycast. It places a simple,
  license-free 30 cm RC car composed of a body and four wheel entities.
- `DriveBotJolt` is an Objective-C++ boundary around Jolt Physics **v5.6.0**, at
  commit `e77f175595e64cb44218cc9d9d56fc365ad0e36a`. The pod installation verifies
  that commit. It uses Jolt's `VehicleConstraint`, four ray/cast wheel contacts,
  suspension springs/damping, steering, engine, differential and brakes.
- Jolt is the only dynamic authority. RealityKit entities have no dynamic
  physics body and only consume Jolt transforms. Simulation runs at 60 Hz with
  at most four catch-up steps and display updates follow `CADisplayLink`.

## Scale and configuration

All values use SI units and the ARKit coordinate system: one AR unit is one
metre. The test car is 0.30 m long, 0.15 m wide, has 0.025 m radius wheels and
1.8 kg mass. Its HUD reports actual metres per second from Jolt linear velocity;
it does not apply a full-size-car multiplier. Vehicle shape, wheel positions,
suspension, mass and drive values are centralized in `DBJoltWorld.reset` so a
future USDZ presentation can be swapped without changing physics ownership.

An Object Capture USDZ still requires an explicit preparation record (model
orientation/scale, four wheel pivots/radii, simplified body collider, mass and
drive parameters). Object Capture cannot infer those vehicle semantics.

## Safety and lifecycle

Camera denial, unsupported tracking and AR errors are presented honestly.
Limited/interrupted tracking and app resignation release all inputs and pause
Jolt. Interruption recovery resets the AR origin, environment colliders and car
instead of mixing coordinate systems. Throttle/brake controls handle touch exit
and cancellation independently, so steering and throttle support multitouch.
The debug control is off by default; no room wireframe is permanently shown.

## Device acceptance test

Use a physical LiDAR iPhone/iPad via TestFlight:

1. Slowly scan a textured floor and nearby wall/furniture until the placement
   prompt appears.
2. Tap the highlighted/confirmed real floor and confirm that all wheels sit on
   it at the expected 30 cm scale.
3. Hold gas while steering, then brake. Verify the speed is labelled `m/s`.
4. Drive into scanned furniture/wall and verify that motion is physically
   blocked and a subtle haptic occurs on the real velocity impulse.
5. Cover the camera or background/foreground the app. Inputs must release and
   the world/car must reset consistently after interruption.
6. Use reset and place the car again.
7. Run for at least ten minutes while checking frame pacing and device thermal
   state. A simulator cannot validate LiDAR reconstruction or these checks.

Codemagic's existing `ios-testflight` workflow installs the local Jolt pod,
builds a signed release IPA without changing bundle ID/signing, and uploads it
to TestFlight. After processing, assign the build to an internal tester group,
install it on the LiDAR device, grant camera access, rotate to landscape, open
AR Racing and follow the checklist above.
