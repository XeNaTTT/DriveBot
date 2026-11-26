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
- Confirmed horizontal planes become finite solid Jolt boxes whose tops match
  the AR plane and whose footprint follows its center, extent and yaw. The
  placement hit's plane is installed on the physics queue before vehicle
  creation. The unloaded vehicle must report four upward wheel contacts
  before driving starts. A vehicle that falls below its placement height
  without contact pauses at the last accepted pose and offers an explicit reset. AR mesh anchors
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
  The timestamp advances when a physics step is submitted. The AR anchor
  remains fixed while a child entity receives the Jolt world pose.
  The miniature chassis uses linear-cast collision detection with a 0.5 mm
  penetration allowance.

## Scale and configuration

All values use SI units and the ARKit coordinate system: one AR unit is one
metre. Each complete visual hierarchy is measured after assembly and receives
one uniform `0.05 / bounds.extents.z` scale, so every profile is exactly 0.050 m
long. Body and wheels share that root. Physics uses a 0.046 m long, 0.023 m wide
box collider, 0.0045 m wheel radius, 0.033 m wheelbase, 0.023 m track and a
0.011 m initial chassis-centre height. Profile masses are 0.075–0.095 kg;
engine torque is 0.008–0.009 N·m and suspension travel is 0.005–0.0065 m.
Wheel inertia uses the 0.0045 m radius and an estimated wheel mass of 5 g.
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
Jolt. ARKit relocalizes into the existing world on recovery. Flutter hands
race-view pointers to UIKit on touch-down. Throttle/brake controls handle touch exit
and cancellation independently. The brake overrides forward throttle while held.
Once the brake brings the vehicle to 0.01 m/s or below, release it and press it
again to reverse. The button turns red and shows `R` while held. Releasing it
ends reverse input and restores the brake label.
The analog pad takes priority over Core Motion while touched. The first ready
sample (and the gear/debug action) captures neutral tilt. Landscape-left and
landscape-right use opposite gravity-Y signs, followed by a three-degree
deadzone and a low-latency smoothing filter. The scan overlay starts visible, is hidden for driving and remains independently
toggleable without adding colliders. Speed and pedals only exist in the ready
state; scan instructions only exist before it. Motion steering is the default,
and both steering inputs share the saved sensitivity and inversion.

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
the selected model on the main thread, and only then asks Jolt to create the
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
`DRIVEBOT_VISUAL_ONLY_PLACEMENT=1` to place the model without Jolt; Release
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

## Vehicle rendering and asset sources

The garage IDs still select the same physics profiles. In RealityKit,
`RallyVehicleVisual` assembles three reusable model hierarchies:

