# Room Rallye miniature district

The Flutter garage embeds a non-AR RealityKit showroom and forwards the selected profile to the race. The race keeps its existing world-coordinate Jolt chassis and independent wheel transforms. The district derives miniature dimensions from a 6.5 m vehicle displayed at 50 mm (1:130). A floor update can place one storefront after corner support, reconstructed geometry, vehicle and avatar clearance checks. Buildings keep their original world-space anchors. Walking, entry, pickup and return transitions run on the native game view. Collected equipment belongs to the current placement and resets with the vehicle.

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
- RallyDistrict.swift owns scale, footprint checks, anchors and cutaway transitions. RallyInventory.swift owns item identity, equipment, installation, fuel and deployment state.
- ArRacingView.swift connects mode-dependent controls, carried items, sounds, cosmetics, contact snapshots and stationary surface marks.
- DriveBotJolt.h and DriveBotJolt.mm apply optional engine and airborne changes on the physics queue. Runner.xcodeproj/project.pbxproj bundles the resources and builds both new Swift modules.
- RunnerTests.swift covers asset loading, placement clearance, scale, transport, gear switching, boost and landing. ar_racing_ios_compatibility_test.rb tracks the central scale expression. The original pedal and geodesy cases remain in the full suite.
- codemagic-testflight.md records baseline and split-workflow timings.

On a physical iPhone verify portrait and landscape gestures, visibility and grounding of every miniature, all four doorways, hand alignment during the walk cycle, reflections, sound, scene reconstruction on furniture, relocalization, boost distance, jump and landing, and sustained frame timing. Compare driving without upgrades with the installed reference. Simulator measurements cannot establish physical-device performance or art direction.
