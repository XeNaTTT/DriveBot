import Foundation
import simd

struct RallyCell: Hashable {
  let x, z: Int
  static let width: Float = 0.08
  init(_ x: Int, _ z: Int) { self.x = x; self.z = z }
  init(_ p: SIMD3<Float>) {
    x = Int(floor(p.x / Self.width))
    z = Int(floor(p.z / Self.width))
  }
  func point(_ y: Float) -> SIMD3<Float> {
    [(Float(x)+0.5)*Self.width,y,(Float(z)+0.5)*Self.width]
  }
  func offset(_ dx: Int,_ dz: Int) -> Self { Self(x+dx,z+dz) }
  var seed: UInt32 { UInt32(truncatingIfNeeded: x &* 73856093 ^ z &* 19349663) }
}

struct RallyFloorMap {
  private struct Sample { var y: Float; var hits: Int; var time: Double }
  private var samples: [RallyCell: Sample] = [:]
  var observedCount: Int { samples.count }
  var stableCount: Int { samples.values.filter { $0.hits >= 2 }.count }
  mutating func observe(_ cell: RallyCell, floor: Float?, time: Double) {
    guard let y = floor, y.isFinite else { samples[cell] = nil; return }
    if var old = samples[cell], abs(old.y-y) < 0.004 {
      guard time-old.time >= 0.25 else { return }
      old.hits = min(2,old.hits+1)
      old.time = time
      samples[cell] = old
    } else if samples[cell] != nil || samples.count < 16384 {
      samples[cell] = Sample(y:y,hits:1,time:time)
    }
  }
  func floor(_ cell: RallyCell) -> Float? {
    guard let sample = samples[cell], sample.hits >= 2 else { return nil }
    return sample.y
  }
  func covers(_ p: SIMD3<Float>, radius: Float) -> Bool {
    guard radius.isFinite, radius >= 0, radius < 2,
          [p.x,p.y,p.z].allSatisfy({ $0.isFinite && abs($0)<1000 }) else { return false }
    let lo = RallyCell(p - [radius,0,radius]), hi = RallyCell(p + [radius,0,radius])
    for z in lo.z...hi.z {
      for x in lo.x...hi.x {
        guard let y = floor(RallyCell(x,z)), abs(y-p.y) < 0.004 else { return false }
      }
    }
    return true
  }

  // Find a full-width corridor first, then round its turns and revalidate the swept strip.
  func road(from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float = 0.047, clear: (SIMD3<Float>) -> Bool) -> [SIMD3<Float>]? {
    let first = RallyCell(start), last = RallyCell(end)
    func valid(_ p: SIMD3<Float>) -> Bool { covers(p,radius: radius) && clear(p) }
    guard valid(start),valid(end),first != last else { return nil }
    var parent = [first:first], queue = [first], head = 0
    while head < queue.count && parent[last] == nil && head < 4096 {
      let c = queue[head]
      head += 1
      let neighbors = [c.offset(1,0),c.offset(-1,0),c.offset(0,1),c.offset(0,-1)].sorted {
        abs($0.x-last.x)+abs($0.z-last.z) < abs($1.x-last.x)+abs($1.z-last.z)
      }
      for n in neighbors where parent[n] == nil {
        guard let y = floor(n),abs(y-start.y)<0.004,valid(n.point(y)) else { continue }
        parent[n] = c
        queue.append(n)
      }
    }
    guard parent[last] != nil else { return nil }
    var reverse = [end], cursor = last
    while let previous = parent[cursor], previous != cursor {
      if previous != first { reverse.append(previous.point(start.y)) }
      cursor = previous
    }
    let points = [start] + Array(reverse.reversed())
    // Simplify straight runs before rounding with quadratic Bezier segments.
    var corners = [start]
    for i in 1..<(points.count-1) {
      let a = points[i]-points[i-1], b = points[i+1]-points[i]
      if abs(a.x*b.z-a.z*b.x) > 0.00001 { corners.append(points[i]) }
    }
    corners.append(end)
    var curve = [start]
    for i in 1..<(corners.count-1) {
      let p = corners[i], before = corners[i-1]-p, after = corners[i+1]-p
      let r = min(0.14,min(simd_length(before),simd_length(after))*0.45)
      let a = p+simd_normalize(before)*r, b = p+simd_normalize(after)*r
      for k in 0...8 {
        let t = Float(k)/8
        curve.append(a*(1-t)*(1-t)+p*(2*t*(1-t))+b*t*t)
      }
    }
    curve.append(end)
    if corners.count == 2 {
      let span = end-start
      let side = simd_normalize(SIMD3(span.z,0,-span.x))
      let bend = (start+end)/2 + side*min(0.14,simd_length(span)*0.18)
      let steps = max(4,Int(ceil(simd_length(span)/0.035)))
      let arc = (0...steps).map { i -> SIMD3<Float> in
        let t = Float(i)/Float(steps)
        return start*(1-t)*(1-t)+bend*(2*t*(1-t))+end*t*t
      }
      if arc.allSatisfy(valid) { curve = arc }
    }
    return Self.validStrip(curve,clear:valid) ? curve : nil
  }

