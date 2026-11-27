import DriveBotJolt
import ARKit
import RealityKit
import AudioToolbox

struct RallyCourse {
  typealias Point = SIMD3<Float>
  let start: Point
  let gates: [Point]
  let normals: [Point]
  func gridPosition(_ lane: Int) -> Point {
    let n = normals[0]
    return start+Point(n.z,0,-n.x)*(Float(lane)*0.045)
  }
  var key: String {
    ([start]+gates).map { let c = RallyCell($0); return "\(c.x),\(c.z)" }.joined(separator:";")
  }
  static func plan(near car: Point, map: RallyFloorMap, clear: (Point)->Bool) -> Self? {
    guard [car.x,car.y,car.z].allSatisfy({ $0.isFinite && abs($0)<1000 }) else { return nil }
    let origin = RallyCell(car)
    var shorter: Self?
    func pass(_ p: Point) -> Bool {
      map.covers(p,radius:0.048) && clear(p) &&
        [Point(0.04,0,0),Point(-0.04,0,0),Point(0,0,0.04),Point(0,0,-0.04)].allSatisfy { clear(p+$0) }
    }
    for (dx,dz) in [(2,0),(-2,0),(0,2),(0,-2),(3,2),(-3,-2)] {
      let cell = origin.offset(dx,dz)
      guard let y = map.floor(cell) else { continue }
      let start = cell.point(y)
      guard map.covers(start,radius:0.13), pass(start),
        RallyFloorMap.validStrip([[car.x,y,car.z],start],clear:{ map.covers($0,radius:0.022) && clear($0) }),
        (-2...2).allSatisfy({ pass(start+Point(Float($0)*0.045,0,0)) }) else { continue }
      var gates: [Point] = [], normals: [Point] = [], cursor = start
      for i in 0..<12 {
        let directions = [Point(0,0,1),Point(1,0,0),Point(0,0,-1),Point(-1,0,0)]
        var chosen: (Point,Point)?
        for k in 0..<4 {
          let n = directions[(i+k+Int(cell.seed%4))%4]
          if let previous = normals.last, simd_dot(n,previous) < -0.9 { continue }
          for distance: Float in [0.48,0.32,0.20] {
            let end = cursor+n*distance
            guard !gates.contains(where:{ simd_distance($0,end)<0.09 }),
              RallyFloorMap.validStrip([cursor,end],clear:pass),
              pass(end+n*0.035) else { continue }
            chosen = (end,n)
            break
          }
          if chosen != nil { break }
        }
        guard let (end,n) = chosen else { break }
        gates.append(end)
        normals.append(n)
        cursor = end
      }
      if gates.count >= 2 {
        let candidate = Self(start:start,gates:gates,normals:normals)
        if gates.count >= 8 { return candidate }
        if gates.count > (shorter?.gates.count ?? 0) { shorter = candidate }
      }
    }
    return shorter
  }
  func crossed(_ index: Int, from a: Point, to b: Point) -> Bool {
    crossingFraction(index,from:a,to:b) >= 0
  }
  func crossingFraction(_ index: Int, from a: Point, to b: Point) -> Float {
    let radius: Float = index == gates.count-1 ? 0.11 : 0.085
    let n = normals[index], center = gates[index]+Point(0,radius,0)
    let da = simd_dot(a-center,n), db = simd_dot(b-center,n)
    let across = Point(n.z,0,-n.x)
    return rrGateFraction(da,db,simd_dot(a-center,across),simd_dot(b-center,across),
      a.y-center.y,b.y-center.y,radius)
  }
}

struct RaceDriverInput {
  let id: UUID
  let spawn: SIMD3<Float>
  let heading: Float
  let profile: String
  var throttle: Float = 0
  var steer: Float = 0
  var brake: Float = 1
}

