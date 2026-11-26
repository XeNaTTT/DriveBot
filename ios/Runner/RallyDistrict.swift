import ARKit
import RealityKit

enum RallyScale {
  static let factor: Float = 0.05 / 6.5
  static func metres(_ fullSize: Float) -> Float { fullSize * factor }
}

@preconcurrency @MainActor
final class RallyDistrict {
  private var anchors: [AnchorEntity] = []
  private var details: [(anchor: AnchorEntity, parts: [Entity], visible: Bool)] = []
  private var lastLOD: TimeInterval = -.infinity
  private var visited: Set<Int> = []
  private var highlighted: Int?
  private var lastAttempt: TimeInterval = -.infinity
  private let hull = ShapeResource.generateBox(size: [0.16,0.078,0.16])

  func reset() {
    for anchor in anchors { anchor.removeFromParent() }
    anchors.removeAll()
    details.removeAll()
    traffic.removeAll()
    buildings.removeAll()
    elapsed = 0
    lastFrame = nil
    lastLOD = -.infinity
    visited.removeAll()
    highlighted = nil
    lastAttempt = -.infinity
  }

  func updateDetail(camera: SIMD3<Float>, time: TimeInterval) {
    let dt = Float(min(0.08, max(0, time - (lastFrame ?? time))))
    lastFrame = time
    elapsed += dt
    for actor in traffic {
      let speed: Float = actor.walker == nil ? 0.045 : 0.010
      let (point, yaw) = Self.loop(actor.phase + elapsed * speed, radius: actor.radius)
      actor.entity.position = actor.center + point
      actor.entity.orientation = simd_quatf(angle: yaw, axis: [0,1,0])
      actor.walker?.animate(dt: dt, velocity: [sin(yaw)*speed,0,cos(yaw)*speed])
    }
    guard time - lastLOD > 0.35 else { return }
    lastLOD = time
    for index in details.indices {
      let visible = simd_distance(details[index].anchor.position(relativeTo: nil), camera) < (details[index].visible ? 0.95 : 0.82)
      if details[index].visible != visible {
        for part in details[index].parts { part.isEnabled = visible }
        details[index].visible = visible
      }
    }
  }

  static func clearSite(_ p: SIMD3<Float>, player: SIMD3<Float>, car: SIMD3<Float>,
                        occupied: [SIMD3<Float>]) -> Bool {
    simd_distance(p, player) > 0.09 && simd_distance(p, car) > 0.09 &&
      occupied.allSatisfy { simd_distance($0, p) > 0.12 }
  }

  // Each tile has half a street around its pavement. Adjacent tiles share a street.
  static let blocks: [SIMD3<Float>] = [
    [-0.16,0,-0.08], [0,0,-0.08], [0.16,0,-0.08], [-0.16,0,0.08], [0,0,0.08]
  ]
  static func carCount(on block: Int) -> Int { block < 3 ? 2 : 1 }
  static func pedestrianCount(on block: Int) -> Int { block == 0 ? 2 : 1 }

  private var buildings: [BoundingBox] = []
  private var traffic: [(entity: Entity, walker: RallyWalker?, center: SIMD3<Float>, phase: Float, radius: Float)] = []
  private var lastFrame: TimeInterval?
  private var elapsed: Float = 0
  let colliderID = UUID()

  static func loop(_ distance: Float, radius: Float) -> (SIMD3<Float>, Float) {
    let side = 2 * radius
    let along = distance.truncatingRemainder(dividingBy: side)
    switch Int(distance / side) % 4 {
    case 0: return ([-radius + along,0,-radius], .pi / 2)
    case 1: return ([radius,0,-radius + along], 0)
    case 2: return ([radius - along,0,radius], -.pi / 2)
    default: return ([-radius,0,radius - along], .pi)
    }
  }

