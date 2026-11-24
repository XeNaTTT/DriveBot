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
  private(set) var inside: Int?
  private var lastAttempt: TimeInterval = -.infinity
  private let hull = ShapeResource.generateBox(size: [0.066,0.029,0.069])

  func reset() {
    for anchor in anchors { anchor.removeFromParent() }
    anchors.removeAll()
    details.removeAll()
    inside = nil
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
          display.position = [0,0.001,-0.008]
          anchor.addChild(display)
        }
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

  func pickup(at p: SIMD3<Float>) -> RallyItem? {
    guard let inside, let item = anchors[inside].findEntity(named: "collectible"),
          Self.canReach(p, item: item.position(relativeTo: nil)) else { return nil }
    return RallyItem(rawValue: inside)
  }

  func collect(_ item: RallyItem) { anchors[item.rawValue].findEntity(named: "collectible")?.removeFromParent() }

  func entry(at p: SIMD3<Float>) -> Int? {
    anchors.indices.first { simd_distance(p, doorway($0)) < RallyScale.metres(1.5) }
  }

  private func doorway(_ i: Int) -> SIMD3<Float> {
    anchors[i].position(relativeTo: nil) + [0,0,RallyScale.metres(4)]
  }

  func toggle(_ index: Int, walker: Entity) {
    let leaving = inside != nil
    anchors[index].findEntity(named: "Roof")?.isEnabled = leaving
    if let door = anchors[index].findEntity(named: "EntryDoor") {
      var open = door.transform
      open.translation.x = leaving ? -0.48 : -1.45
      door.move(to: open, relativeTo: door.parent, duration: 0.18)
    }
    walker.setPosition(leaving ? doorway(index) : anchors[index].position(relativeTo: nil) + [0,0,0.012], relativeTo: nil)
    inside = leaving ? nil : index
  }

  func permits(_ p: SIMD3<Float>) -> Bool {
    for (i, anchor) in anchors.enumerated() {
      let d = p - anchor.position(relativeTo: nil)
      if inside == i { return abs(d.x) < 0.026 && abs(d.z) < 0.019 }
      if abs(d.x) < 0.033 && abs(d.z) < 0.025 { return false }
    }
    return true
  }
}
