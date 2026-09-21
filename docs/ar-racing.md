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
- The centre reticle uses an `existingPlaneGeometry` raycast on every display
  update. A tap is accepted only while that exact hit is valid. Placement moves
  through `aiming -> placing -> building -> ready`; repeated taps cannot enter
  the transaction again.
- `DriveBotJolt` is an Objective-C++ boundary around Jolt Physics **v5.6.0**, at
  commit `e77f175595e64cb44218cc9d9d56fc365ad0e36a`. The pod installation verifies
  that commit. It uses Jolt's `VehicleConstraint`, four ray/cast wheel contacts,
  suspension springs/damping, steering, engine, differential and brakes.
- Jolt is the only dynamic authority. RealityKit entities have no dynamic
  physics body and only consume Jolt transforms. Simulation runs at 60 Hz with
  at most four catch-up steps and display updates follow `CADisplayLink`.

## Scale and configuration

All values use SI units and the ARKit coordinate system: one AR unit is one
metre. Each complete visual hierarchy is measured after assembly and receives
one uniform `0.05 / bounds.extents.z` scale, so every profile is exactly 0.050 m
long. Body and wheels share that root. Physics uses a 0.046 m long, 0.023 m wide
box collider, 0.0045 m wheel radius, 0.033 m wheelbase, 0.023 m track and a
0.011 m initial chassis-centre height. Profile masses are 0.075–0.095 kg;
engine torque is 0.008–0.009 N·m and suspension travel is 0.005–0.0065 m.
Sport, off-road and compact profiles vary these parameters only inside the
native physics boundary. The HUD reports actual metres per second from Jolt linear velocity;
it does not apply a full-size-car multiplier. Vehicle shape, wheel positions,
suspension, mass and drive values are centralized in `DBJoltWorld.prepareVehicle` so a
future USDZ presentation can be swapped without changing physics ownership.

## Root-cause record (five-centimetre repair)

- No vehicle USDZ exists in the repository. The previous fallback did contain
  an opaque body, but it was built at 0.25–0.30 m while every wheel was 0.05 m
  across. There was no bounds normalization. More importantly, Jolt wheel-world
  matrices were assigned individually to entities parented under that moving
  visual chassis. That mixed world and local spaces and separated the wheels.
  The replacement uses a distinct common visual root, always-visible fallback
  body, one bounds-derived scale, and explicit world-to-chassis-to-model-local
  conversion.
- The AR plane collider used the opposite triangle winding from the verified
  native test ground. Its collidable face pointed away from the car, so wheel
  casts could miss the floor. Together with full 30 cm mass, torque, suspension,
  radius and spawn-height constants, engine/brake input could not produce a
  valid small-car contact response. The winding and the complete coherent
  physical parameter set are now corrected; non-zero input also activates the
  body immediately and brake has explicit priority.
- Motion steering previously used absolute `gravity.x` in both landscape
  orientations, without a neutral reference. Depending on rotation this was
  the wrong screen axis and could settle near zero. Steering now uses calibrated
  signed gravity-Y in both landscape orientations, a three-degree deadzone,
  smoothing, and a speed-dependent limit.

An Object Capture USDZ still requires an explicit preparation record (model
orientation/scale, four wheel pivots/radii, simplified body collider, mass and
drive parameters). Object Capture cannot infer those vehicle semantics.

## Safety and lifecycle

Camera denial, unsupported tracking and AR errors are presented honestly.
Limited/interrupted tracking and app resignation release all inputs and pause
Jolt. Interruption recovery resets the AR origin, environment colliders and car
instead of mixing coordinate systems. Throttle/brake controls handle touch exit
and cancellation independently, so steering and throttle support multitouch.
Core Motion is the sole steering source in this native view. The first ready
sample (and the gear/debug action) captures neutral tilt. Landscape-left and
landscape-right use opposite gravity-Y signs, followed by a three-degree
deadzone and a low-latency smoothing filter. The scan overlay starts visible, is hidden for driving and remains independently
toggleable without adding colliders. Speed and pedals only exist in the ready
state; scan instructions only exist before it. Motion steering is the default,
and the legacy touch steering pad remains hidden.

## Placement diagnostics and crash status

The TestFlight exception `-[__NSArrayM insertObject:atIndex:]: object cannot be
nil` is on the result-packaging path, not in `PhysicsSystem::Update`. The
failing expression was `[[NSValue alloc] initWithBytes:&matrix
objCType:@encode(simd_float4x4)]`: Foundation does not provide a supported,
portable `NSValue` contract for the nested SIMD-vector encoding, and the nil
result was then inserted into the mutable wheel array. The bridge now transports
each rigid transform as an owned `DBJoltTransform` with seven scalar values
(position xyz and normalized quaternion xyzw) plus an explicit wheel index.
Swift reconstructs and validates the matrix from those values. No temporary
matrix pointer crosses the boundary, and missing/invalid wheels remain errors
rather than being skipped or replaced.