  func expand(on plane: ARPlaneAnchor, in view: ARView, player: SIMD3<Float>, car: SIMD3<Float>,
              install: (UUID, [SIMD3<Float>], [UInt32]) -> Void) {
    let now = ProcessInfo.processInfo.systemUptime
    guard anchors.isEmpty, now - lastAttempt > 0.6, plane.alignment == .horizontal,
          case .normal = view.session.currentFrame?.camera.trackingState else { return }
    switch plane.classification {
    case .table, .seat, .ceiling, .door, .window, .wall: return
    default: break
    }
    lastAttempt = now
    let floor = plane.transform * SIMD4(plane.center.x, plane.center.y, plane.center.z, 1)
    guard abs(floor.y - car.y) < 0.035 else { return }
    for _ in 0..<12 {
      let x = Float.random(in: -0.45...0.45) * plane.extent.x
      let z = Float.random(in: -0.45...0.45) * plane.extent.z
      let candidate = plane.transform * SIMD4(plane.center.x+x, plane.center.y, plane.center.z+z, 1)
      let centers = Self.blocks.map { $0 + SIMD3(candidate.x,candidate.y,candidate.z) }
      guard centers.allSatisfy({ center in
        for actor in [player, car] where abs(actor.x-center.x) < 0.11 && abs(actor.z-center.z) < 0.11 { return false }
        for dx: Float in [-0.08,0.08] {
          for dz: Float in [-0.08,0.08] {
            let query = ARRaycastQuery(origin: center + [dx,0.05,dz], direction: [0,-1,0],
              allowing: .existingPlaneGeometry, alignment: .horizontal)
            guard let hit = view.session.raycast(query).first, hit.anchor?.identifier == plane.identifier,
                  abs(hit.worldTransform.columns.3.y-center.y) < 0.002 else { return false }
          }
        }
        let q = simd_quatf(angle: 0, axis: [0,1,0])
        return view.scene.convexCast(convexShape: hull, fromPosition: center + [0,0.045,0],
          fromOrientation: q, toPosition: center + [0,0.041,0], toOrientation: q,
          query: .any, mask: .sceneUnderstanding, relativeTo: nil).isEmpty
      }) else { continue }
      let shops = (0..<4).compactMap { index -> Entity? in
        guard let url = Bundle.main.url(forResource: "Shop" + String(index), withExtension: "usdz",
                                        subdirectory: "RallyAssets") else { return nil }
        return try? Entity.load(contentsOf: url)
      }
      guard shops.count == 4 else { return }
      for (index, center) in centers.enumerated() {
        let p = center + SIMD3<Float>(0,0.0008,0.016)
        let model = index < shops.count ? shops[index] : residence(floors: 2)
        let anchor = AnchorEntity(world: p)
        if index < shops.count { model.scale = SIMD3(repeating: RallyScale.factor) }
        anchor.addChild(model)
        if let item = RallyItem(rawValue: anchors.count), let display = item.model() {
          display.name = "collectible"
          display.position = [0,RallyScale.metres(4.5),0]
          display.scale *= 1.8
          anchor.addChild(display)
        }
        for (name, z) in [("Entry", Float(2.75)), ("Exit", Float(4.6))] {
          let point = Entity()
          point.name = name
          point.position.z = RallyScale.metres(z)
          anchor.addChild(point)
        }
        let marker = ModelEntity(mesh: .generateBox(size: [0.012,0.0004,0.002]),
                                 materials: [UnlitMaterial(color: .systemTeal)])
        marker.position = [0,0.0005,RallyScale.metres(3.45)]
        marker.name = "Entrance light"
        marker.isEnabled = false
        anchor.addChild(marker)
        var trim: [Entity] = []
        func collectTrim(_ entity: Entity) {
          if ["Seam","Sill","Mullion","Pull","Stock_shelving"].contains(where: { entity.name.hasPrefix($0) }) {
            trim.append(entity)
          }
          for child in entity.children { collectTrim(child) }
        }
        collectTrim(model)
        details.append((anchor,trim,true))
        view.scene.addAnchor(anchor)
        anchors.append(anchor)
        buildBlock(index, center: center, anchor: anchor, front: model)
      }
      var vertices: [SIMD3<Float>] = []
      var indices: [UInt32] = []
      for box in buildings {
        let base = UInt32(vertices.count)
        for y in [box.min.y,box.max.y] {
          for z in [box.min.z,box.max.z] {
            for x in [box.min.x,box.max.x] { vertices.append([x,y,z]) }
          }
        }
        let faces: [UInt32] = [0,1,2,1,3,2,4,6,5,5,6,7,0,4,1,1,4,5,2,3,6,3,7,6,
                               0,2,4,2,6,4,1,5,3,3,5,7]
        indices.append(contentsOf: faces.map { base + $0 })
      }
      install(colliderID, vertices, indices)
      return
    }
  }

