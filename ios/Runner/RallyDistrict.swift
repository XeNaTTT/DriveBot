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

  let fleet = RallyTraffic()

  func reset() {
    fleet.reset()
    for anchor in anchors { anchor.removeFromParent() }
    anchors.removeAll()
    details.removeAll()
    traffic.removeAll()
    buildings.removeAll()
    lastFrame = nil
    lastLOD = -.infinity
    visited.removeAll()
    highlighted = nil
    lastAttempt = -.infinity
  }

  func updateDetail(view: ARView, camera: SIMD3<Float>, time: TimeInterval, walkerPosition: SIMD3<Float>?, parkedCar: Entity?,
                    updateActor: (UUID, SIMD3<Float>, SIMD3<Float>, Float) -> Void) {
    let dt = Float(min(0.08, max(0, time - (lastFrame ?? time))))
    lastFrame = time
    fleet.tick(view: view, dt: dt, time: time, camera: camera,
      obstacles: [walkerPosition,parkedCar?.position(relativeTo: nil)].compactMap { $0 } + traffic.map { $0.entity.position(relativeTo: nil) },
      buildings: buildings, publish: updateActor)
    for index in traffic.indices {
      let actor = traffic[index]
      let speed: Float = actor.walker == nil ? 0.045 : 0.010
      let phase = actor.phase + dt * speed
      let (point, yaw) = Self.loop(phase, radius: actor.radius)
      let next = actor.center + point
      var blocked = false
      if let parent = actor.entity.parent {
        let world = parent.convert(position: next, to: nil)
        if let walkerPosition {
          let delta = walkerPosition - world
          let local = simd_quatf(angle: -yaw, axis: [0,1,0]).act(delta)
          if abs(local.y) < 0.018 && abs(local.x) < actor.half.x + 0.003 &&
             abs(local.z) < actor.half.z + 0.003 { blocked = true }
        }
        if fleet.cars.contains(where: { car in
          let local = car.pose.convert(position: world, from: nil)
          return abs(local.y) < 0.025 && abs(local.x) < car.half.x + 0.003 && abs(local.z) < car.half.z + 0.003
        }) { blocked = true }
        if let parkedCar {
          let local = parkedCar.convert(position: world, from: nil)
          let radius = max(actor.half.x, actor.half.z)
          if abs(local.y) < 0.022 && abs(local.x) < 0.013 + radius &&
             abs(local.z) < 0.025 + radius { blocked = true }
        }
      }
      if !blocked {
        traffic[index].phase = phase
        actor.entity.position = next
        actor.entity.orientation = simd_quatf(angle: yaw, axis: [0,1,0])
      }
      let center = actor.entity.convert(position: [0,actor.half.y,0], to: nil)
      let forward = actor.entity.orientation.act(SIMD3<Float>(0, 0, 1))
      updateActor(actor.id, center, actor.half, atan2(forward.x, forward.z))
      actor.walker?.animate(dt: dt, velocity: blocked ? .zero : forward * speed)
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
  private var traffic: [(entity: Entity, walker: RallyWalker?, center: SIMD3<Float>, phase: Float, radius: Float, id: UUID, half: SIMD3<Float>)] = []
  var actorIDs: [UUID] { traffic.map { $0.id } + fleet.cars.map { $0.id } }
  private var lastFrame: TimeInterval?
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
    let part = ModelEntity(mesh: .generateBox(size: size, cornerRadius: min(size.x,min(size.y,size.z))*0.13), materials: [SimpleMaterial(color: color, isMetallic: false)])
    part.position = point
    parent.addChild(part)
  }

  private func residence(floors: Int) -> Entity {
    let house = Entity()
    let paints: [UIColor] = [UIColor(red: 0.96,green: 0.72,blue: 0.66,alpha: 1), .systemTeal, .systemPink, UIColor(red: 0.62,green: 0.85,blue: 0.75,alpha: 1), .systemBrown]
    for level in 0..<floors {
      let y = Float(level) * 0.016
      box([0.052,0.016,0.024], paints[(floors-1)%paints.count], at: [0,y+0.008,0], in: house)
      box([0.054,0.0013,0.026], .white, at: [0,y+0.015,0], in: house)
      if level == 0 {
        for side: Float in [-1,1] {
          let awning = ModelEntity(mesh: .generateBox(size: [0.021,0.0008,0.009],cornerRadius: 0.00035),
            materials: [SimpleMaterial(color: floors.isMultiple(of: 2) ? .systemPink : .systemTeal,isMetallic: false)])
          awning.position = [side*0.014,0.013,0.015]
          awning.orientation = simd_quatf(angle: 0.22,axis: [1,0,0])
          house.addChild(awning)
        }
      }
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
    let shops = ["PALM MOTOR WORKS","CORAL CURIOS","TIDE SUPPLY","KEYS AIR","SURF MOTEL"]
    let venues = ["BAY DINER","OCEAN HOTEL","PALM SERVICE","LAGOON INN","COAST SUITES"]
    for (text, z, y) in [(shops[index],Float(0.039),Float(0.027)),(venues[index],Float(-0.021),Float(0.013))] {
      let letters = ModelEntity(mesh: .generateText(text, extrusionDepth: 0.012,
        font: .boldSystemFont(ofSize: 1), containerFrame: .zero, alignment: .left, lineBreakMode: .byClipping),
        materials: [UnlitMaterial(color: index.isMultiple(of: 2) ? .cyan : .systemPink)])
      let width = letters.visualBounds(relativeTo: letters).extents.x
      letters.scale = SIMD3(repeating: 0.043/max(1,width))
      letters.position = [-0.0215,y,z+0.001]
      box([0.047,0.008,0.002], .darkGray, at: [0,y+0.002,z], in: tile)
      tile.addChild(letters)
    }
    // Facade elements sit on either side of the existing +Z entrance.
    let coral = UIColor(red: 0.89,green: 0.46,blue: 0.43,alpha: 1)
    let cream = UIColor(red: 0.98,green: 0.93,blue: 0.81,alpha: 1)
    let frontage: [UIColor] = [cream,coral,.darkGray,.lightGray,.systemTeal]
    for side: Float in [-1,1] {
      box([0.017,0.024,0.002], frontage[index], at: [side*0.022,0.013,0.038], in: tile)
      if index == 0 || index == 3 {
        for slat in 0..<8 {
          box([0.015,0.0012,0.001], .gray, at: [side*0.022,0.004+Float(slat)*0.0024,0.0394], in: tile)
        }
      } else {
        box([0.015,0.017,0.001], .systemTeal, at: [side*0.022,0.012,0.0394], in: tile)
        box([0.019,0.002,0.005], cream, at: [side*0.022,0.023,0.040], in: tile)
      }
    }
    if index == 0 || index == 3 {
      let bayX: Float = -0.048
      for x: Float in [-0.014,0.014] {
        for z: Float in [-0.023,0.023] {
          let post = SIMD3<Float>(bayX+x,0.015,z)
          box([0.0015,0.029,0.0015], cream, at: post, in: tile)
          let half = SIMD3<Float>(0.00075,0.0145,0.00075)
          buildings.append(BoundingBox(min: center+post-half,max: center+post+half))
        }
      }
      box([0.032,0.002,0.052], frontage[index], at: [bayX,0.031,0], in: tile)
    }
    if index == 2 {
      for x: Float in [-0.016,0.016] {
        box([0.004,0.014,0.004], cream, at: [x,0.008,-0.010], in: tile)
        box([0.007,0.007,0.005], coral, at: [x,0.006,-0.010], in: tile)
      }
      box([0.045,0.002,0.012], cream, at: [0,0.016,-0.010], in: tile)
    }
    let streetSign = Entity()
    streetSign.position = [0.052,0,0.052]
    tile.addChild(streetSign)
    box([0.001,0.019,0.001], .lightGray, at: [0,0.010,0], in: streetSign)
    box([0.014,0.004,0.0008], .systemGreen, at: [0,0.019,0], in: streetSign)
    let streetName = ModelEntity(mesh: .generateText(["PALM AV","KEYS ST","BAY AV","REEF ST","SURF AV"][index],
      extrusionDepth: 0.01, font: .boldSystemFont(ofSize: 1)), materials: [UnlitMaterial(color: .white)])
    streetName.scale = SIMD3(repeating: 0.012/max(1,streetName.visualBounds(relativeTo: streetName).extents.x))
    streetName.position = [-0.006,0.018,0.00045]
    streetSign.addChild(streetName)
    for side: Float in [-1,1] {
      let x = side * 0.045
      box([0.016,0.001,0.017], .systemGreen, at: [x,0.001,-0.040], in: tile)
      box([0.002,0.029,0.002], .brown, at: [x,0.015,-0.04], in: tile)
      for n in 0..<8 {
        let angle = Float(n) * .pi / 4
        let frond = ModelEntity(mesh: .generateSphere(radius: 0.009), materials: [SimpleMaterial(color: .systemGreen,isMetallic: false)])
        frond.scale = [0.25,0.10,1]
        frond.position = [x+sin(angle)*0.006,0.029,-0.04+cos(angle)*0.006]
        frond.orientation = simd_quatf(angle: angle, axis: [0,1,0]) * simd_quatf(angle: 0.25, axis: [1,0,0])
        tile.addChild(frond)
      }
      box([0.001,0.029,0.001], .darkGray, at: [side*0.059,0.015,0.048], in: tile)
      box([0.005,0.002,0.002], .white, at: [side*0.059,0.030,0.048], in: tile)
      for edge: Float in [-1,1] {
        box([0.0008,0.0003,0.043], .white, at: [x+edge*0.012,0.001,0], in: tile)
      }
    }
    for building in [front, rear] {
      let bounds = building.visualBounds(relativeTo: tile)
      buildings.append(BoundingBox(min: center + bounds.min, max: center + bounds.max))
    }

    fleet.spawn(tile: tile, block: index, count: Self.carCount(on: index))
    for slot in 0..<Self.pedestrianCount(on: index) {
      let walker = RallyWalker()
      tile.addChild(walker.root)
      traffic.append((walker.root,walker,[0,0.0008,0],Float(slot)*0.224,0.056,UUID(),[0.0025,0.007,0.0025]))
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
    for car in fleet.cars where car.control != .player {
      let local = car.pose.convert(position: p, from: nil)
      if abs(local.x) < car.half.x + 0.002 && abs(local.z) < car.half.z + 0.002 && abs(local.y) < 0.025 { return false }
    }
    for actor in traffic {
      let local = actor.entity.convert(position: p, from: nil)
      if abs(local.x) < actor.half.x + 0.002 && abs(local.z) < actor.half.z + 0.002 &&
         abs(local.y - actor.half.y) < actor.half.y + 0.003 { return false }
    }
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