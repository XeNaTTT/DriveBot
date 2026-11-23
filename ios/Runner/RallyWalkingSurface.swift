import ARKit
import RealityKit
import simd

@MainActor
final class RallyWalkingSurface {
  private let arView: ARView
  private let walkerHull = ShapeResource.generateBox(size: SIMD3<Float>(0.006, 0.015, 0.005))

  init(view: ARView) { arView = view }

  func position(_ candidate: SIMD3<Float>, from start: SIMD3<Float>, vehiclePose: Entity?,
                hasSceneReconstruction: Bool) -> SIMD3<Float>? {
    let up = SIMD3<Float>(0, 0.025, 0)
    let query = ARRaycastQuery(origin: candidate + up, direction: [0,-1,0],
                               allowing: .existingPlaneGeometry, alignment: .horizontal)
    guard let hit = arView.session.raycast(query).first else { return nil }
    let floor = hit.worldTransform.columns.3
    guard abs(floor.y - candidate.y) < 0.006 else { return nil }
    let end = SIMD3(candidate.x, floor.y, candidate.z)
    if let vehiclePose {
      let local = vehiclePose.convert(position: end, from: nil)
      if abs(local.x) < 0.016 && abs(local.z) < 0.029 { return nil }
    }
    let delta = end - start
    let distance = simd_length(delta)
    guard distance > 0.000001 else { return end }
    let heading = delta / distance
    if !hasSceneReconstruction {
      let wallQuery = ARRaycastQuery(origin: start + SIMD3(0, 0.009, 0), direction: heading,
                                     allowing: .existingPlaneGeometry, alignment: .vertical)
      if let wall = arView.session.raycast(wallQuery).first {
        let p = wall.worldTransform.columns.3
        if simd_distance(SIMD3(p.x, p.y, p.z), start + SIMD3(0, 0.009, 0)) <= distance + 0.003 {
          return nil
        }
      }
    }
    if hasSceneReconstruction {
      let offset = SIMD3<Float>(0, 0.009, 0)
      let upright = simd_quatf(angle: 0, axis: [0,1,0])
      let hits = arView.scene.convexCast(convexShape: walkerHull, fromPosition: start + offset,
        fromOrientation: upright, toPosition: end + offset, toOrientation: upright,
        query: .any, mask: .sceneUnderstanding, relativeTo: nil)
      if !hits.isEmpty { return nil }
    }
    return end
  }
}