- Urban Camper (`compact`) uses the proportions of the
  [Campground camper van](https://1designtool.com/3d/models/campground-camper-van)
  as a visual reference.
- Family Cruiser (`sport`) uses the overcab silhouette of the
  [Class C RV](https://www.fab.com/listings/1e7683dc-0f7d-4cac-84d2-e9a1af88523f).
- Expedition Beast (`offroad`) uses the supplied overland reference for its
  roof rack, cargo, rock sliders and wider treaded tyres.

The models are built locally with RealityKit meshes and lit materials. Paint,
opaque glass, metal and rubber have separate surface finishes. ARView provides
grounding shadows on physical surfaces and ARKit environment texturing supplies
scene reflections. LiDAR occlusion and scanned furniture colliders use the
existing paths. Each wheel mesh has a Y-axis pivot matching the Jolt bridge;
its world matrix carries suspension position, wheel spin and steering. The
four wheels share mesh resources and each uses three material groups.

GLB is useful as a source format, but the native RealityKit loading path uses
USD/USDZ. Replacing an authored model with a licensed export requires the same
axes and wheel pivots and a check of the five-centimetre bounds. This build
ships no third-party vehicle files. Verify shadows, occlusion, wheel motion
and frame pacing on a physical iPhone using the device checklist below.

### Earlier asset experiment

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
with `#ifdef`, so defining them to zero still enables them. The device archive
builds Jolt through the Runner dependency graph. Full Gameplay Regression builds
the simulator variant with the test host and runs the complete RunnerTests suite.
## Room Rallye – driving and walking acceptance

Flutter stable builds the garage. It passes the selected profile through the
platform view creation parameters. ARKit supplies metric tracking and detected
geometry, RealityKit renders the live camera scene, and a serial Jolt world
steps the car at 60 Hz. The display link advances the walker using elapsed time.
No Flutter updates are needed per camera frame.

The native view owns driving, exiting, on-foot and entering states. The car
stays under its original world anchor during a mode switch. A brief tracking
interruption during asynchronous vehicle construction previously called reset
and removed that anchor. Construction now finishes while paused if tracking
is limited. The previous pedal repair also replaced the full-size wheel inertia
with miniature inertia; a negative throttle request selects reverse.

The gear button opens the steering settings. Both tilt and the left thumb pad
use the same bounded steering gain and inversion, persisted in UserDefaults.
The left pad controls camera-relative movement on foot. ARKit verifies floor
support and RealityKit checks reconstructed obstacles along the proposed step.
Without reconstruction, detected vertical planes provide a wall check.
Unscanned furniture and narrow geometry can still be missed.

The garage illustrations, three camper meshes and articulated figure are
project-generated. The figure uses a jacket, denim, separate limbs and
procedural steps, breathing and turns. Door transitions use a short movement
between the checked standing position and the cab. No third-party character,
motion capture, vehicle textures or USDZ licenses were added. For higher
fidelity, supply a licensed skinned character with idle, walk and door clips
and vehicle meshes with separate wheel pivots. Jolt's license is in
`LICENSES/JoltPhysics-LICENSE.txt`.

### Implementation and verification record

| Files | Responsibility |
| --- | --- |
| `ar_racing_screen.dart`, `caravan_art.dart`, `racing_caravan_art.dart`, `caravan_palette.dart`, `caravan_model.dart` | Garage, profile presentation and UI-independent camper data |
| `ArRacingView.swift` | Placement recovery, mode transitions, HUD, input routing and parking |
| `RallySteeringPanel.swift` | Persistent inversion and gain controls |
| `RallyWalker.swift`, `RallyWalkingSurface.swift` | Articulated avatar, camera-relative movement, door distance, ground and obstacle queries |
| `RallyVehicleVisual.swift`, `DriveBotJolt.mm` | Clear-coated bodywork, expedition lights and profile steering angles |
| `project.pbxproj`, `codemagic.yaml`, `pubspec.lock`, `docs/codemagic-testflight.md` | Native target membership and reproducible build toolchain |
| `RunnerTests.swift`, `ar_racing_ios_compatibility_test.rb`, `community_reporting_static_test.dart` | Control settings, walking geometry, native integration contracts and portable path exclusions in the repository scan |

Local verification used Flutter 3.50.1 and Dart 3.14.0 on Windows. All 228
Flutter tests passed. Analysis reported 30 informational notices and zero warnings
or errors. The two Ruby integration suites passed 20 tests with 188 assertions.
Swift syntax was parsed locally. The simulator XCTest suite, signing, TestFlight
distribution, actual camera tracking and frame-time measurements require separate
verification on the macOS build runner or a physical iPhone.

### Physical iPhone acceptance

For the November 2026 regression comparison the reference is `3475f7e`,
the last successful TestFlight workflow before the redesign. Its distribution
build succeeded before the workflow began executing RunnerTests. The installed
device build number was unavailable. The native Jolt source and all three
profiles have been restored to that revision. The redesign had moved the sport
profile from 0.009 to 0.0085 N·m and 30 to 28 degrees of steering, and compact
from 0.0085 to 0.009 N·m and 28 to 34 degrees. Off-road was unchanged.

A Windows C++ replay using the pinned Jolt source, the bridge's floor, chassis,
wheel and drivetrain settings, and the XCTest's 60 Hz inputs gave these compact
profile speeds in m/s:

| Measurement | Reference | Redesign |
| --- | ---: | ---: |
| At throttle release | 0.08413 | 0.08877 |
| After 0.2 s coasting | 0.08465 | 0.08925 |
| After 1 s coasting | 0.04987 | 0.05259 |

Both runs reproduce the early-coast assertion failure. The test now verifies
zero pedal inputs and forward displacement at 0.2 s, then slowing over a full
second before applying the brake. The replay covers the Jolt dynamics only.
The native test bypasses Flutter, UIKit, AR tracking and the display link.
Its logs and result bundle are retained by the Codemagic workflow.

1. Place each camper on a textured floor. Walk around it, briefly cover the
   camera during placement, restore tracking and check visibility and contact.
2. Accelerate, coast, brake to rest, release and press the brake again. Check
   the red R, signed movement, wheel rotation, steering and speed indication.
3. Try tilt and touch at gains 0.5, 1 and 2 in both landscape orientations.
   Invert steering, terminate the app and verify the saved values on relaunch.
4. Attempt exit while moving, then beside furniture, at a plane boundary and
   on clear ground. Verify the feet stay supported and the camper stays parked.
5. Hold diagonal input, drag off the pad and release. Walk away from the door
   and return. Check contextual entry, repeated mode switches, app suspension,
   immediate pedal response after entry, and recovery after tracking loss.
6. Repeat on phones with and without scene reconstruction. Use Instruments
   to record frame times during mesh refinement, walking and turning. Check
   contact shadows and occlusion over both dark carpet and reflective floors.

### Investigation of termination immediately after placement

TestFlight 1.1.1 (20261126191026), incident 640D5695-3F4E-4301-BB9D-CA00D0B94718, terminated with EXC_BREAKPOINT / SIGTRAP on thread 28. The symbolicated stack goes through SerializedJoltWorld.step, DBJoltWorld.step, PhysicsSystem::Update, QuadTree::UpdatePrepare and QuadTree::ValidateTree. The ARM register x3 holds 0x63d (1597), matching the assertion line argument in the pinned Jolt source. At that line Jolt checks that the cached child-node box contains the child's actual bounds or that the actual bounds are invalid. The report identifies the failing check; it does not identify the body update that first invalidated the bounds.

RallyPhysicsSystem.cpp builds the same pinned PhysicsSystem using Jolt's direct body-bounds broad phase. The pod excludes the original PhysicsSystem translation unit to compile it exactly once. This removes the failing tree maintenance path while retaining wheel casts, contacts, constraints and debug assertions. Direct queries scan the registered bodies. The race streams up to 48 reconstructed mesh anchors within three metres of the current car, prioritizes nearby anchors and decodes at most eight snapshots at once. An independent Windows test with the same PhysicsSystem translation unit completed 1,200 simulation steps and 19,200 collider replacements, then exercised acceleration, braking and reverse. Recheck CPU time and wheel contact on device under sustained AR mesh updates. [Pinned Jolt tree validation](https://github.com/jrouwe/JoltPhysics/blob/e77f175595e64cb44218cc9d9d56fc365ad0e36a/Jolt/Physics/Collision/BroadPhase/QuadTree.cpp#L1591-L1597)

The placement path also keeps an incomplete-stage marker until the first successful driving step. After an interrupted attempt **Diagnose kopieren** includes that marker and build information. An incomplete marker may also result from closing the app. The earlier packed AR mesh reader fix remains in place.