  static func validStrip(_ points: [SIMD3<Float>], clear: (SIMD3<Float>)->Bool) -> Bool {
    guard points.count >= 2, let last = points.last, clear(last) else { return false }
    for (a,b) in zip(points,points.dropFirst()) {
      let steps = max(1,Int(ceil(simd_distance(a,b)/0.012)))
      for i in 0...steps where !clear(a+(b-a)*(Float(i)/Float(steps))) { return false }
    }
    return true
  }
}

struct RallyNeighborhood {
  let cell: RallyCell
  let center: SIMD3<Float>
  let kind: Int
  let lots: [SIMD3<Float>]
  let angles: [Float]
  static let names = ["Ocean District","Downtown","Palm Heights","Motor District","Shopping District","Entertainment District"]
  init(cell: RallyCell, floor: Float, ordinal: Int, compact: Bool = false) {
    self.cell = cell
    center = cell.point(floor)
    kind = ordinal < 3 ? ordinal : 3 + Int(cell.seed % 3)
    let base = Float(cell.seed % 628)/100
    let n = ordinal == 1 ? 3 : 2
    var positions: [SIMD3<Float>] = [], headings: [Float] = []
    for i in 0..<n {
      let a = base + Float(i)*2 * .pi/Float(n) + Float((cell.seed >> (i*4)) % 9)*0.025
      let r: Float = compact && i == 0 ? 0.094 : 0.19 + Float((cell.seed >> (i*3)) % 5)*0.012
      positions.append(cell.point(floor) + SIMD3(sin(a)*r,0,cos(a)*r))
      headings.append(a + .pi)
    }
    lots = positions
    angles = headings
  }
}

struct RallyRoadNetwork {
  private(set) var links: [Int:[Int:[SIMD3<Float>]]] = [:]
  mutating func connect(_ a: Int,_ b: Int,points: [SIMD3<Float>]) {
    links[a,default: [:]][b] = points
    links[b,default: [:]][a] = Array(points.reversed())
  }
  func path(_ from: Int,_ to: Int) -> [SIMD3<Float>]? {
    if from == to { return [] }
    var parents = [from:from], queue = [from], head = 0
    while head < queue.count && parents[to] == nil {
      let n = queue[head]
      head += 1
      for next in (links[n] ?? [:]).keys.sorted() where parents[next] == nil {
        parents[next] = n
        queue.append(next)
      }
    }
    guard parents[to] != nil else { return nil }
    var sections: [[SIMD3<Float>]] = [], current = to
    while let prev = parents[current], prev != current {
      guard let section = links[prev]?[current] else { return nil }
      sections.append(section)
      current = prev
    }
    return sections.reversed().flatMap { $0 }
  }
}
