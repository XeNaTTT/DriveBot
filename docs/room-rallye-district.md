# Room Rallye miniature district

The Flutter garage embeds a non-AR RealityKit showroom and forwards the selected profile to the race. The race keeps its existing world-coordinate Jolt chassis and independent wheel transforms. The district derives miniature dimensions from a 6.5 m vehicle displayed at 50 mm (1:130). Floor updates sample a random position for a five-block district spanning 48 × 32 cm. Placement requires supported tile corners, reconstructed-geometry clearance and space around the player and vehicle. Shared streets surround ten buildings, including the four reward shops and residences with one to five floors. Eight NPC cars travel between parking bays and six animated pedestrians follow the pavement. Rectangular bounds from each building supply a static Jolt collision mesh and walking clearance. Reset removes the district and its collider. Buildings keep their original world-space anchors. Walking, entry, pickup and return transitions run on the native game view. Collected equipment belongs to the current placement and resets with the vehicle.

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

The five blocks share ten parking bays. Eight cars start in separate bays with staggered departure times. RallyTraffic selects an unclaimed destination, plans intermediate points on a bounded grid and checks the upcoming segment against recognized floor, vertical planes, reconstructed geometry, buildings and nearby actors. The display link advances traffic off screen while tracking is ready. Distant cars probe less often. A single outstanding actor batch updates Jolt on its serial queue.

The Marina Cabrio, Bay Pickup and Ocean Sedan use reusable procedural bodies, independent wheels and visible seated drivers. Each profile supplies its own chassis size, mass, torque, brake response, steering, speed limit and impact resistance. The district combines the original functional storefronts with new frontage, venue signs, palms, parking stripes, pumps and lighting.

On foot, approach the left door of a stationary car and tap **Fahrzeug übernehmen**. The target reserves its controls during the 2.4-second exchange. After floor contact is confirmed the active chassis, inputs, wheel transforms and indicator switch together. The previous car stays parked. Damage, remaining NOS and installed wings belong to the individual car. The pilot keeps collected equipment. Displaced drivers remain visible after stepping away. Reset removes the fleet and its physics actors.

AR session callbacks use the main queue. Mesh capture validates CPU-accessible buffers and copies the packed bytes before background decoding. Mesh updates allow one pending decode per anchor and discard obsolete results after anchor removal.

### Physical-device acceptance

- Scan a furnished room with and without scene reconstruction. Observe several departures, off-screen trips, parking and repeat departures. Block a lane with the player vehicle, then clear it. Check following distance, edge support and route recovery.
- Acquire each profile, return to the camper, then repeat. Check driver exit, immediate steering, four-wheel floor contact, active-car indicator, damage, NOS balance, wings and held items. Visit the four shops and use the existing equipment.
- Interrupt tracking during the approach, exchange, physics preparation and return to driving. Check that input recovers and the active car has one controller. Reset while a mesh or vehicle update is outstanding.
- Run for at least 30 minutes with moving traffic, repeated camera turns, changing mesh anchors and multiple vehicle exchanges. Capture frame times and memory with Instruments and check device crash logs for the reported mesh access fault.
