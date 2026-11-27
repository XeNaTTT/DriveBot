# Room Rallye miniature district

The Flutter garage embeds a non-AR RealityKit showroom and forwards the selected profile to the race. The race keeps its existing world-coordinate Jolt chassis and independent wheel transforms. The district derives miniature dimensions from a 6.5 m vehicle displayed at 50 mm (1:130). Ocean District, Downtown and Palm Heights appear incrementally on stable, scanned floor. Further exploration can add shopping, entertainment and motor districts. World-space cell coordinates seed each neighborhood's orientation and lot positions. Rectangular bounds from each building supply a static Jolt collision mesh and walking clearance. Reset removes the district and its collider. Buildings keep their original world-space anchors. Walking, entry, pickup and return transitions run on the native game view. Collected equipment belongs to the current placement and resets with the vehicle.

## Asset manifest

| Resources under ios/Runner/RallyAssets | Origin and import |
| --- | --- |
| compact, sport, offroad USDZ | Project-authored lofted coachwork, enamel and UV liveries. One model-space unit spans the vehicle, including its separate runtime bumpers. Keep four independent wheel pivots. |
| RallyPilot.usdz | Adapted CesiumMan skinned mesh and walk cycle, copyright 2017 Cesium, CC BY 4.0. New suit texture and materials replace the original logo. Attribution ships in CREDITS.txt. [Source model](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CesiumMan) · [License](https://creativecommons.org/licenses/by/4.0/) |
| Shop0–Shop3 USDZ | Project-authored garage, tech shop, equipment store and hangar. Model metres, Y up, entrances face +Z. Roof and EntryDoor are independently addressable. |
| Item0–Item3 USDZ | Project-authored pressure vessel, energy blade, pulse emitter and wing module. Model metres, Y up. |
| boost, pickup, pulse WAV | Original short synthesized mono cues at 22.05 kHz. |

Export USDZ with embedded textures, metres and Y up in Blender 4.5. Export armatures and animation for the pilot. Add replacements under the existing Xcode folder reference. Verify names, bounds, body orientation and skin animation on import. Building and item visual meshes do not enter Jolt as triangle colliders.

## Changed code and verification

- AppDelegate.swift, ArRacingViewFactory.swift and ar_racing_screen.dart register, display and rotate the showroom and handle selection.
- RallyVehicleVisual.swift and RallyWalker.swift load the bundled meshes and attach animation and equipment.
- RallyDistrict.swift owns scale, footprint checks, anchors and automatic doorway visits. RallyInventory.swift owns item identity, equipment, installation, fuel and deployment state.
- ArRacingView.swift connects mode-dependent controls, carried items, sounds, cosmetics, contact snapshots and stationary surface marks.
- DriveBotJolt.h and DriveBotJolt.mm apply optional engine and airborne changes on the physics queue. Runner.xcodeproj/project.pbxproj bundles the resources and builds both new Swift modules.
- RunnerTests.swift covers asset loading, placement clearance, scale, transport, gear switching, boost and landing. ar_racing_ios_compatibility_test.rb tracks the central scale expression. The original pedal and geodesy cases remain in the full suite.
- codemagic-testflight.md records baseline and split-workflow timings.

On a physical iPhone verify portrait and landscape gestures, visibility and grounding of every miniature, all four automatic doorway visits, hand alignment during the walk cycle, reflections, sound, scene reconstruction on furniture, relocalization, boost distance, jump and landing, and sustained frame timing. Compare driving without upgrades with the installed reference. Simulator measurements cannot establish physical-device performance or art direction.

The showroom gesture test in test/features/ar_racing/ar_racing_screen_test.dart verifies slow drags in both directions. Offline OpenUSD validation loaded all 12 packages, checked metres and Y-up axes, confirmed embedded PNG liveries on all three coachwork meshes and the pilot, and found 48 skeletal rotation samples. The Windows Flutter suite and Ruby contracts run separately from macOS XCTest and on-device checks.

A level-floor probe using pinned Jolt measured the compact, family and expedition profiles over a 15-second steady interval. Mean unassisted speeds were 1.038, 1.048 and 1.029 m/s. With an unlimited test supply of NOS these reached 1.565, 1.572 and 1.549 m/s, respectively. The final drive changes only during boost. Positive drive torque tapers near the calibrated speed ceiling. Gameplay uses the normal 10-metre fuel supply.

## Pilot and automatic building visits

The compiled resource remains ios/Runner/RallyAssets/RallyPilot.usdz. The previous package contained 4,672 triangles. The new skinned mesh contains 7,336 (+57.0%), measured from the exported USD face indices. It retains the original rig and 48 rotation samples. New facial contours, ears, eyes, brown ponytail, shaped waist, T-shirt hem, sneaker soles and laces give the pilot a distinct silhouette. The turquoise fabric uses an embedded texture. The jeans, ivory shoes, hair and skin use separate materials. The existing 1.80 m scale reference, AR lighting and walking collision hull remain in use. RightHandGrip tracks the original right wrist and carries the selected item.

Each shop has named Entry and Exit points. In front of the door, within 3.4 full-size metres at 1:130, the walking HUD offers **Betreten**. The pilot approaches, crosses the threshold and disappears. The wait starts on the actual entry frame. After two seconds the pilot walks back out, receives the item once and returns to manual control. The overhead item disappears and the entrance marker turns green. Tracking interruption restores the last safe pre-visit position, visibility and walking mode without granting an item. Reset clears the visit and inventory. The four rewards are NOS, laser sword, virtual rifle and aircraft wings.

Local verification included re-import and rendering of the shipped USDZ with Blender, OpenUSD geometry and animation inspection, and Ruby integration checks. Native XCTest adds entrance direction, radius, floor tolerance, waiting, exit position and duplicate reward coverage. The existing RealityKit loading test includes the pilot asset. On an iPhone verify actual skinning and hand alignment, entrance reachability in a furnished room, control recovery after tracking loss, and automatic NOS and wing installation after returning to the camper.
## Living district

Each lot contributes two parking bays. Ocean District starts with two NPC cars, Downtown adds four and Palm Heights adds two. Eight cars start in separate bays with staggered departure times. RallyTraffic selects an unclaimed destination, plans intermediate points on a bounded grid and checks the upcoming segment against recognized floor, vertical planes, reconstructed geometry, buildings and nearby actors. The display link advances traffic off screen while tracking is ready. Distant cars probe the logical floor map less often. A single outstanding actor batch updates Jolt on its serial queue.

The Marina Cabrio, Bay Pickup and Ocean Sedan use reusable procedural bodies, independent wheels and visible seated drivers. Each profile supplies its own chassis size, mass, torque, brake response, steering, speed limit and impact resistance. The district combines the original functional storefronts with new frontage, venue signs, palms, parking stripes, pumps and lighting.

On foot, approach the left door of a stationary car and tap **Fahrzeug übernehmen**. The target reserves its controls during the 2.4-second exchange. After floor contact is confirmed the active chassis, inputs, wheel transforms and indicator switch together. The previous car stays parked. Damage, remaining NOS and installed wings belong to the individual car. The pilot keeps collected equipment. Displaced drivers remain visible after stepping away. Reset removes the fleet and its physics actors.

AR session callbacks use the main queue. Mesh capture validates CPU-accessible buffers and copies the packed bytes before background decoding. Mesh updates allow one pending decode per anchor and discard obsolete results after anchor removal.

### Session map, roads and streaming

RallyFloorMap records 8 cm cells after two consistent observations. Four floor samples, reconstructed-geometry clearance and vertical-plane checks gate each cell. A neighborhood can start once its first lot and its small road junction are confirmed. Later lots keep their seeded locations and wait for their own floor coverage. Centers must be more than 74 cm apart. These distances are in real AR metres at the existing 1:130 vehicle scale.

RallyNeighborhood chooses two lots in Ocean District and Palm Heights and three in Downtown. The room scan runs only with normal tracking. New lots and highway links are installed individually. District IDs derive from the cell coordinate. One background planning job at a time searches connected cells for a 9.1 cm corridor, rounds turns with quadratic Bézier segments and checks the sampled strip. The main thread revalidates the route against the latest map before adding the roadway and exposing the link to traffic. NPCs select reachable bays and follow road waypoints between districts.

The session retains lot definitions, reward state, traffic and the road graph. Scenery beyond 3 m is detached and rebuilt from the stored lot when the camera returns within 2.6 m. Functional anchors, collision geometry and actors persist. The implementation caps the map at 16,384 cells, neighborhoods at 12, active NPC traffic at eight cars and six regular walkers. Reset starts a new map. Non-LiDAR devices rely on recognized planes and have less information about furniture.

### TestFlight incident 47D0C969 and checkpoint racing

Build 20261126195526 trapped on thread 16 in DriveBotJolt while integrating velocity, through Body::AddPositionStep at Body.h:365. The earlier mesh read fault occurred in a different component. The older QuadTree trap also had a different immediate call site. The new log does not identify the body or the expression of the three assertions on that source line.

The bridge commanded kinematic actors to reach each target in one 1/60 s step. Publishing targets was limited to 30 Hz and the integrator could perform four fixed steps in one frame. Jolt retained the velocity after the first step. With four steps per sample the position error reverses sign and approximately triples before the next correction. A Windows A/B run with the pinned Jolt source, finite targets near 1 cm and four fixed steps produced infinity at sample 82 and NaN at sample 83 (zero-based). Resetting actor velocities after the target step gave zero measured target error over 4,800 steps. This reproduces the invalid position tested on the reported source line. Attribution of the specific device incident still requires device confirmation.

The same serialized physics queue handles player and four rival chassis, all constructed by CreateRallyVehicle with four suspension wheels. Native control inputs are checked for finiteness. The bridge reads mesh scalars with alignment-independent copies and rejects incomplete triangles and invalid indices. ARKit mesh decoding continues to consume owned snapshots, with up to eight pending jobs. Enabled Jolt assertions log their expression and source location.

RallyDistrict now samples around the placement target or vehicle, then around visible floor while the camera explores farther away. Building starts during aiming on verified floor. The previous quarter-metre clearance radius and simultaneous test of every future lot could suppress the first building indefinitely. Missing shop resources now use a procedural facade while preserving the entrance and reward. Pending local roads are retried on later scan updates. The optional scan display reports sampled areas, blocked cells, candidates, lots, attached buildings, loaded shop templates, outstanding road work and tracking. Its cell overlay is removed when hidden.

RallyRace plans one fixed event from a snapshot of known floor. A serial worker checks corridors independent of the road network. A staged event has four street models with seated drivers and a fifth illuminated starting position. Stopping there starts the traffic-light countdown. Real Jolt poses drive both collision response and checkpoint progress. The existing traffic pathfinder and live AR probes guide opponents. The visible ring follows the player and uses the native direction indicator. The two ring meshes are cached. The finish includes checkered geometry, results, replay and free driving. Course-keyed best times and last finishing positions use local preferences. Movement between samples is tested against the gate plane in either direction. Losing tracking resets the time baseline and pauses simulation.

The native implementation touches DriveBotJolt.h/.mm, ArRacingView.swift, RallyDistrict.swift, RallyWorld.swift, RallyTraffic.swift, RallyDirectionHUD.swift, RallyRace.swift, RallyGateMath.h, the Runner bridging header and Xcode target membership. Regression coverage is in RunnerTests.swift, drivebot_jolt_integration_test.rb and rally_indicator_math_test.c.

### Verification on Windows

- 229 Flutter tests passed. Flutter analysis reported 30 existing deprecation notices.
- 25 Ruby integration and compatibility checks passed with 236 assertions. The suite compiled and ran the production C gate intersection checks, including a high-speed crossing, reverse crossing, misses and invalid input.
- A standalone pinned-Jolt run using the vehicle construction logic exercised five vehicles for 108,000 fixed steps, equivalent to 30 simulated minutes. It completed 100 creations/removals. A separate placement and traffic run exercised 19,200 collider replacements.
- Seven Swift files passed syntax parsing. Twelve source USDZ archives passed integrity checks and the Xcode Resources phase includes the asset folder. An archived iOS bundle, Apple SDK type checking, native XCTest and on-device rendering still require macOS or an iPhone.
- The normal Codemagic workflow is unchanged. For extended native coverage set RALLY_STRESS=1 in the Xcode Test action and run RunnerTests/testFourOpponentChassisShareThePlayerWorldAndCanRestart. Production frame time and peak memory need measurement with Instruments.

### Physical-device acceptance

- Place the car on a small clear patch. Compare scanned area, candidate count and attached building count before and after walking to a second room. Verify the first visible house, model scale and real obstacle clearance.
- Start on bare floor, drive through the rings with NOS, interrupt tracking during countdown and racing, and test replay and free driving. Verify all four physical opponents, off-screen progress, traffic interactions, finish placement and stored best time.


- Scan an L-shaped room with furniture and an initially unscanned hallway. Confirm the road waits for the corridor, follows free floor into the next room and leaves narrow doorways clear. Revisit each district after a tracking interruption and check lot positions, rewards, traffic and memory.
- Compare the downtown tower heights, spacing, parking and boulevard width with Ocean District and Palm Heights. Exercise NOS on a highway and acquire an NPC after it crosses a district boundary.

- Scan a furnished room with and without scene reconstruction. Observe several departures, off-screen trips, parking and repeat departures. Block a lane with the player vehicle, then clear it. Check following distance, edge support and route recovery.
- Acquire each profile, return to the camper, then repeat. Check driver exit, immediate steering, four-wheel floor contact, active-car indicator, damage, NOS balance, wings and held items. Visit the four shops and use the existing equipment.
- Interrupt tracking during the approach, exchange, physics preparation and return to driving. Check that input recovers and the active car has one controller. Reset while a mesh or vehicle update is outstanding.
- Run for at least 30 minutes with moving traffic, repeated camera turns, changing mesh anchors and multiple vehicle exchanges. Capture frame times and memory with Instruments and check device crash logs for the reported mesh access fault.
