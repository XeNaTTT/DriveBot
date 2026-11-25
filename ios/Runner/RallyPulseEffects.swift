import ARKit
import RealityKit
import UIKit

/// Cosmetic entities live under the existing stationary world anchor. They have
/// no collision shapes, gesture recognizers or references to the player controller.
@preconcurrency @MainActor
final class RallyPulseEffects {
  private var transient: [Entity] = []
  private var marks: [Entity] = []
  private var nextShot: TimeInterval = 0
  private lazy var dot = MeshResource.generateSphere(radius: 1)
  private lazy var line = MeshResource.generateBox(size: 1)
  private let glow = UnlitMaterial(color: .cyan)
  private let ember = UnlitMaterial(color: .systemOrange)

  static func heading(_ facing: SIMD3<Float>) -> SIMD3<Float>? {
    let flat = SIMD3(facing.x, 0, facing.z)
    let length = simd_length(flat)
    return length.isFinite && length > 0.001 ? flat / length : nil
  }

  func acceptShot(at now: TimeInterval) -> Bool {
    guard now >= nextShot else { return false }
    nextShot = now + 0.1
    return true
  }

  func emit(from origin: SIMD3<Float>, heading: SIMD3<Float>, stage: Entity, session: ARSession) {
    let range: Float = 2
    let query = ARRaycastQuery(origin: origin, direction: heading,
                               allowing: .existingPlaneGeometry, alignment: .vertical)
    let hit = session.raycast(query).first.flatMap { result -> ARRaycastResult? in
      guard let plane = result.anchor as? ARPlaneAnchor, plane.alignment == .vertical,
            plane.classification == .wall else { return nil }
      let p = result.worldTransform.columns.3
      let distance = simd_dot(SIMD3(p.x,p.y,p.z) - origin, heading)
      return distance > 0 && distance <= range ? result : nil
    }
    let group = Entity()
    stage.addChild(group)
    group.setPosition(origin, relativeTo: nil)
    group.setOrientation(simd_quatf(from: SIMD3<Float>(0,0,1), to: heading), relativeTo: nil)
    let flash = ModelEntity(mesh: dot, materials: [ember])
    flash.scale = [0.0015,0.0015,0.0025]
    group.addChild(flash)
    let distance: Float
    if let hit {
      let p = hit.worldTransform.columns.3
      distance = simd_distance(origin,[p.x,p.y,p.z])
      let spot = ModelEntity(mesh: dot, materials: [UnlitMaterial(color: .systemTeal)])
      stage.addChild(spot)
      let normal = (hit.anchor?.transform ?? hit.worldTransform).columns.1
      var n = SIMD3(normal.x,normal.y,normal.z)
      if simd_dot(n,heading) > 0 { n = -n }
      spot.setPosition(SIMD3(p.x,p.y,p.z) + n * 0.0004, relativeTo: nil)
      spot.setOrientation(simd_quatf(from: SIMD3<Float>(0,1,0), to: simd_normalize(n)), relativeTo: nil)
      spot.scale = [0.002,0.00025,0.002]
      marks.append(spot)
      if marks.count > 30 { marks.removeFirst().removeFromParent() }
      for offset: SIMD3<Float> in [[0,0.001,0],[0.0015,0.002,0],[-0.0015,0,0]] {
        let spark = ModelEntity(mesh: dot, materials: [ember])
        spark.scale = SIMD3(repeating: 0.00065)
        spark.position = offset + [0,0,distance-0.001]
        group.addChild(spark)
      }
    } else { distance = min(range,0.35) }
    let trace = ModelEntity(mesh: line, materials: [glow])
    trace.position.z = distance / 2
    trace.scale = [0.00035,0.00035,distance]
    group.addChild(trace)
    transient.append(group)
    if transient.count > 3 { transient.removeFirst().removeFromParent() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) { [weak self, weak group] in
      guard let group else { return }
      group.removeFromParent()
      self?.transient.removeAll { $0 === group }
    }
  }

  func reset() {
    for effect in transient + marks { effect.removeFromParent() }
    transient.removeAll()
    marks.removeAll()
    nextShot = 0
  }
}
