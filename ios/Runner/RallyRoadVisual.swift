import RealityKit
import UIKit

@MainActor
enum RallyRoadVisual {
  struct Strip {
    var vertices: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    mutating func quad(_ a: SIMD3<Float>,_ b: SIMD3<Float>,_ c: SIMD3<Float>,_ d: SIMD3<Float>) {
      let n = UInt32(vertices.count)
      vertices += [a,b,c,d]
      indices += [n,n+2,n+1,n+1,n+2,n+3]
    }
    func entity(name: String,color: UIColor) -> ModelEntity? {
      guard !indices.isEmpty else { return nil }
      var mesh = MeshDescriptor(name:name)
      mesh.positions = MeshBuffers.Positions(vertices)
      mesh.primitives = .triangles(indices)
      guard let resource = try? MeshResource.generate(from:[mesh]) else { return nil }
      return ModelEntity(mesh:resource,materials:[SimpleMaterial(color:color,isMetallic:false)])
    }
  }

  static func build(points: [SIMD3<Float>],width: Float,marked: Bool) -> AnchorEntity? {
    guard let start = points.first, points.count >= 2 else { return nil }
    var asphalt = Strip(), paint = Strip()
    var previousLeft = SIMD3<Float>.zero, previousRight = SIMD3<Float>.zero
    let length = zip(points,points.dropFirst()).reduce(Float.zero) { $0+simd_distance($1.0,$1.1) }
    var travelled: Float = 0
    for i in points.indices {
      let tangent = points[min(i+1,points.count-1)]-points[max(i-1,0)]
      let side = SIMD3(tangent.z,0,-tangent.x)/max(simd_length(tangent),0.00001)
      let p = points[i]-start+[0,0.00045,0]
      let along = travelled + (i > 0 ? simd_distance(points[i],points[i-1]) : 0)
      let ramp = min(1,max(0,min(along,length-along)/0.12))
      let localWidth = width > 0.09 ? 0.068+(width-0.068)*ramp : width
      let left = p-side*localWidth/2, right = p+side*localWidth/2
      if i > 0 {
        asphalt.quad(previousLeft,previousRight,left,right)
        let delta = points[i]-points[i-1], length = simd_length(delta)
        if marked && length > 0.00001 {
          let forward = delta/length
          let stripe = SIMD3(forward.z,0,-forward.x)*0.0008
          let base = points[i-1]-start+[0,0.00065,0]
          let period: Float = 0.045
          var meter = floor(travelled/period)*period
          while meter < travelled+length {
            let a = max(0,meter-travelled), b = min(length,meter+period*0.48-travelled)
            if b>a {
              paint.quad(base+forward*a-stripe,base+forward*a+stripe,base+forward*b-stripe,base+forward*b+stripe)
            }
            meter += period
          }
        }
        travelled += length
      }
      previousLeft = left
      previousRight = right
    }
    guard let surface = asphalt.entity(name:"Boulevard",color:.darkGray) else { return nil }
    let anchor = AnchorEntity(world:start)
    anchor.addChild(surface)
    if let markings = paint.entity(name:"Lane markings",color:.systemYellow) { anchor.addChild(markings) }
    return anchor
  }
}
