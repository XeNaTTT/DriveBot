# Third-party notices

## Jolt Physics

- **Project:** Jolt Physics
- **Source:** <https://github.com/jrouwe/JoltPhysics>
- **Pinned release:** `v5.6.0`
- **Pinned commit:** `e77f175595e64cb44218cc9d9d56fc365ad0e36a`
- **License:** MIT (the license text is retained in
  [`LICENSES/JoltPhysics-LICENSE.txt`](LICENSES/JoltPhysics-LICENSE.txt))
- **Purpose:** Native collision, static scene-mesh and vehicle simulation for
  the iOS AR racing view.

The iOS dependency setup fetches the complete upstream checkout at the pinned
revision. The CocoaPods target compiles Jolt's library sources but deliberately
excludes desktop graphics backends, optional debug-renderer utilities and
shader tests. Jolt's core `DebugRenderer.cpp` remains part of the matched
library source set because core shape code can reference its base types.

## Kenney Car Kit

- **Project:** Kenney Car Kit
- **Source:** <https://kenney.nl/assets/car-kit>
- **License:** CC0 1.0
- **Current use:** None. The current AR racing implementation creates three
  visually distinct placeholder vehicles from RealityKit primitives. No Kenney
  source model or derived USDZ file is currently stored or bundled, so these
  placeholders must not be represented as integrated Kenney assets.