  private func box(_ size: SIMD3<Float>, _ color: UIColor, at point: SIMD3<Float>, in parent: Entity) {
    let part = ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, isMetallic: false)])
    part.position = point
    parent.addChild(part)
  }

  private func residence(floors: Int) -> Entity {
    let house = Entity()
    for level in 0..<floors {
      let y = Float(level) * 0.016
      box([0.052,0.016,0.024], .systemOrange, at: [0,y+0.008,0], in: house)
      for x: Float in [-0.017,0,0.017] {
        box([0.009,0.007,0.0245], .darkGray, at: [x,y+0.009,0], in: house)
      }
    }
    return house
  }

  private func buildBlock(_ index: Int, center: SIMD3<Float>, anchor: AnchorEntity, front: Entity) {
    let tile = Entity()
    anchor.addChild(tile)
    tile.position = [0,-0.0008,-0.016]
    box([0.16,0.0003,0.16], .darkGray, at: [0,0.00015,0], in: tile)
    box([0.122,0.0005,0.122], .lightGray, at: [0,0.00055,0], in: tile)
    let rear = residence(floors: index + 1)
    rear.position = [0,0.0008,-0.036]
    tile.addChild(rear)
    for building in [front, rear] {
      let bounds = building.visualBounds(relativeTo: tile)
      buildings.append(BoundingBox(min: center + bounds.min, max: center + bounds.max))
    }

    for slot in 0..<Self.carCount(on: index) {
      let car = Entity()
      let colors: [UIColor] = [.systemBlue,.systemRed,.systemYellow,.white,.systemGreen]
      box([0.013,0.006,0.029], colors[index], at: [0,0.005,0], in: car)
      box([0.011,0.004,0.014], .darkGray, at: [0,0.010,-0.002], in: car)
      for x: Float in [-0.006,0.006] {
        for z: Float in [-0.009,0.009] { box([0.003,0.005,0.005], .black, at: [x,0.003,z], in: car) }
      }
      tile.addChild(car)
      traffic.append((car,nil,.init(0,0.0003,0),Float(slot)*0.28,0.070))
    }
    for slot in 0..<Self.pedestrianCount(on: index) {
      let walker = RallyWalker()
      tile.addChild(walker.root)
      traffic.append((walker.root,walker,[0,0.0008,0],Float(slot)*0.224,0.056))
    }
  }

  static func canReach(_ p: SIMD3<Float>, item: SIMD3<Float>) -> Bool {
    simd_distance(p, item) <= RallyScale.metres(1.3)
  }

  static func nearEntrance(_ local: SIMD3<Float>) -> Bool {
    let halfWidth = RallyScale.metres(4.5)
    let depth = RallyScale.metres(5)
    return abs(local.y) < RallyScale.metres(1) && abs(local.x) <= halfWidth
      && (0...depth).contains(local.z)
  }

  func entry(at p: SIMD3<Float>) -> Int? {
    anchors.indices.filter { i in
      guard RallyItem(rawValue: i) != nil, !visited.contains(i), let threshold = anchors[i].findEntity(named: "Entry") else { return false }
      return Self.nearEntrance(threshold.convert(position: p, from: nil))
    }.min { simd_distance(p, anchors[$0].position(relativeTo: nil)) < simd_distance(p, anchors[$1].position(relativeTo: nil)) }
  }

  func highlight(_ i: Int?) {
    guard highlighted != i else { return }
    if let old = highlighted { anchors[old].findEntity(named: "Entrance light")?.isEnabled = false }
    highlighted = i
    if let i { anchors[i].findEntity(named: "Entrance light")?.isEnabled = true }
  }

  func visit(_ index: Int, from start: SIMD3<Float>, now: TimeInterval) -> RallyVisit? {
    guard entry(at: start) == index, let entry = anchors[index].findEntity(named: "Entry"),
          let exit = anchors[index].findEntity(named: "Exit") else { return nil }
    return RallyVisit(index: index, start: start, entry: entry.position(relativeTo: nil),
                      exit: exit.position(relativeTo: nil), began: now)
  }

  func finish(_ index: Int) {
    visited.insert(index)
    highlight(nil)
    anchors[index].findEntity(named: "collectible")?.removeFromParent()
    if let light = anchors[index].findEntity(named: "Entrance light") as? ModelEntity {
      light.model?.materials = [UnlitMaterial(color: .systemGreen)]
      light.isEnabled = true
    }
  }
  func permits(_ p: SIMD3<Float>) -> Bool {
    for box in buildings where p.x > box.min.x - 0.002 && p.x < box.max.x + 0.002 &&
      p.z > box.min.z - 0.002 && p.z < box.max.z + 0.002 { return false }
    return true
  }
}

/// Positions are AR-world metres. Start the wait on the frame that reaches the threshold.
struct RallyVisit {
  let index: Int
  let start, entry, exit: SIMD3<Float>
  let began: TimeInterval
  private(set) var entered: TimeInterval? = nil

  mutating func sample(at now: TimeInterval) -> (position: SIMD3<Float>, hidden: Bool, done: Bool) {
    let approach = Double(simd_distance(start, exit)) / 0.035
    let crossing = max(0.15, Double(simd_distance(exit, entry)) / 0.035)
    func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ fraction: Double) -> SIMD3<Float> {
      a + (b-a) * Float(max(0,min(1,fraction)))
    }
    if entered == nil {
      let elapsed = now - began
      if elapsed < approach { return (lerp(start,exit,elapsed / approach),false,false) }
      if elapsed < approach + crossing { return (lerp(exit,entry,(elapsed-approach)/crossing),false,false) }
      entered = now
    }
    let returning = now - (entered ?? now) - 2
    if returning < 0 { return (entry,true,false) }
    return (lerp(entry,exit,returning/crossing),false,returning >= crossing)
  }
}