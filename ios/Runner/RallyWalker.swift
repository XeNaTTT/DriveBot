import RealityKit
import UIKit
import simd

enum RallyWalking {
  static func canEnter(distance: Float, localX: Float) -> Bool {
    localX < -0.012 && distance < 0.032
  }

  static func velocity(input: SIMD2<Float>, cameraRight: SIMD3<Float>) -> SIMD3<Float> {
    let horizontal = SIMD3(cameraRight.x, 0, cameraRight.z)
    guard simd_length(horizontal) > 0.1 else { return .zero }
    let right = simd_normalize(horizontal)
    let stick = input / max(1, simd_length(input))
    return (right * stick.x + SIMD3(-right.z, 0, right.x) * stick.y) * 0.026
  }
}

/// Animated pilot with a procedural fallback. The root sits at the soles of the shoes.
final class RallyWalker {
  let root: Entity
  private let hips: Entity
  private var legs: [Entity] = []
  private var arms: [Entity] = []
  private var pilot: Entity?
  private weak var skin: ModelEntity?
  private var handChain: [Int] = []
  private var gait: AnimationPlaybackController?
  private var phase: Float = 0

  @MainActor init() {
    root = Entity()
    hips = Entity()
    root.addChild(hips)
    hips.position.y = 0.008
    if let url = Bundle.main.url(forResource: "RallyPilot", withExtension: "usdz", subdirectory: "RallyAssets"),
       let model = try? Entity.load(contentsOf: url) {
      let bounds = model.visualBounds(relativeTo: model)
      if bounds.extents.y > 0 {
        let scale = RallyScale.metres(1.8) / bounds.extents.y
        model.scale = SIMD3(repeating: scale)
        model.position.y = -bounds.min.y * scale
        root.addChild(model)
        pilot = model
        func bind(_ entity: Entity) {
          if let mesh = entity as? ModelEntity,
             let hand = mesh.jointNames.first(where: { $0.hasSuffix("Skeleton_arm_joint_R__3_") }) {
            let segments = hand.split(separator: "/")
            handChain = segments.indices.compactMap { index in
              mesh.jointNames.firstIndex(of: segments[...index].joined(separator: "/"))
            }
            skin = mesh
          }
          for child in entity.children { bind(child) }
        }
        bind(model)
        return
      }
    }
    let denim = SimpleMaterial(color: UIColor(white: 0.13, alpha: 1), isMetallic: false)
    let jacket = SimpleMaterial(color: .systemTeal, isMetallic: false)
    let skin = SimpleMaterial(color: UIColor(red: 0.60, green: 0.37, blue: 0.25, alpha: 1), isMetallic: false)
    func part(_ parent: Entity, _ size: SIMD3<Float>, _ center: SIMD3<Float>, _ material: SimpleMaterial) {
      let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: min(size.x, min(size.y, size.z)) * 0.35),
                               materials: [material])
      entity.position = center
      parent.addChild(entity)
    }
    part(hips, [0.0045,0.006,0.0027], [0,0.003,0], jacket)
    let head = ModelEntity(mesh: .generateSphere(radius: 0.0017), materials: [skin])
    head.position.y = 0.008
    hips.addChild(head)
    for side: Float in [-1, 1] {
      let leg = Entity()
      hips.addChild(leg)
      leg.position.x = side * 0.0011
      part(leg, [0.0018,0.007,0.002], [0,-0.0035,0], denim)
      part(leg, [0.002,0.001,0.003], [0,-0.0075,0.0005], denim)
      legs.append(leg)
      let arm = Entity()
      hips.addChild(arm)
      arm.position = [side * 0.0028, 0.005, 0]
      part(arm, [0.0014,0.004,0.0015], [0,-0.002,0], jacket)
      part(arm, [0.0012,0.002,0.0012], [0,-0.005,0], skin)
      arms.append(arm)
    }
  }

  @MainActor func animate(dt: Float, velocity: SIMD3<Float>) {
    if let skin, let held = root.findEntity(named: "held item"), !handChain.isEmpty {
      let joints = skin.jointTransforms
      var hand = matrix_identity_float4x4
      for index in handChain where index < joints.count { hand = hand * joints[index].matrix }
      let p = hand.columns.3
      held.position = skin.convert(position: [p.x,p.y,p.z], to: root)
    }
    let speed = simd_length(velocity)
    if let pilot {
      if speed > 0 && gait == nil, let walk = pilot.availableAnimations.first {
        gait = pilot.playAnimation(walk.repeat())
      } else if speed == 0 {
        gait?.stop()
        gait = nil
      }
    }
    phase += dt * (speed > 0 ? speed * 620 : 2)
    let swing = speed > 0 ? sin(phase) * 0.45 : 0
    hips.position.y = 0.008 + abs(sin(phase)) * (speed > 0 ? 0.0003 : 0.00005)
    for index in legs.indices {
      let angle = index == 0 ? swing : -swing
      legs[index].orientation = simd_quatf(angle: angle, axis: [1,0,0])
      arms[index].orientation = simd_quatf(angle: -angle, axis: [1,0,0])
    }
    if speed > 0 {
      let facing = simd_quatf(angle: atan2(velocity.x, velocity.z), axis: [0,1,0])
      root.setOrientation(simd_slerp(root.orientation(relativeTo: nil), facing, min(1, dt * 14)),
                          relativeTo: nil)
    }
  }
}