@preconcurrency @MainActor
final class RallyRace: NSObject {
  typealias Point = SIMD3<Float>
  private enum Phase { case waiting, countdown, running, results }
  private var phase = Phase.waiting
  private var course: RallyCourse?
  private var anchor: AnchorEntity?
  private var lamps: [ModelEntity] = []
  private let planner = DispatchQueue(label:"de.drivebot.rally.race-planning",qos:.utility)
  private var planning = false
  private var generation = UUID()
  private var ringTemplates: [Bool:Entity] = [:]
  private var ring: Entity?
  private var cars: [StreetCar] = []
  private(set) var commands: [RaceDriverInput] = []
  private var stuck = Array(repeating:0.0,count:4)
  private var reverseUntil = Array(repeating:0.0,count:4)
  private var cache: [StreetModel:Entity] = [:]
  private var progress = Array(repeating:0,count:5)
  private var finish = Array<Double?>(repeating:nil,count:5)
  private var clock = 0.0, previousTime: Double?, nextPlan = 0.0, nextHUD = 0.0
  private var previous: Point?
  private var lastCount = 0
  private var nextRanking = 0.0
  private var rankingPending = false
  private var distances: [(gate:Int,remaining:Float)] = []
  private var finalRank: Int?
  private var flashUntil = 0.0
  private var previousPhysicsClock: Double?
  private var dismissed: Point?
  private let panel = UIStackView()
  private let label = UILabel()
  private let buttons = UIStackView()
  private var removals: [UUID] = []
  var target: SIMD3<Float>? {
    guard phase == .running, let course else { return nil }
    let i = progress[0]
    return course.gates[i]+[0,i == course.gates.count-1 ? 0.11 : 0.085,0]
  }
  var overlay: UIView { panel }
  var hasEvent: Bool { course != nil }
  var holding: Bool { phase == .countdown }
  init(root: UIView) {
    super.init()
    buttons.distribution = .fillEqually
    let buttonHeight = buttons.heightAnchor.constraint(greaterThanOrEqualToConstant:44)
    buttonHeight.priority = .defaultHigh; buttonHeight.isActive = true
    panel.axis = .vertical
    panel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    panel.layer.cornerRadius = 8
    label.textColor = .white
    label.font = .monospacedDigitSystemFont(ofSize:15,weight:.semibold)
    label.numberOfLines = 0
    label.textAlignment = .center
    panel.addArrangedSubview(label)
    for (title,action) in [("Erneut fahren",#selector(replay)),("Weiterfahren",#selector(leave))] {
      let b = UIButton(type:.system)
      b.setTitle(title,for:.normal)
      b.tintColor = .white
      b.addTarget(self,action:action,for:.touchUpInside)
      buttons.addArrangedSubview(b)
    }
    panel.addArrangedSubview(buttons)
    root.addSubview(panel)
    panel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([panel.topAnchor.constraint(equalTo:root.safeAreaLayoutGuide.topAnchor,constant:4),
      panel.centerXAnchor.constraint(equalTo:root.centerXAnchor),panel.widthAnchor.constraint(greaterThanOrEqualToConstant:195)])
    panel.isHidden = true
  }
  func pause() { previousTime = nil; previous = nil; previousPhysicsClock = nil }
  func reset() {
    removals += cars.map { $0.id }
    anchor?.removeFromParent()
    ring = nil; anchor = nil; course = nil; lamps.removeAll(); generation = UUID()
    cars.removeAll(); commands.removeAll(); previous = nil; previousTime = nil
    nextPlan = 0; phase = .waiting; panel.isHidden = true; dismissed = nil
  }
  func drainRemoved() -> [UUID] { defer { removals.removeAll() }; return removals }
  func apply(_ poses: [String:DBJoltTransform]) {
    guard let track = course else { return }
    let preceding = previousPhysicsClock ?? clock
    previousPhysicsClock = clock
    for (i,rival) in cars.enumerated() {
      guard let pose = poses[rival.id.uuidString] else { continue }
      let old = rival.position
      let next = Point(pose.positionX,pose.positionY,pose.positionZ)
      rival.pose.position = next
      rival.pose.orientation = simd_quatf(ix:pose.rotationX,iy:pose.rotationY,iz:pose.rotationZ,r:pose.rotationW)
      rival.speed = pose.speed
      guard phase == .running || phase == .results else { continue }
      var lastFraction: Float = -1
      while finish[i+1] == nil {
        let fraction = track.crossingFraction(progress[i+1],from:old,to:next)
        guard fraction >= 0, fraction > lastFraction else { break }
        lastFraction = fraction
        rival.nextRoute = 0; rival.route.removeAll()
        progress[i+1] += 1
        if progress[i+1] == track.gates.count {
          finish[i+1] = preceding+Double(fraction)*(clock-preceding); commands[i].throttle = 0; commands[i].brake = 1
        }
      }
    }
  }
  @objc private func leave() { let p = course?.start; reset(); dismissed = p }
  @objc private func replay() { if let course { stage(course) } }
  private func box(_ size: Point,_ color: UIColor,_ p: Point,_ parent: Entity) -> ModelEntity {
    let e = ModelEntity(mesh:.generateBox(size:size),materials:[UnlitMaterial(color:color)])
    e.position = p; parent.addChild(e); return e
  }
  private func stage(_ track: RallyCourse) {
    guard let anchor else { return }
    for child in Array(anchor.children) { child.removeFromParent() }
    removals += cars.map { $0.id }; cars.removeAll(); commands.removeAll()
    generation = UUID(); distances.removeAll(); finalRank = nil; nextRanking = 0; flashUntil = 0
    stuck = Array(repeating:0,count:4); reverseUntil = stuck
    progress = Array(repeating:0,count:5); finish = Array(repeating:nil,count:5)
    phase = .waiting; previous = nil; clock = 0; nextHUD = 0
    ring = nil; buttons.isHidden = true; panel.isHidden = true
    let n = track.normals[0], heading = atan2(n.x,n.z)
    let grid = Entity()
    grid.position = track.start
    grid.orientation = simd_quatf(angle:heading,axis:[0,1,0])
    anchor.addChild(grid)
    _ = box([0.23,0.0006,0.006],.white,[0,0.001,0.027],grid)
    _ = box([0.034,0.0005,0.05],.systemTeal,[0,0.001,0],grid)
    let housing = box([0.018,0.037,0.012],.darkGray,[0.11,0.052,0.025],grid)
    lamps = [0.011,0,-0.011].enumerated().map { index, y in
      let light = ModelEntity(mesh:.generateSphere(radius:0.005),materials:[UnlitMaterial(color:index == 0 ? .red : .black)])
      light.position = [0,Float(y),0.006]; housing.addChild(light); return light
    }
    _ = box([0.003,0.044,0.003],.darkGray,[0.11,0.022,0.025],grid)
    for (i,lane) in [-2,-1,1,2].enumerated() {
      let model = StreetModel.allCases[i%3], visual = RallyVehicleVisual.street(model,cache:&cache)
      let pose = Entity()
      anchor.addChild(pose); pose.addChild(visual.root)
      pose.position = track.gridPosition(lane)+[0,0.009,0]
      let car = StreetCar(pose:pose,visual:visual,model:model,profile:model.rawValue,floorY:track.start.y)
      pose.orientation = simd_quatf(angle:heading,axis:[0,1,0])
      cars.append(car)
      commands.append(RaceDriverInput(id:car.id,spawn:[pose.position.x,track.start.y,pose.position.z],heading:heading,profile:model.rawValue))
    }
  }
  func reserves(_ point: SIMD3<Float>) -> Bool {
    guard let course else { return false }
    if hypot(point.x-course.start.x,point.z-course.start.z)<0.23 { return true }
    for (a,b) in zip([course.start]+course.gates,course.gates) {
      let line = b-a
      let t = max(0,min(1,simd_dot(point-a,line)/simd_length_squared(line)))
      if simd_distance(point,a+t*line)<0.15 { return true }
    }
    return false
  }
  private func showRing(_ track: RallyCourse) {
    ring?.removeFromParent()
    guard let anchor else { return }
    let i = progress[0], final = i == track.gates.count-1
    let radius: Float = final ? 0.11 : 0.085
    let e = Entity()
    anchor.addChild(e); e.position = track.gates[i]+[0,radius,0]
    e.orientation = simd_quatf(angle:atan2(track.normals[i].x,track.normals[i].z),axis:[0,1,0])
    if let template = ringTemplates[final] {
      e.addChild(template.clone(recursive:true))
    } else {
      let template = Entity()
      let color: UIColor = final ? .systemYellow : .systemPink
      var neon = PhysicallyBasedMaterial()
      neon.baseColor = .init(tint:color)
      neon.emissiveColor = .init(color:color)
      neon.emissiveIntensity = 2
      func tube(_ thickness: Float,_ checker: Int? = nil) -> MeshResource? {
        var positions: [Point] = [], normals: [Point] = [], indices: [UInt32] = []
        for arc in 0...64 {
          let a = Float(arc)*2 * .pi/64
          let radial = Point(sin(a),cos(a),0)
          for side in 0...8 {
            let b = Float(side)*2 * .pi/8
            let normal = radial*cos(b)+Point(0,0,sin(b))
            positions.append(radial*radius+normal*thickness)
            normals.append(normal)
            if arc < 64, side < 8, checker == nil || (arc/2+side/2)%2 == checker {
              let i = UInt32(arc*9+side)
              indices += [i,i+1,i+9,i+1,i+10,i+9]
            }
          }
        }
        var mesh = MeshDescriptor(name:"Checkpoint")
        mesh.positions = MeshBuffers.Positions(positions)
        mesh.normals = MeshBuffers.Normals(normals)
        mesh.primitives = .triangles(indices)
        return try? MeshResource.generate(from:[mesh])
      }
      if let body = tube(0.0038) { template.addChild(ModelEntity(mesh:body,materials:[neon])) }
      if final {
        for i in 0...1 {
          if let checks = tube(0.0039,i) {
            template.addChild(ModelEntity(mesh:checks,materials:[UnlitMaterial(color:i == 0 ? .black : .white)]))
          }
        }
        let title = ModelEntity(mesh:.generateText("FINISH",extrusionDepth:0.025,font:.boldSystemFont(ofSize:1)),materials:[neon])
        let bounds = title.visualBounds(relativeTo:title)
        let scale = 0.09/max(bounds.extents.x,0.001)
        title.scale = Point(repeating:scale)
        title.position = [-bounds.center.x*scale,radius+0.008,0]; template.addChild(title)
      }
      if let halo = tube(0.007) {
        template.addChild(ModelEntity(mesh:halo,materials:[UnlitMaterial(color:color.withAlphaComponent(0.16))]))
      }
      ringTemplates[final] = template
      e.addChild(template.clone(recursive:true))
    }
    ring = e
  }
  private func updateDistances(positions: [Point],track: RallyCourse,district: RallyDistrict) {
    guard !rankingPending, clock >= nextRanking else { return }
    rankingPending = true
    nextRanking = clock+0.5
    let map = district.map, boxes = district.buildings, token = generation, indices = progress
    planner.async { [weak self] in
      let result: [(gate:Int,remaining:Float)] = positions.enumerated().map { i,position in
        let index = indices[i]
        guard index < track.gates.count else { return (index,0) }
        let goal = track.gates[index], start = Point(position.x,goal.y,position.z)
        func clear(_ p: Point) -> Bool {
          !boxes.contains { p.x > $0.min.x-0.016 && p.x < $0.max.x+0.016 &&
                            p.z > $0.min.z-0.016 && p.z < $0.max.z+0.016 }
        }
        if RallyFloorMap.validStrip([start,goal],clear:{ map.covers($0,radius:0.02) && clear($0) }) {
          return (index,simd_distance(start,goal))
        }
        guard let path = map.road(from:start,to:goal,radius:0.02,clear:clear) else { return (index,.infinity) }
        return (index,zip(path,path.dropFirst()).reduce(Float.zero) { $0+simd_distance($1.0,$1.1) })
      }
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.rankingPending = false
        if self.generation == token { self.distances = result }
      }
    }
  }
  func tick(view: ARView,district: RallyDistrict,car: SIMD3<Float>,speed: Float,time: Double) {
    let delta = max(0,time-(previousTime ?? time)); previousTime = time
    guard let track = course else {
      guard time >= nextPlan else { return }
      nextPlan = time+2
      if let dismissed, simd_distance(dismissed,car)<0.8 { return }
      guard !planning else { return }
      planning = true
      let map = district.map, boxes = district.buildings, token = generation
      planner.async { [weak self] in
        let plan = RallyCourse.plan(near:car,map:map) { p in
          !boxes.contains { p.x > $0.min.x-0.022 && p.x < $0.max.x+0.022 &&
                            p.z > $0.min.z-0.022 && p.z < $0.max.z+0.022 }
        }
        DispatchQueue.main.async { [weak self, weak view, weak district] in
          guard let self else { return }
          self.planning = false
          guard self.generation == token, let plan, let view, let district,
            district.map.covers(plan.start,radius:0.13),
            (-2...2).allSatisfy({ district.permits(plan.gridPosition($0)) }),
            ([plan.start]+plan.gates).allSatisfy({ district.permits($0) && district.map.covers($0,radius:0.048) }) else { return }
          let root = AnchorEntity(world:SIMD3<Float>.zero)
          view.scene.addAnchor(root); self.anchor = root; self.course = plan; self.stage(plan)
        }
      }
      return
    }
    if phase == .waiting {
      if simd_distance(car,track.start)>1.8 { reset(); nextPlan = time+2; return }
      guard hypot(car.x-track.start.x,car.z-track.start.z)<0.021, speed<=0.01 else { return }
      clock = 0; lastCount = 0; phase = .countdown; panel.isHidden = false
    } else { clock += delta }
    if phase == .countdown {
      let count = max(0,3-Int(clock))
      if count != lastCount {
        AudioServicesPlaySystemSound(count == 0 ? 1057 : 1104)
        label.text = count == 0 ? "GO!" : String(count)
        let active = count == 0 ? 2 : count == 3 ? 0 : 1
        let colors: [UIColor] = [.red,.yellow,.green]
        for (i,light) in lamps.enumerated() { light.model?.materials = [UnlitMaterial(color:i == active ? colors[i] : .black)] }
        lastCount = count
      }
      guard count == 0 else { return }
      phase = .running; clock = 0; previousPhysicsClock = 0; previous = car; nextHUD = 0.5; showRing(track)
    }
    for (i,rival) in cars.enumerated() where finish[i+1] == nil {
      let idx = progress[i+1], n = track.normals[idx]
      let side = Point(n.z,0,-n.x)*((Float(i)-1.5)*0.009)
      var goal = track.gates[idx]+n*0.015+side
      goal.y = rival.position.y
      let neighbors = [car]+cars.filter { $0 !== rival }.map { $0.position }+district.fleet.cars.map { $0.position }
      if time >= rival.nextRoute {
        rival.route = StreetRoute.plan(from:rival.position,to:goal,clearance:rival.half.x+0.003,
          buildings:district.buildings,obstacles:neighbors)
        rival.nextRoute = time+0.55+Double(i)*0.07
      }
      while let first = rival.route.first, simd_distance(first,rival.position)<0.012 { rival.route.removeFirst() }
      let waypoint = rival.route.first ?? goal
      let offset = waypoint-rival.position, length = simd_length(offset)
      guard length > 0.00001 else { continue }
      let direction = offset/length
      let yaw = atan2(direction.x,direction.z)
      let ahead = rival.position+direction*min(length,0.035)
      if time >= rival.nextProbe {
        rival.clear = district.map.covers([ahead.x,track.start.y,ahead.z],radius:0.018) && district.permits(ahead)
        if rival.clear && simd_distance(view.cameraTransform.translation,ahead)<2.6 {
          rival.clear = district.fleet.navigable(view:view,car:rival,look:ahead,heading:yaw)
        }
        rival.nextProbe = time+0.14
      }
      let blocked = !rival.clear || neighbors.contains {
        let d = $0-rival.position
        return simd_dot(d,direction)>0 && simd_distance($0,ahead)<rival.half.x+0.012
      }
      // Right input steers around Jolt's negative Y axis.
      let error = atan2(sin(yaw-rival.yaw),cos(yaw-rival.yaw))
      let desired = min(0.21+Float(i)*0.025,abs(error)>0.6 ? 0.075 : Float.infinity)
      commands[i].steer = max(-1,min(1,-error/0.55))
      commands[i].throttle = blocked ? 0 : max(0,min(0.6,(desired-rival.speed)*3))
      commands[i].brake = blocked ? 1 : max(0,min(1,(rival.speed-desired)*5))
      if rival.speed < 0.012 { stuck[i] += min(delta,0.1) } else { stuck[i] = 0 }
      if stuck[i] > 1.5 {
        let back = rival.position-Point(sin(rival.yaw),0,cos(rival.yaw))*0.038
        if district.map.covers([back.x,track.start.y,back.z],radius:rival.half.z), district.permits(back),
          !neighbors.contains(where:{ simd_distance($0,back)<0.032 }) { reverseUntil[i] = clock+0.55 }
        stuck[i] = 0; rival.nextRoute = 0
      }
      if clock < reverseUntil[i] {
        commands[i].throttle = -0.25; commands[i].brake = 0; commands[i].steer *= -1
      }
    }
    if phase == .running {
      var lastFraction: Float = -1
      while let previous, phase == .running {
        let fraction = track.crossingFraction(progress[0],from:previous,to:car)
        guard fraction >= 0, fraction > lastFraction else { break }
        lastFraction = fraction
        AudioServicesPlaySystemSound(1057)
        flashUntil = clock+0.24
        progress[0] += 1
        if progress[0] == track.gates.count {
          let crossingTime = max(0,clock-delta*(1-Double(fraction)))
          finish[0] = crossingTime; phase = .results; buttons.isHidden = false
          ring?.removeFromParent(); ring = nil
          let key = "rally.best."+track.key, best = UserDefaults.standard.double(forKey:key)
          UserDefaults.standard.set(best == 0 ? crossingTime : min(best,crossingTime),forKey:key)
        } else { showRing(track) }
      }
      previous = car
      ring?.scale = SIMD3(repeating:1+0.015*sin(Float(clock)*5))
    }
    guard clock >= nextHUD else { return }
    nextHUD = clock+0.1
    let positions = [car]+cars.map { $0.position }
    if phase == .running { updateDistances(positions:positions,track:track,district:district) }
    let rank = 1+(1...4).filter { i in
      if let t = finish[i] { return t < (finish[0] ?? .infinity) }
      if progress[i] != progress[0] { return progress[i] > progress[0] }
      guard progress[0]<track.gates.count else { return false }
      let p = track.gates[progress[0]]
      if distances.count == 5, distances[i].gate == progress[i], distances[0].gate == progress[0] {
        return distances[i].remaining < distances[0].remaining
      }
      return simd_distance(p,positions[i]) < simd_distance(p,car)
    }.count
    if phase == .results, finalRank == nil {
      finalRank = rank
      UserDefaults.standard.set(rank,forKey:"rally.lastRank."+track.key)
    }
    label.textColor = clock < flashUntil ? .systemGreen : .white
    label.text = String(format:"%d / 5    %02d:%05.2f    %d / %d",finalRank ?? rank,Int(finish[0] ?? clock)/60,(finish[0] ?? clock).truncatingRemainder(dividingBy:60),progress[0],track.gates.count)
    if phase == .results {
      label.text! += String(format:"\nBestzeit %.2f s",UserDefaults.standard.double(forKey:"rally.best."+track.key))
      for i in 1...4 { label.text! += "\nNPC \(i)  "+(finish[i].map { String(format:"%.2f s",$0) } ?? "unterwegs") }
    }
  }
}
