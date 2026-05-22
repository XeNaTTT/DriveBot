# AR Architecture (MVP Mock Mode)

## Overview
The AR layer remains mock-first and sensor-driven. Warning data comes from `MockHudRepository`, while heading comes from the current `LocationRepository` abstraction. No real APIs or routing engines are integrated in this stage.

## Distance + Bearing Placement
- `BearingToArPositionMapper` converts warning bearing/distance into a stable relative AR position.
- Inputs:
  - user heading degrees
  - warning bearing degrees
  - warning distance meters
- Output:
  - horizontal alignment (`-1` left to `1` right)
  - vertical bias for perceived depth
  - normalized (clamped) distance

### Mapping behavior
1. Compute relative angle (`warningBearing - userHeading`) and normalize to `[-180, 180]`.
2. Project horizontal alignment within a configurable field-of-view (default 80°).
3. Clamp projected distance at `maxRenderableDistanceMeters` (default 1500 m) to keep distant markers readable.
4. Derive vertical bias from normalized distance so farther warnings render lower/less prominent.

## Warning Prioritization
Warnings are sorted for AR display and primary HUD selection with this fixed order:
1. speed camera
2. roadwork
3. speed limit
4. weather warning
5. charging/fuel POI

Distance is used as the tie-breaker inside the same warning type.

## Clutter Control
- AR marker layer shows a maximum of **3** markers.
- HUD center overlay highlights the highest-priority nearest item as the **primary** warning.
- Existing fallback messaging and mock-safe behavior remain unchanged.

## Testing
`bearing_to_ar_position_mapper_test.dart` verifies:
- direct heading alignment
- angle normalization near 0/360 boundaries
- horizontal edge clamping
- distance clamping for far markers
