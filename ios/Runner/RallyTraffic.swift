import ARKit
import RealityKit

enum StreetModel: String, CaseIterable {
  case convertible, pickup, sedan
  var title: String {
    switch self { case .convertible: return "Marina Cabrio"; case .pickup: return "Bay Pickup"; case .sedan: return "Ocean Sedan" }
  }
  var length: Float { self == .pickup ? 0.043 : self == .sedan ? 0.039 : 0.035 }
  var topSpeed: Float { self == .pickup ? 0.86 : self == .sedan ? 0.97 : 1.18 }
  var cruise: Float { self == .pickup ? 0.032 : self == .sedan ? 0.039 : 0.048 }
  var half: SIMD3<Float> { [length * 0.24,0.008,length / 2] }
}

enum StreetControl { case parked, driving, waiting, reserved, vacant, player }

@preconcurrency @MainActor
final class StreetCar {
  let id = UUID()
  let pose: Entity
  let visual: RallyVehicleVisual
  let model: StreetModel?
  let profile: String
  var title: String { model?.title ?? "Wohnmobil" }
  var half: SIMD3<Float> { model?.half ?? [0.013,0.012,0.025] }
  var door: SIMD3<Float> { [-half.x - 0.003,0,half.z * 0.32] }
  var control: StreetControl = .parked
  var speed: Float = 0
  var cooldown: Float = 0
  var goal = 0
  var nextProbe: TimeInterval = 0
  var desiredYaw: Float = 0
  var clear = false
  var route: [SIMD3<Float>] = []
  var nextRoute: TimeInterval = 0
  var departed: RallyWalker?
  var walkingAway: Float = 0
  var awayDirection = SIMD3<Float>.zero
  var previousControl: StreetControl = .parked
  var driver: Entity?
  var floorY: Float
  var damage = RallyCarDamage()
  var gear = RallyInstalledGear()
  var position: SIMD3<Float> { pose.position(relativeTo: nil) }
  var yaw: Float {
    let forward = pose.orientation(relativeTo: nil).act(SIMD3<Float>(0,0,1))
    return atan2(forward.x,forward.z)
  }

  init(pose: Entity, visual: RallyVehicleVisual, model: StreetModel?, profile: String, floorY: Float) {
    self.pose = pose
    self.visual = visual
    self.model = model
    self.profile = profile
    self.floorY = floorY
  }

  func accessible(from point: SIMD3<Float>) -> Bool {
    guard control == .vacant || control == .parked || control == .waiting, speed < 0.001 else { return false }
    let local = pose.convert(position: point, from: nil)
    return local.x < -half.x && simd_distance(local, door) < 0.019
  }
}

@preconcurrency @MainActor
final class RallyTraffic {
  var cars: [StreetCar] = []
  private var bays: [SIMD3<Float>] = []
  private var prototypes: [StreetModel: Entity] = [:]
  private let probe = ShapeResource.generateBox(size: [0.021,0.011,0.035])


  func reset() {
    for car in cars { car.departed?.root.removeFromParent() }
    cars.removeAll()
    bays.removeAll()

  }

  func spawn(tile: Entity, block: Int, count: Int) {
    for slot in 0..<2 {
      let spot = SIMD3<Float>(slot == 0 ? -0.048 : 0.048,0,0)
      let bay = tile.convert(position: spot, to: nil)
      bays.append(bay)
      guard slot < count else { continue }
      let model = StreetModel.allCases[cars.count % StreetModel.allCases.count]
      let pose = Entity()
      tile.addChild(pose)
      pose.position = spot + [0,0.009,0]
      let visual = RallyVehicleVisual.street(model, cache: &prototypes)
      pose.addChild(visual.root)
      let car = StreetCar(pose: pose, visual: visual, model: model, profile: model.rawValue, floorY: bay.y)
      car.driver = visual.root.findEntity(named: "driver")
      car.cooldown = 1 + Float(cars.count) * 0.7
      car.goal = bays.count - 1
      cars.append(car)
    }
  }

  func walkAway(dt: Float, surface: RallyWalkingSurface, reconstruction: Bool,
                allowed: (SIMD3<Float>) -> Bool) {
    for car in cars where car.walkingAway > 0 {
      guard let walker = car.departed else { continue }
      car.walkingAway = max(0,car.walkingAway-dt)
      let p = walker.root.position(relativeTo: nil)
      let velocity = car.awayDirection * 0.012
      if let next = surface.position(p+velocity*dt,from: p,vehiclePose: nil,hasSceneReconstruction: reconstruction),
         allowed(next) {
        walker.root.setPosition(next,relativeTo: nil)
        walker.animate(dt: dt,velocity: car.walkingAway > 0 ? velocity : .zero)
      } else {
        car.walkingAway = 0
        walker.animate(dt: dt,velocity: .zero)
      }
    }
  }

