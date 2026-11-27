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
  private struct LotRender {
    let parent: Entity
    let center: SIMD3<Float>
    let style, district, kind: Int
    var front: Entity?
    var stage: Entity?
  }
  private var scenery: [LotRender] = []

  let fleet = RallyTraffic()

  func reset() {
    hideSamples()
    blockedCells.removeAll()
    fleet.reset()
    map = RallyFloorMap()
    worldGeneration = UUID()
    plannedRoad = nil
    connectionCursor = 0
    neighborhoods.removeAll()
    roads.forEach { $0.anchor.removeFromParent() }
    roads.removeAll()
    roadPoints.removeAll(); localRoads.removeAll()
    rewards.removeAll()
    scenery.removeAll()
    nextSample = 0
    scanCursor = 0
    builtCounts.removeAll()
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
      buildings: buildings, mappedFloor: map.covers, publish: updateActor)
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
      let forward = actor.entity.orientation(relativeTo:nil).act(SIMD3<Float>(0, 0, 1))
      updateActor(actor.id, center, actor.half, atan2(forward.x, forward.z))
      let near = simd_distance(center,camera) < 2.6
      actor.entity.isEnabled = near
      if near { actor.walker?.animate(dt: dt, velocity: blocked ? .zero : forward * speed) }
    }
    guard time - lastLOD > 0.35 else { return }
    lastLOD = time
    for i in scenery.indices {
      let lot = scenery[i], distance = simd_distance(camera,lot.center)
      if distance > 3.0, let front = lot.front {
        front.removeFromParent()
        lot.stage?.removeFromParent()
        scenery[i].front = nil
        scenery[i].stage = nil
        details[i].parts.removeAll()
      } else if distance < 2.6, lot.front == nil {
        let model = shopTemplates[lot.style]?.clone(recursive:true) ?? residence(floors:floorsForLot(lot.kind),kind:lot.kind)
        if shopTemplates[lot.style] != nil { model.scale = SIMD3(repeating:RallyScale.factor) }
        lot.parent.addChild(model)
        scenery[i].front = model
        scenery[i].stage = buildBlock(lot.style,district:lot.district,kind:lot.kind,center:lot.center,
          anchor:lot.parent,front:model,lotIndex:i,firstLoad:false)
        break
      }
    }
    for road in roads { road.anchor.isEnabled = simd_distance(camera,road.center) < 3+road.radius }
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

  private(set) var buildings: [BoundingBox] = []
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

  private(set) var map = RallyFloorMap()
  private var neighborhoods: [RallyNeighborhood] = []
  private var builtCounts: [Int:Int] = [:]
  private var nextSample: Double = 0
  private var scanCursor = 0
  private var connectionCursor = 0
  private let roadQueue = DispatchQueue(label:"de.drivebot.road-planning",qos:.utility)
  private var worldGeneration = UUID()
  private var planning = false
  private var localRoads: [(points:[SIMD3<Float>],width:Float,marked:Bool)] = []
  private var plannedRoad: (from:Int,to:Int,points:[SIMD3<Float>])?
  private var roads: [(anchor: AnchorEntity,center: SIMD3<Float>,radius: Float)] = []
  private var roadPoints: [SIMD3<Float>] = []
  private var shopTemplates: [Int:Entity] = [:]
  private var rewards: [Int:RallyItem] = [:]
  private let scanHull = ShapeResource.generateBox(size: [0.08,0.09,0.08])
  private static let offsets: [(x:Int,z:Int)] = (-7...7).flatMap { z in (-7...7).map { (x:$0,z:z) } }.sorted {
    max(abs($0.x),abs($0.z)) < max(abs($1.x),abs($1.z))
  }

  private var blockedCells = Set<RallyCell>()
  private var sampleOverlay: AnchorEntity?
  private var candidateCount = 0
  private var rejection = "Boden wird vermessen"
  func hideSamples() { sampleOverlay?.removeFromParent(); sampleOverlay = nil }
  func showSamples(near camera: SIMD3<Float>,in view: ARView) {
    hideSamples()
    guard [camera.x,camera.z].allSatisfy({ $0.isFinite && abs($0)<1000 }) else { return }
    let overlay = AnchorEntity(world:SIMD3<Float>.zero)
    let mesh = MeshResource.generateBox(size:[0.065,0.0005,0.065])
    let origin = RallyCell(camera)
    for offset in Self.offsets.prefix(64) {
      let cell = origin.offset(offset.x,offset.z)
      guard let y = map.floor(cell) ?? (blockedCells.contains(cell) ? lastFloor : nil) else { continue }
      let color: UIColor = blockedCells.contains(cell) ? .systemRed : .systemGreen
      let tile = ModelEntity(mesh:mesh,materials:[SimpleMaterial(color:color.withAlphaComponent(0.35),isMetallic:false)])
      tile.position = cell.point(y+0.002)
      overlay.addChild(tile)
    }
    view.scene.addAnchor(overlay); sampleOverlay = overlay
  }
  private var lastFloor: Float = 0
  var scanSummary: String {
    let rendered = scenery.reduce(0) { count,lot in
      let front = lot.front?.scene != nil ? 1 : 0
      let rear = lot.stage?.findEntity(named:"Rear building")?.scene != nil ? 1 : 0
      return count+front+rear
    }
    return String(format:"Boden %.2f m² · stabil %.2f m²", Float(map.observedCount+blockedCells.count)*0.0064,Float(map.stableCount)*0.0064)
      + "\nViertel \(neighborhoods.count) · Häuser \(scenery.count * 2) · sichtbar \(rendered)"
      + "\nShopmodelle \(shopTemplates.count) · Straßenaufträge \(localRoads.count+(planning ? 1 : 0))"
      + "\nHinderniszellen \(blockedCells.count) · Kandidaten \(candidateCount)"
      + "\n" + rejection
  }

  func reward(_ index: Int) -> RallyItem? { rewards[index] }

  var raceReservation: ((SIMD3<Float>)->Bool)?
  func explore(in view: ARView, time: Double, floorY: Float, player: SIMD3<Float>, car: SIMD3<Float>,
               install: (UUID,[SIMD3<Float>],[UInt32])->Void) {
    let camera = view.cameraTransform.translation
    lastFloor = floorY
    guard time >= nextSample, case .normal = view.session.currentFrame?.camera.trackingState,
          camera.x.isFinite, camera.z.isFinite, abs(camera.x)<1000, abs(camera.z)<1000, floorY.isFinite else { return }
    nextSample = time + 0.045
    var focus = car, sampleY = floorY
    if hypot(car.x-camera.x,car.z-camera.z) > 0.9 {
      focus = camera
      if let hit = view.raycast(from:CGPoint(x:view.bounds.midX,y:view.bounds.midY),allowing:.existingPlaneGeometry,alignment:.horizontal).first {
        let p = hit.worldTransform.columns.3
        if p.y.isFinite, hypot(p.x-camera.x,p.z-camera.z)<1.2,
           (hit.anchor as? ARPlaneAnchor)?.classification == .floor || abs(p.y-floorY)<0.055 {
          focus = [p.x,p.y,p.z]; sampleY = p.y
        }
      }
    }
    let origin = RallyCell(focus)
    for _ in 0..<3 {
      let offset = Self.offsets[scanCursor]
      scanCursor = (scanCursor+1) % Self.offsets.count
      let cell = origin.offset(offset.x,offset.z)
      let p = cell.point(sampleY)
      blockedCells.remove(cell)
      map.observe(cell,floor: sampleFloor(p,in: view),time: time)
    }
    guard time-lastAttempt >= 0.42 else { return }
    lastAttempt = time
    if !localRoads.isEmpty {
      let road = localRoads.removeFirst()
      if !addRoad(road.points,width:road.width,in:view,marked:road.marked) { localRoads.append(road) }
    }
    for ordinal in neighborhoods.indices {
      let district = neighborhoods[ordinal], builtLots = builtCounts[ordinal,default:0]
      guard builtLots < district.lots.count else { continue }
      let center = district.lots[builtLots]
      guard raceReservation?(center) != true, hypot(center.x-camera.x,center.z-camera.z) < 1.3, map.covers(center,radius: 0.095),
            Self.clearSite(center,player: player,car: car,occupied: []) else { continue }
      let item: RallyItem? = ordinal == 0 ? (builtLots == 0 ? .sword : nil) :
        ordinal == 1 ? (builtLots == 0 ? .blaster : builtLots == 1 ? .wings : nil) :
        ordinal == 2 && builtLots == 0 ? .nos : nil
      if addLot(center: center,angle: district.angles[builtLots],district: ordinal,kind: district.kind,
                item: item,in: view,install: install) {
        let angle = district.angles[builtLots]
        let entrance = center + SIMD3(sin(angle)*0.074,0,cos(angle)*0.074)
        let mid = (entrance+district.center)/2 + SIMD3(cos(angle)*0.012,0,-sin(angle)*0.012)
        var points: [SIMD3<Float>] = []
        for i in 0...8 {
          let t = Float(i)/8
          points.append(entrance*(1-t)*(1-t)+mid*2*t*(1-t)+district.center*t*t)
        }
        localRoads.append((points,district.kind == 1 ? 0.082 : 0.068,true))
        let right = SIMD3<Float>(cos(angle),0,-sin(angle))
        let front = SIMD3<Float>(sin(angle),0,cos(angle))
        for sign: Float in [-1,1] {
          let side = right*sign*0.048
          localRoads.append(([center+side,center+side+front*0.052,entrance+side*0.75,entrance],0.031,false))
        }
        rejection = "Gebäude platziert"
        builtCounts[ordinal] = builtLots+1
      }
      return
    }
    if let result = plannedRoad {
      plannedRoad = nil
      let lots = neighborhoods.flatMap { $0.lots }
      let valid = RallyFloorMap.validStrip(result.points) { p in
        self.map.covers(p,radius:0.047) && !lots.contains { simd_distance($0,p)<0.115 }
      }
      if valid && fleet.network.path(result.from,result.to) == nil {
        guard addRoad(result.points,width:0.091,in:view) else { return }
        fleet.network.connect(result.from,result.to,points:result.points)
        return
      }
    }
    if neighborhoods.count >= 2 && !planning {
      let pairs = neighborhoods.indices.flatMap { b in (0..<b).map { ($0,b) } }.filter { fleet.network.path($0.0,$0.1) == nil }
      if !pairs.isEmpty {
        let (a,b) = pairs[connectionCursor % pairs.count]
        connectionCursor = (connectionCursor+1) % 10000
        planning = true
        let snapshot = map, generation = worldGeneration
        let start = neighborhoods[a].center, end = neighborhoods[b].center
        let lots = neighborhoods.flatMap { $0.lots }
        roadQueue.async { [weak self] in
          let points = snapshot.road(from:start,to:end) { p in
            !lots.contains { simd_distance($0,p)<0.115 }
          }
          DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.planning = false
            if self.worldGeneration == generation, let points {
              self.plannedRoad = (a,b,points)
            }
          }
        }
      }
    }
    guard neighborhoods.count < 12 else { return }
    candidateCount = 0
    rejection = "Stabiler Boden oder freie Grundstücksfläche fehlt"
    for offset in Self.offsets {
      let cell = origin.offset(offset.x,offset.z)
      guard let y = map.floor(cell) else { continue }
      let p = cell.point(y)
      guard neighborhoods.allSatisfy({ simd_distance($0.center,p)>0.74 }),
            map.covers(p,radius: 0.047) else { continue }
      candidateCount += 1
      let next = RallyNeighborhood(cell: cell,floor: y,ordinal: neighborhoods.count,compact: !map.covers(p,radius:0.25))
      guard let lot = next.lots.first, raceReservation?(lot) != true, map.covers(lot,radius:0.095), Self.clearSite(lot,player: player,car: car,occupied: []),
        !roadPoints.contains(where: { simd_distance(lot,$0)<0.14 }) else { continue }
      rejection = "Bauplatz bestätigt"
      neighborhoods.append(next)
      return
    }
  }

  private func sampleFloor(_ p: SIMD3<Float>, in view: ARView) -> Float? {
    var level: Float?
    for dx: Float in [-0.039,0.039] {
      for dz: Float in [-0.039,0.039] {
        let q = ARRaycastQuery(origin: p+[dx,0.075,dz],direction: [0,-1,0],allowing: .existingPlaneGeometry,alignment: .horizontal)
        guard let hit = view.session.raycast(q).first, let plane = hit.anchor as? ARPlaneAnchor,
              plane.classification == .floor || plane.classification == .none else { return nil }
        let y = hit.worldTransform.columns.3.y
        guard y.isFinite,abs(y-p.y)<0.055,abs(y-(level ?? y))<0.003 else { return nil }
        level = y
      }
    }
    guard let y = level else { return nil }
    let base = SIMD3(p.x,y,p.z)
    let q = simd_quatf(angle:0,axis:[0,1,0])
    func blocked() -> Float? {
      if blockedCells.count < 16384 { blockedCells.insert(RallyCell(p)) }; return nil
    }
    guard view.scene.convexCast(convexShape: scanHull,fromPosition: base+[0,0.049,0],fromOrientation:q,
      toPosition: base+[0,0.047,0],toOrientation:q,query:.any,mask:.sceneUnderstanding,relativeTo:nil).isEmpty else { return blocked() }
    for dir: SIMD3<Float> in [[1,0,0],[-1,0,0],[0,0,1],[0,0,-1]] {
      let start = base+[0,0.025,0]
      let query = ARRaycastQuery(origin:start,direction:dir,allowing:.existingPlaneGeometry,alignment:.vertical)
      if let wall = view.session.raycast(query).first {
        let w = wall.worldTransform.columns.3
        if simd_distance(start,[w.x,w.y,w.z]) < 0.058 { return blocked() }
      }
    }
    return y
  }

  @discardableResult private func addRoad(_ points: [SIMD3<Float>],width: Float,in view: ARView,marked: Bool = true) -> Bool {
    guard RallyFloorMap.validStrip(points,clear: { map.covers($0,radius:width/2) }),
          let anchor = RallyRoadVisual.build(points:points,width:width,marked:marked) else { return false }
    let center = points.reduce(SIMD3<Float>.zero,+)/Float(points.count)
    let radius = points.map { simd_distance($0,center) }.max() ?? width
    view.scene.addAnchor(anchor)
    roads.append((anchor,center,radius))
    for (a,b) in zip(points,points.dropFirst()) {
      let steps = max(1,Int(ceil(simd_distance(a,b)/0.045)))
      for i in 0..<steps { roadPoints.append(a+(b-a)*(Float(i)/Float(steps))) }
    }
    return true
  }

  private func addLot(center: SIMD3<Float>, angle: Float, district: Int, kind: Int,item: RallyItem?, in view: ARView,
                      install: (UUID,[SIMD3<Float>],[UInt32])->Void) -> Bool {
        let index = item?.rawValue ?? 4
        let model: Entity
        if let item {
          if shopTemplates[index] == nil, let url = Bundle.main.url(forResource:"Shop"+String(index),withExtension:"usdz",subdirectory:"RallyAssets") {
            shopTemplates[index] = try? Entity.load(contentsOf:url)
          }
          if let shop = shopTemplates[index] {
            model = shop.clone(recursive:true)
            model.scale = SIMD3(repeating:RallyScale.factor)
          } else { model = residence(floors:floorsForLot(kind),kind:kind) }
          rewards[anchors.count] = item
        } else { model = residence(floors:floorsForLot(kind),kind:kind) }
        let rotation = simd_quatf(angle:angle,axis:[0,1,0])
        let p = center + rotation.act([0,0.0008,0.016])
        let anchor = AnchorEntity(world:p)
        let lot = Entity()
        lot.orientation = rotation
        anchor.addChild(lot)
        lot.addChild(model)
        if let item, let display = item.model() {
          display.name = "collectible"
          display.position = [0,RallyScale.metres(4.5),0]
          display.scale *= 1.8
          lot.addChild(display)
        }
        for (name, z) in [("Entry", Float(2.75)), ("Exit", Float(4.6))] {
          let point = Entity()
          point.name = name
          point.position.z = RallyScale.metres(z)
          lot.addChild(point)
        }
        let marker = ModelEntity(mesh: .generateBox(size: [0.012,0.0004,0.002]),
                                 materials: [UnlitMaterial(color: .systemTeal)])
        marker.position = [0,0.0005,RallyScale.metres(3.45)]
        marker.name = "Entrance light"
        marker.isEnabled = false
        lot.addChild(marker)
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
        let stage = buildBlock(index,district:district,kind:kind,center:center,anchor:lot,front:model,
          lotIndex:anchors.count-1,firstLoad:true)
        scenery.append(LotRender(parent:lot,center:center,style:index,district:district,kind:kind,front:model,stage:stage))
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
      return true
  }

  private func box(_ size: SIMD3<Float>, _ color: UIColor, at point: SIMD3<Float>, in parent: Entity) {
    let part = ModelEntity(mesh: .generateBox(size: size, cornerRadius: min(size.x,min(size.y,size.z))*0.13), materials: [SimpleMaterial(color: color, isMetallic: false)])
    part.position = point
    parent.addChild(part)
  }

  private var residenceTemplates: [Int:Entity] = [:]
  private func residence(floors: Int,kind: Int) -> Entity {
    let key = kind*16+floors
    if let template = residenceTemplates[key] { return template.clone(recursive:true) }
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
    let roofY = Float(floors)*0.016
    let ivory = UIColor(red:0.98,green:0.93,blue:0.81,alpha:1)
    let glazing = UIColor(red:0.17,green:0.39,blue:0.40,alpha:1)
    if kind == 0 {
      // Stepped parapets, porthole glazing and horizontal bands along Ocean Drive.
      for tier in 0..<3 {
        let width = 0.036-Float(tier)*0.009
        box([width,0.0025,0.017],ivory,at:[0,roofY+Float(tier)*0.0025,0],in:house)
      }
      for side: Float in [-1,1] {
        let window = ModelEntity(mesh:.generateSphere(radius:1),materials:[SimpleMaterial(color:glazing,isMetallic:true)])
        window.scale = [0.003,0.003,0.0006]; window.position = [side*0.02,roofY-0.006,0.0125]; house.addChild(window)
      }
    } else if kind == 1 {
      for column: Float in [-0.022,-0.011,0,0.011,0.022] {
        box([0.001,roofY,0.0014],ivory,at:[column,roofY/2,0.0125],in:house)
      }
      box([0.026,0.006,0.014],glazing,at:[0.006,roofY+0.003,0],in:house)
    } else if kind == 2 {
      let tile = SimpleMaterial(color:UIColor(red:0.67,green:0.31,blue:0.20,alpha:1),isMetallic:false)
      for side: Float in [-1,1] {
        let slope = ModelEntity(mesh:.generateBox(size:[0.058,0.0018,0.016]),materials:[tile])
        slope.position = [0,roofY+0.0035,side*0.007]
        slope.orientation = simd_quatf(angle:side*0.36,axis:[1,0,0]); house.addChild(slope)
      }
    }
    residenceTemplates[key] = house
    return house.clone(recursive:true)
  }

  private func floorsForLot(_ kind: Int) -> Int { kind == 1 ? 6 : kind == 2 ? 1 : 3 }

  private func buildBlock(_ index: Int, district: Int, kind: Int, center: SIMD3<Float>, anchor: Entity,
                          front: Entity,lotIndex: Int,firstLoad: Bool) -> Entity {
    let stage = Entity()
    anchor.addChild(stage)
    stage.position = [0,-0.0008,-0.016]
    let rear = residence(floors: kind == 1 ? 5 + lotIndex%3 : kind == 2 ? 1 + lotIndex%2 : 2 + lotIndex%3,kind:kind)
    let seed = RallyCell(center).seed
    let width = 0.88 + Float(seed % 23) * 0.01
    rear.name = "Rear building"
    rear.scale = [width*(kind == 2 ? 1.22 : 1),1,kind == 1 ? 1.27 : 1]
    rear.position = [0,0.0008,-0.057]
    // Soft, oval landscaped lots leave the surrounding scanned floor open.
    let green = ModelEntity(mesh:.generateSphere(radius:1),materials:[SimpleMaterial(
      color: kind == 1 ? .lightGray : UIColor(red:0.32,green:0.53,blue:0.36,alpha:1),isMetallic:false)])
    green.scale = [kind == 2 ? 0.056 : 0.040,0.00055,0.032]
    green.position = [0,0.0002,-0.052]
    stage.addChild(green)
    stage.addChild(rear)
    let shops = ["PALM MOTOR WORKS","CORAL CURIOS","TIDE SUPPLY","KEYS AIR","SURF MOTEL"]
    let venueNames = [["BAY DINER","OCEAN HOTEL"],["TRADE CENTER","GRAND ARCADE","METRO TOWER"],
      ["PALM VILLA","GARDEN COURT"],["SERVICE BAY","MOTOR CLUB"],["MARKET HALL","CORAL PLAZA"],["CINEMA","SUNSET CLUB"]]
    let venue = venueNames[kind][(lotIndex + Int(seed % 7)) % venueNames[kind].count]
    for (text, z, y) in [(shops[index],Float(0.039),Float(0.027)),(venue,Float(-0.042),Float(0.013))] {
      let letters = ModelEntity(mesh: .generateText(text, extrusionDepth: 0.012,
        font: .boldSystemFont(ofSize: 1), containerFrame: .zero, alignment: .left, lineBreakMode: .byClipping),
        materials: [UnlitMaterial(color: index.isMultiple(of: 2) ? .cyan : .systemPink)])
      let width = letters.visualBounds(relativeTo: letters).extents.x
      letters.scale = SIMD3(repeating: 0.043/max(1,width))
      letters.position = [-0.0215,y,z+0.001]
      box([0.047,0.008,0.002], .darkGray, at: [0,y+0.002,z], in: stage)
      stage.addChild(letters)
    }
    // Facade elements sit on either side of the existing +Z entrance.
    let coral = UIColor(red: 0.89,green: 0.46,blue: 0.43,alpha: 1)
    let cream = UIColor(red: 0.98,green: 0.93,blue: 0.81,alpha: 1)
    let frontage: [UIColor] = [cream,coral,.darkGray,.lightGray,.systemTeal]
    for side: Float in [-1,1] {
      box([0.017,0.024,0.002], frontage[index], at: [side*0.022,0.013,0.038], in: stage)
      if index == 0 || index == 3 {
        for slat in 0..<8 {
          box([0.015,0.0012,0.001], .gray, at: [side*0.022,0.004+Float(slat)*0.0024,0.0394], in: stage)
        }
      } else {
        box([0.015,0.017,0.001], .systemTeal, at: [side*0.022,0.012,0.0394], in: stage)
        box([0.019,0.002,0.005], cream, at: [side*0.022,0.023,0.040], in: stage)
      }
    }
    if index == 0 || index == 3 {
      let bayX: Float = -0.048
      for x: Float in [-0.014,0.014] {
        for z: Float in [-0.023,0.023] {
          let post = SIMD3<Float>(bayX+x,0.015,z)
          box([0.0015,0.029,0.0015], cream, at: post, in: stage)
          let half = SIMD3<Float>(0.00075,0.0145,0.00075)
          if firstLoad {
            let world = center + anchor.orientation.act(post)
            buildings.append(BoundingBox(min:world-half,max:world+half))
          }
        }
      }
      box([0.032,0.002,0.052], frontage[index], at: [bayX,0.031,0], in: stage)
    }
    if kind == 2 && index == 0 {
      for x: Float in [-0.016,0.016] {
        box([0.004,0.014,0.004], cream, at: [x,0.008,-0.010], in: stage)
        box([0.007,0.007,0.005], coral, at: [x,0.006,-0.010], in: stage)
      }
      box([0.045,0.002,0.012], cream, at: [0,0.016,-0.010], in: stage)
    }
    let streetSign = Entity()
    streetSign.position = [0.052,0,0.052]
    stage.addChild(streetSign)
    box([0.001,0.019,0.001], .lightGray, at: [0,0.010,0], in: streetSign)
    box([0.014,0.004,0.0008], .systemGreen, at: [0,0.019,0], in: streetSign)
    let streetName = ModelEntity(mesh: .generateText(RallyNeighborhood.names[kind].uppercased(),
      extrusionDepth: 0.01, font: .boldSystemFont(ofSize: 1)), materials: [UnlitMaterial(color: .white)])
    streetName.scale = SIMD3(repeating: 0.012/max(1,streetName.visualBounds(relativeTo: streetName).extents.x))
    streetName.position = [-0.006,0.018,0.00045]
    streetSign.addChild(streetName)
    for side: Float in [-1,1] {
      let x = side * 0.045
      box([0.016,0.001,0.017], .systemGreen, at: [x,0.001,-0.040], in: stage)
      box([0.002,0.029,0.002], .brown, at: [x,0.015,-0.04], in: stage)
      for n in 0..<8 {
        let angle = Float(n) * .pi / 4
        let frond = ModelEntity(mesh: .generateSphere(radius: 0.009), materials: [SimpleMaterial(color: .systemGreen,isMetallic: false)])
        frond.scale = [0.25,0.10,1]
        frond.position = [x+sin(angle)*0.006,0.029,-0.04+cos(angle)*0.006]
        frond.orientation = simd_quatf(angle: angle, axis: [0,1,0]) * simd_quatf(angle: 0.25, axis: [1,0,0])
        stage.addChild(frond)
      }
      box([0.001,0.029,0.001], .darkGray, at: [side*0.059,0.015,0.048], in: stage)
      box([0.005,0.002,0.002], .white, at: [side*0.059,0.030,0.048], in: stage)
      for edge: Float in [-1,1] {
        box([0.0008,0.0003,0.043], .white, at: [x+edge*0.012,0.001,0], in: stage)
      }
    }
    guard firstLoad else { return stage }
    let actors = Entity()
    anchor.addChild(actors)
    actors.position = stage.position
    for building in [front, rear] {
      let bounds = building.visualBounds(relativeTo:anchor.parent)
      let origin = center - anchor.orientation.act(stage.position)
      buildings.append(BoundingBox(min:origin+bounds.min,max:origin+bounds.max))
    }

    let population = min(district == 1 && builtCounts[district,default:0] == 0 ? 2 : 1, max(0,8-fleet.cars.filter { $0.model != nil }.count))
    fleet.spawn(tile:actors,block:district,count:population,center:center,orientation:anchor.orientation)
    for slot in 0..<(anchors.count <= 6 ? 1 : 0) {
      let walker = RallyWalker()
      actors.addChild(walker.root)
      traffic.append((walker.root,walker,[0,0.0008,0],Float(slot)*0.224,0.056,UUID(),[0.0025,0.007,0.0025]))
    }
    return stage
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
      guard rewards[i] != nil, !visited.contains(i), let threshold = anchors[i].findEntity(named: "Entry") else { return false }
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