The replacement is transactional: it rejects non-finite transforms, attaches
the visual fallback on the main thread, and only then asks Jolt to create the
vehicle. It checks shape/body/lock creation, keeps the vehicle paused until the
initial transform is applied, and removes partial resources on every error.
RealityKit does not generate or inspect collision shapes during placement;
Jolt owns collision independently. Every Jolt mutation, mesh update, input and
step now runs on the single `de.drivebot.physics` queue, while completion blocks
return to the main thread before touching RealityKit or UIKit. A back-pressure
guard prevents display frames from queuing overlapping physics steps.

Every native state also carries the operation, fixed-step number, elapsed input,
expected/output wheel counts and finite-value result. On failure the loop pauses,
stale completions are rejected by placement generation, and the HUD exposes
**Fahrzeug zurücksetzen** plus **Diagnose kopieren**. The report is persisted in
`UserDefaults` and contains app/build/commit identity and no camera or mesh data.
Codemagic writes `CM_COMMIT` into the archived app's `DriveBotCommit` plist key.

Unified logging under subsystem `de.drivebot`, category `ARPlacement`, emits
the numbered checkpoints `[Placement] 01` through `[Placement] 10`. The last
checkpoint from a device run therefore separates raycast/configuration/model
work (01–06) from Jolt setup (07–09) and driving activation (10), without
logging pointers or mesh payloads. Debug builds can set
`DRIVEBOT_VISUAL_ONLY_PLACEMENT=1` to place the fallback without Jolt; Release
always uses `fullJolt`. Runner Release/Profile and the native Jolt pod generate
DWARF-with-dSYM output for symbolication. A symbolicated `.ips` report is still
required to identify the original exception class and failing frame
conclusively.

## Scan rendering

On LiDAR devices RealityKit's `showSceneUnderstanding` renderer displays the
session's real reconstructed mesh. Confirmed plane anchors get a subtle teal
surface and the valid centre raycast gets a teal marker. These entities have no
RealityKit physics components; collision remains exclusively in Jolt. Mesh
collider conversion is coalesced for 350 ms and sent as indexed 3D triangles to
the serialized Jolt world. This is the race track representation; no invented
remote upload API is involved. The scan is hidden after successful
placement and can be restored with **Scan anzeigen**. Without scene
reconstruction the UI explicitly reports limited plane-only mode; it never
invents a completion percentage.

## Bundled model limitation

The repository does **not** yet contain the Kenney Car Kit archive or three
converted USDZ assets. The official host rejected downloads from this build
environment, so fabricating filenames, relabelling glTF files, or claiming that
materials and hierarchies were inspected would be misleading. Three distinct
native appearances and physics profiles are selectable and work offline, but
the garage art is not a render of imported Kenney geometry. Importing and
device-checking the official CC0 models (wheel pivots, materials, axes and
scale) remains an explicit acceptance blocker.

## Device acceptance test

Use a physical LiDAR iPhone/iPad via TestFlight:

1. Slowly scan a textured floor and nearby wall/furniture until the placement
   prompt appears.
2. Tap the highlighted/confirmed real floor and confirm that the complete body
   and four attached wheels sit on it at exactly 5 cm overall length.
3. Hold gas while steering, then brake. Verify the speed is labelled `m/s`.
4. Drive into scanned furniture/wall and verify that motion is physically
   blocked and a subtle haptic occurs on the real velocity impulse.
5. Cover the camera or background/foreground the app. Inputs must release and
   the world/car must reset consistently after interruption.
6. Use reset and place the car again. If an error appears, copy/share the
   persisted diagnosis before resetting.
7. Run for at least ten minutes while checking frame pacing and device thermal
   state. A simulator cannot validate LiDAR reconstruction or these checks.

Codemagic's existing `ios-testflight` workflow installs the local Jolt pod,
builds a signed release IPA without changing bundle ID/signing, and uploads it
to TestFlight. After processing, assign the build to an internal tester group,
install it on the LiDAR device, grant camera access, rotate to landscape, open
AR Racing and follow the checklist above.

### Native build boundary

`DriveBotJolt` exposes only `Sources/DriveBotJolt.h` to Swift. The implementation
is Objective-C++ and includes `Jolt/Jolt.h` before every other Jolt header. Jolt's
own `.cpp` files are compiled as C++17 against libc++; its headers are deliberately
not registered as CocoaPods source headers. Instead, they are resolved through the
single non-recursive include root `Vendor/Jolt`, which supports includes such as
`<Jolt/Jolt.h>` without putting `Jolt/Math/Math.h` in CocoaPods' case-insensitive
header map (where it could shadow the Apple SDK's `<math.h>`).

The pod uses Jolt's default feature configuration. In particular, disabled Jolt
features must not be expressed as `JPH_*_ENABLED=0`: upstream tests those switches
with `#ifdef`, so defining them to zero still enables them. Codemagic first builds
the unsigned `DriveBotJolt` scheme for a generic ARM64 iOS device and only then
continues with the signed Flutter archive.
