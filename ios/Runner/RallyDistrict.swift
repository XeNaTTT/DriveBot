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
  private let hull = ShapeResource.generateBox(size: [0.066,0.029,0.069])

  func reset() {
    for anchor in anchors { anchor.removeFromParent() }
    anchors.removeAll()
    details.removeAll()
    visited.removeAll()
    highlighted = nil
    lastAttempt = -.infinity
  }

  func updateDetail(camera: SIMD3<Float>, time: TimeInterval) {
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

  func expand(on plane: ARPlaneAnchor, in view: ARView, player: SIMD3<Float>, car: SIMD3<Float>) {
    let now = ProcessInfo.processInfo.systemUptime
    guard anchors.count < 4, now - lastAttempt > 0.6, plane.alignment == .horizontal,
          case .normal = view.session.currentFrame?.camera.trackingState else { return }
    switch plane.classification {
    case .table, .seat, .ceiling, .door, .window, .wall: return
    default: break
    }
    lastAttempt = now
    let floor = plane.transform * SIMD4(plane.center.x, plane.center.y, plane.center.z, 1)
    guard abs(floor.y - car.y) < 0.035 else { return }
    for x in [-0.34,0.34,-0.12,0.12] as [Float] {
      for z in [-0.32,0.32,0] as [Float] {
        let point = plane.transform * SIMD4(plane.center.x + x * plane.extent.x, plane.center.y,
                                             plane.center.z + z * plane.extent.z, 1)
        let p = SIMD3(point.x, point.y, point.z)
        let occupied = anchors.map { $0.position(relativeTo: nil) }
        guard Self.clearSite(p, player: player, car: car, occupied: occupied) else { continue }
        let supported = [-0.035,0.035].allSatisfy { (dx: Float) in
          [-0.027,0.045].allSatisfy { (dz: Float) in
            let query = ARRaycastQuery(origin: p + SIMD3(dx,0.05,dz), direction: [0,-1,0],
                                       allowing: .existingPlaneGeometry, alignment: .horizontal)
            guard let hit = view.session.raycast(query).first else { return false }
            return hit.anchor?.identifier == plane.identifier && abs(hit.worldTransform.columns.3.y-p.y) < 0.002
          }
        }
        guard supported else { continue }
        let origin = p + SIMD3<Float>(0,0.014,0.006)
        let blocked = [SIMD3<Float>(1,0,0),[-1,0,0],[0,0,1],[0,0,-1]].contains { direction in
          let query = ARRaycastQuery(origin: origin, direction: direction,
                                     allowing: .existingPlaneGeometry, alignment: .vertical)
          guard let hit = view.session.raycast(query).first else { return false }
          let wall = hit.worldTransform.columns.3
          return simd_distance(origin, SIMD3(wall.x,wall.y,wall.z)) < 0.04
        }
        guard !blocked else { continue }
        let q = simd_quatf(angle: 0, axis: [0,1,0])
        guard view.scene.convexCast(convexShape: hull, fromPosition: p + [0,0.019,0.006],
          fromOrientation: q, toPosition: p + [0,0.017,0.006], toOrientation: q,
          query: .any, mask: .sceneUnderstanding, relativeTo: nil).isEmpty else { continue }
        guard let url = Bundle.main.url(forResource: "Shop" + String(anchors.count), withExtension: "usdz", subdirectory: "RallyAssets"),
              let model = try? Entity.load(contentsOf: url) else { return }
        let anchor = AnchorEntity(world: p)
        model.scale = SIMD3(repeating: RallyScale.factor)
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
        return
      }
    }
  }

  static func canReach(_ p: SIMD3<Float>, item: SIMD3<Float>) -> Bool {
    simd_distance(p, item) <= RallyScale.metres(1.3)
  }

  static func nearEntrance(_ local: SIMD3<Float>) -> Bool {
    let radius = RallyScale.metres(3.4)
    return abs(local.y) < RallyScale.metres(1) && local.z >= 0
      && simd_length(SIMD2(local.x,local.z)) <= radius
  }

  func entry(at p: SIMD3<Float>) -> Int? {
    anchors.indices.filter { i in
      guard !visited.contains(i), let threshold = anchors[i].findEntity(named: "Entry") else { return false }
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
    for anchor in anchors {
      let d = p - anchor.position(relativeTo: nil)

      if abs(d.x) < 0.033 && abs(d.z) < 0.025 { return false }
    }
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