  func nearby(_ point: SIMD3<Float>) -> StreetCar? {
    cars.filter { $0.accessible(from: point) }.min {
      simd_distance($0.position,point) < simd_distance($1.position,point)
    }
  }

  func tick(view: ARView, dt: Float, time: TimeInterval, camera: SIMD3<Float>, obstacles: [SIMD3<Float>],
            buildings: [BoundingBox], publish: (UUID,SIMD3<Float>,SIMD3<Float>,Float) -> Void) {
    advance(dt: dt,time: time,camera: camera,obstacles: obstacles,buildings: buildings,publish: publish) { car,look,heading in
      self.navigable(view: view,car: car,look: look,heading: heading)
    }
  }

  private func navigable(view: ARView, car: StreetCar, look: SIMD3<Float>, heading: Float) -> Bool {
    let p = car.position
    let dir = SIMD3<Float>(sin(heading),0,cos(heading))
    let edge = SIMD3(dir.z,0,-dir.x)*car.half.x
    guard [look-edge,look+edge].allSatisfy({ point in
      let query = ARRaycastQuery(origin: point + [0,0.035,0], direction: [0,-1,0],
        allowing: .existingPlaneGeometry, alignment: .horizontal)
      guard let hit = view.session.raycast(query).first, let plane = hit.anchor as? ARPlaneAnchor,
            abs(hit.worldTransform.columns.3.y-car.floorY) < 0.004 else { return false }
      switch plane.classification {
      case .table,.seat,.ceiling,.wall,.door,.window: return false
      default: return true
      }
    }) else { return false }
    let wall = ARRaycastQuery(origin: p,direction: dir,allowing: .existingPlaneGeometry,alignment: .vertical)
    if let hit = view.session.raycast(wall).first {
      let w = hit.worldTransform.columns.3
      if simd_distance(p,[w.x,w.y,w.z]) < simd_distance(p,look)+car.half.z { return false }
    }
    let q = simd_quatf(angle: heading, axis: [0,1,0])
    guard view.scene.convexCast(convexShape: probe, fromPosition: p, fromOrientation: q,
      toPosition: look, toOrientation: q, query: .any, mask: .sceneUnderstanding, relativeTo: nil).isEmpty else { return false }

    return true
  }

  func advance(dt: Float, time: TimeInterval, camera: SIMD3<Float>, obstacles: [SIMD3<Float>],
               buildings: [BoundingBox], publish: (UUID,SIMD3<Float>,SIMD3<Float>,Float) -> Void,
               navigable: (StreetCar,SIMD3<Float>,Float) -> Bool) {
    for car in cars where car.control != .player {
      defer { if car.control != .reserved { publish(car.id,car.position,car.half,car.yaw) } }
      guard car.control != .reserved && car.control != .vacant, let model = car.model else { continue }
      if car.control == .parked {
        car.cooldown -= dt
        guard car.cooldown <= 0 else { continue }
        let available = bays.indices.filter { i in
          i != car.goal && !cars.contains { $0 !== car && $0.control != .player && $0.goal == i }
        }
        guard let target = available.randomElement() else { continue }
        car.route.removeAll()
        car.nextRoute = 0
        car.goal = target
        car.control = .driving
      }
      let p = car.position
      var delta = bays[car.goal] - p
      delta.y = 0
      let distance = simd_length(delta)
      if distance < 0.004 && car.speed < 0.009 {
        car.speed = 0
        car.control = .parked
        car.cooldown = .random(in: 3...8)
        continue
      }
      let neighbors = obstacles + cars.filter { $0 !== car && $0.control != .player }.map { $0.position }
      if time >= car.nextRoute {
        car.route = StreetRoute.plan(from: p, to: bays[car.goal], clearance: car.half.x + 0.003,
          buildings: buildings, obstacles: neighbors)
        car.nextRoute = time + (car.control == .waiting ? 0.85 : 2.5)
      }
      while let first = car.route.first, simd_distance(SIMD2(p.x,p.z),SIMD2(first.x,first.z)) < 0.009 {
        car.route.removeFirst()
      }
      if let waypoint = car.route.first { delta = waypoint-p; delta.y = 0 }
      let yaw = car.yaw
      if time >= car.nextProbe {
        car.nextProbe = time + (simd_distance(camera,p) > 0.8 ? 0.32 : 0.14)
        let target = atan2(delta.x,delta.z)
        car.clear = false
        for offset: Float in [0,0.58,-0.58,1.18,-1.18,1.75,-1.75] {
          let heading = target + offset
          let dir = SIMD3<Float>(sin(heading),0,cos(heading))
          let look = p + dir * min(distance,0.034)
          guard !neighbors.contains(where: { abs(look.y-$0.y) < 0.025 && hypot(look.x-$0.x,look.z-$0.z) < car.half.x + 0.014 }), !buildings.contains(where: { box in
            let extent = SIMD2(abs(dir.z)*car.half.x + abs(dir.x)*car.half.z,
                               abs(dir.x)*car.half.x + abs(dir.z)*car.half.z)
            return abs(look.x-box.center.x) < box.extents.x/2 + extent.x &&
              abs(look.z-box.center.z) < box.extents.z/2 + extent.y
          }) else { continue }
          guard navigable(car,look,heading) else { continue }
          car.desiredYaw = heading
          car.clear = true
          break
        }
      }
      let error = atan2(sin(car.desiredYaw-yaw),cos(car.desiredYaw-yaw))
      let turn = min(2.6*dt,max(-2.6*dt,error))
      let heading = yaw + turn
      let forward = SIMD3<Float>(sin(heading),0,cos(heading))
      let blocked = neighbors.contains { other in
        let d = other-p
        let ahead = simd_dot(d,forward)
        return abs(d.y) < 0.027 && ahead >= 0 && ahead < car.half.z + 0.032 &&
          abs(d.x*forward.z-d.z*forward.x) < car.half.x + 0.015
      }
      let targetSpeed: Float = car.clear && !blocked && abs(error) < 0.33 ? min(model.cruise, distance*1.5) : 0
      car.speed = StreetMotion.advance(speed: car.speed, target: targetSpeed, dt: dt)
      if car.clear { car.pose.setOrientation(simd_quatf(angle: heading,axis: [0,1,0]), relativeTo: nil) }
      car.pose.setPosition(p + forward * (dt*car.speed), relativeTo: nil)
      car.control = targetSpeed == 0 && car.speed < 0.001 ? .waiting : .driving
    }
  }
}


enum StreetMotion {
  static func advance(speed: Float, target: Float, dt: Float) -> Float {
    let step = max(0,min(dt,0.08))
    return max(0,speed + min(step*0.055,max(-step*0.16,target-speed)))
  }
}

// A bounded local grid supplies intermediate goals. Each executed segment also checks live AR geometry.
enum StreetRoute {
  static func plan(from start: SIMD3<Float>, to goal: SIMD3<Float>, clearance: Float,
                   buildings: [BoundingBox], obstacles: [SIMD3<Float>]) -> [SIMD3<Float>] {
    let step: Float = 0.018
    let margin = 5
    let origin = SIMD2(min(start.x,goal.x),min(start.z,goal.z)) - SIMD2(repeating: Float(margin)*step)
    let width = min(48,Int(abs(goal.x-start.x)/step)+2*margin+2)
    let height = min(48,Int(abs(goal.z-start.z)/step)+2*margin+2)
    func cell(_ p: SIMD3<Float>) -> Int {
      let xy = (SIMD2(p.x,p.z)-origin)/step
      return min(height-1,max(0,Int(xy.y.rounded())))*width + min(width-1,max(0,Int(xy.x.rounded())))
    }
    func point(_ i: Int) -> SIMD3<Float> {
      [origin.x+Float(i%width)*step,start.y,origin.y+Float(i/width)*step]
    }
    let first = cell(start), last = cell(goal)
    var parent = Array(repeating: -1,count: width*height)
    parent[first] = first
    var queue = [first], head = 0
    while head < queue.count && parent[last] == -1 {
      let i = queue[head]
      head += 1
      for (dx,dz) in [(1,0),(0,1),(-1,0),(0,-1)] {
        let x = i%width + dx, z = i/width + dz
        guard x >= 0, x < width, z >= 0, z < height else { continue }
        let next = z*width+x
        guard parent[next] == -1 else { continue }
        let p = point(next)
        guard !buildings.contains(where: { abs(p.x-$0.center.x) <= $0.extents.x/2+clearance &&
          abs(p.z-$0.center.z) <= $0.extents.z/2+clearance }),
          !obstacles.contains(where: { abs(p.y-$0.y)<0.03 && hypot(p.x-$0.x,p.z-$0.z)<clearance+0.014 }) else { continue }
        parent[next] = i
        queue.append(next)
      }
    }
    guard parent[last] != -1 else { return [] }
    var route = [goal], i = last
    while i != first {
      let previous = parent[i]
      if previous != first && i-previous != previous-parent[previous] { route.append(point(previous)) }
      i = previous
    }
    return Array(route.reversed())
  }
}
