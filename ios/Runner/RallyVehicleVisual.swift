import RealityKit
import UIKit
import simd

/// Convert metres to model units for the offset only. The basis remains rigid
/// so the parent scale still controls the rendered tyre size.
func rallyWheelModelTransform(chassisLocal: simd_float4x4, visualScale: Float) -> simd_float4x4 {
  var transform = chassisLocal
  transform.columns.3 = SIMD4(
    chassisLocal.columns.3.x / visualScale,
    chassisLocal.columns.3.y / visualScale,
    chassisLocal.columns.3.z / visualScale, 1)
  return transform
}

/// Model-space dimensions are normalized together by the race view.
@MainActor
struct RallyVehicleVisual {
  let root: Entity
  let wheels: [Entity]

  static func build(profile: String) -> Self {
    let root = Entity()
    let van = profile == "compact"
    let expedition = profile == "offroad"
    var paint = PhysicallyBasedMaterial()
    paint.baseColor = .init(tint: color(van ? 0x188F90 : expedition ? 0x455440 : 0xE3DCCC))
    paint.metallic = 0.38
    paint.roughness = 0.29
    paint.clearcoat = 0.7
    paint.clearcoatRoughness = 0.18
    let trim = finish(0x23272A, roughness: 0.76)
    let glass = finish(0x20313B, roughness: 0.15, metallic: true)
    let accent = finish(van ? 0xCDB893 : expedition ? 0xB49A5C : 0xA3543F, roughness: 0.43)
    let metal = finish(0xA5A9AB, roughness: 0.35, metallic: true)
    let headlamp = finish(0xF1F0DC, roughness: 0.22, metallic: true)
    let tailLamp = finish(0xAA2427, roughness: 0.25)

    func part(_ name: String, _ size: SIMD3<Float>, _ position: SIMD3<Float>,
              _ material: RealityKit.Material, bevel: Float = 0.008, pitch: Float = 0) {
      let model = ModelEntity(mesh: .generateBox(size: size, cornerRadius: bevel),
                              materials: [material])
      model.name = name
      model.position = position
      model.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
      root.addChild(model)
    }

    // Keep the sill above the wheel contact patch and +Z toward the front axle.
    part("lower body", [0.42, 0.12, 0.96], [0, 0.01, 0], paint, bevel: 0.035)
    part("front bumper", [0.43, 0.055, 0.038], [0, -0.016, 0.481], trim)
    part("rear bumper", [0.43, 0.055, 0.038], [0, -0.016, -0.481], trim)
    part("hood", [0.405, 0.065, 0.175], [0, 0.081, 0.378], paint, bevel: 0.022)
    part("cab", [0.408, 0.21, 0.29], [0, 0.15, 0.195], paint, bevel: 0.032)
    part("windscreen", [0.342, 0.127, 0.02], [0, 0.173, 0.341], glass, pitch: -0.17)
    part("grille", [0.23, 0.044, 0.015], [0, 0.037, 0.484], trim)
    part("grille insert", [0.175, 0.009, 0.008], [0, 0.04, 0.493], metal, bevel: 0.002)

    let cabinWidth: Float = van ? 0.41 : 0.465
    let cabinHeight: Float = van ? 0.223 : expedition ? 0.28 : 0.31
    part("camper shell", [cabinWidth, cabinHeight, 0.565],
         [0, 0.056 + cabinHeight / 2, -0.185], paint, bevel: van ? 0.045 : 0.025)
    if !van && !expedition {
      part("overcab berth", [0.455, 0.115, 0.42], [0, 0.301, 0.157], paint, bevel: 0.04)
      part("berth window", [0.238, 0.04, 0.01], [0, 0.307, 0.365], glass)
    }
    part("rear window", [0.22, 0.09, 0.012], [0, 0.212, -0.47], glass)
    part("roof fixture", [0.22, 0.023, 0.19], [0, cabinHeight + 0.064, -0.27], trim)
    for side in [Float(-1), 1] {
      let flank = side * (cabinWidth / 2)
      part("cab side glass", [0.012, 0.104, 0.166], [side * 0.202, 0.172, 0.22], glass)
      part("mirror", [0.049, 0.038, 0.045], [side * 0.224, 0.152, 0.32], trim)
      part("camper window", [0.014, 0.093, van ? 0.27 : 0.219],
           [flank, 0.207, -0.229], glass, bevel: 0.005)
      part("accent panel", [0.01, 0.028, 0.49], [flank, 0.128, -0.177], accent, bevel: 0.003)
      part("door handle", [0.013, 0.011, 0.044], [flank, 0.164, 0.021], metal, bevel: 0.003)
      part("headlight", [0.071, 0.037, 0.014], [side * 0.165, 0.046, 0.484], headlamp)
      part("taillight", [0.043, 0.068, 0.014], [side * 0.175, 0.084, -0.474], tailLamp)
      if expedition {
        part("roof floodlight", [0.056, 0.035, 0.025], [side * 0.14, 0.39, 0.068], headlamp)
        part("roof rack rail", [0.021, 0.022, 0.47], [side * 0.178, 0.386, -0.172], trim)
        part("rock slider", [0.026, 0.026, 0.37], [side * 0.213, -0.018, 0], trim)
      }
    }
    if expedition {
      for z in [Float(-0.35), -0.19, -0.03] {
        part("roof rack crossbar", [0.365, 0.017, 0.024], [0, 0.379, z], metal, bevel: 0.003)
      }
      part("expedition case", [0.21, 0.061, 0.174], [0.032, 0.42, -0.224], accent)
      part("bumper guard", [0.31, 0.03, 0.012], [0, 0.008, 0.493], metal, bevel: 0.003)
    }

    if let url = Bundle.main.url(forResource: profile, withExtension: "usdz", subdirectory: "RallyAssets"),
       let body = try? Entity.load(contentsOf: url) {
      for name in ["lower body", "hood", "cab", "camper shell"] {
        root.findEntity(named: name)?.removeFromParent()
      }
      body.name = "camper shell"
      root.addChild(body)
    }
    let wheel = makeWheel(width: expedition ? 0.127 : 0.086, offroad: expedition)
    // Match Jolt's axle centres and tyre radius at the nominal 1.0 model length.
    let positions: [SIMD3<Float>] = [
      [0.23, -0.13, 0.33], [-0.23, -0.13, 0.33],
      [0.23, -0.13, -0.33], [-0.23, -0.13, -0.33],
    ]
    let wheels = positions.enumerated().map { index, position in
      let pivot = wheel.clone(recursive: true)
      pivot.name = ["front right", "front left", "rear right", "rear left"][index]
      pivot.position = position
      // Jolt outputs wheel matrices for a model with the axle along local Y.
      pivot.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
      root.addChild(pivot)
      return pivot
    }
    return Self(root: root, wheels: wheels)
  }

  static func street(_ model: StreetModel, cache: inout [StreetModel: Entity]) -> Self {
    let wheelNames = ["front right","front left","rear right","rear left"]
    if cache[model] == nil {
      let shell = Entity()
      let paint = finish(model == .pickup ? 0x48998D : model == .sedan ? 0x87CED2 : 0xF1BE3B, roughness: 0.27, metallic: true)
      let trim = finish(0x29333A, roughness: 0.45)
      let chrome = finish(0xD5D9CD, roughness: 0.17, metallic: true)
      func part(_ size: SIMD3<Float>, _ p: SIMD3<Float>, _ mat: RealityKit.Material, _ radius: Float = 0.012) {
        let unit = ModelEntity(mesh: .generateBox(size: size, cornerRadius: radius), materials: [mat])
        unit.position = p
        shell.addChild(unit)
      }
      part([0.46,0.13,1],[0,0,0],paint,0.055)
      part([0.42,0.045,0.34],[0,0.068,0.30],paint)
      part([0.44,0.032,0.034],[0,-0.017,0.492],chrome)
      for side: Float in [-1,1] {
        part([0.1,0.041,0.016],[side*0.155,0.035,0.492],chrome)
        part([0.035,0.14,0.025],[side*0.189,0.13,0.16],chrome)
        part([0.075,0.036,0.018],[side*0.16,0.028,-0.495],finish(0xD23540,roughness: 0.22))
        part([0.018,0.006,0.86],[side*0.23,0.018,0],chrome,0.002)
      }
      var glass = SimpleMaterial(color: UIColor.systemTeal.withAlphaComponent(0.27), isMetallic: false)
      glass.roughness = 0.12
      part([0.36,0.12,0.012],[0,0.135,0.16],glass,0.004)
      if model != .convertible {
        part([0.40,0.03,model == .pickup ? 0.27 : 0.45],[0,0.225,-0.02],paint)
        part([0.37,0.14,0.025],[0,0.14,model == .pickup ? -0.15 : -0.24],trim)
      }
      if model == .pickup {
        part([0.375,0.012,0.25],[0,0.068,-0.325],trim)
        for side: Float in [-1,1] { part([0.036,0.08,0.3],[side*0.20,0.08,-0.33],paint) }
      }
      let driver = Entity()
      driver.name = "driver"
      driver.position = [-0.09,0.067,0.015]
      let torso = ModelEntity(mesh: .generateBox(size: [0.095,0.085,0.063],cornerRadius: 0.023),materials: [trim])
      torso.position.y = 0.035
      let head = ModelEntity(mesh: .generateSphere(radius: 0.034),materials: [finish(0xB98464,roughness: 0.8)])
      head.position.y = 0.108
      driver.addChild(torso)
      driver.addChild(head)
      shell.addChild(driver)
      let tyre = makeWheel(width: 0.086, offroad: model == .pickup)
      for (i,name) in wheelNames.enumerated() {
        let wheel = tyre.clone(recursive: true)
        wheel.name = name
        wheel.position = [i % 2 == 0 ? 0.23 : -0.23,-0.13,i < 2 ? 0.33 : -0.33]
        wheel.orientation = simd_quatf(angle: .pi/2,axis: [0,0,1])
        shell.addChild(wheel)
      }
      cache[model] = shell
    }
    let root = cache[model]!.clone(recursive: true)
    root.scale = SIMD3(repeating: model.length)
    return Self(root: root,wheels: wheelNames.compactMap { root.findEntity(named: $0) })
  }

  private static let treadTexture: TextureResource? = {
    guard let url = Bundle.main.url(forResource: "tread", withExtension: "png", subdirectory: "RallyAssets") else { return nil }
    return try? TextureResource.load(contentsOf: url)
  }()

  private static func makeWheel(width: Float, offroad: Bool) -> Entity {
    let wheel = Entity()
    func surface(_ rings: [SIMD2<Float>], material: SimpleMaterial,
                 tread: Bool = false) -> Bool {
      guard let mesh = wheelMesh(rings: rings, tread: tread) else { return false }
      wheel.addChild(ModelEntity(mesh: mesh, materials: [material]))
      return true
    }
    let edge = width / 2
    var rubber = finish(0x242526, roughness: 0.88)
    if let texture = treadTexture { rubber.color = .init(tint: .white, texture: .init(texture)) }
    let hasTyre = surface([[0.044, -edge], [0.074, -edge], [0.09, -edge * 0.72],
             [0.09, edge * 0.72], [0.074, edge], [0.044, edge]],
            material: rubber, tread: offroad)
    _ = surface([[0.001, -edge], [0.048, -edge], [0.048, edge], [0.001, edge]],
            material: finish(0x909A9E, roughness: 0.37, metallic: true))
    // Contrasting inserts give a visible rotation cue at miniature scale.
    var inserts: [SIMD3<Float>] = []
    var faces: [UInt32] = []
    for side in [Float(-1), 1] {
      for index in 0..<5 {
        let angle = Float(index) * 2 * .pi / 5
        let rotation = simd_quatf(angle: -angle, axis: [0, 1, 0])
        let start = UInt32(inserts.count)
        let y = side * (edge + 0.001)
        let quad: [SIMD3<Float>] = [[0.018, y, -0.005], [0.038, y, -0.005],
                                    [0.038, y, 0.005], [0.018, y, 0.005]]
        inserts.append(contentsOf: quad.map { rotation.act($0) })
        let winding: [UInt32] = side > 0 ? [0, 2, 1, 0, 3, 2] : [0, 1, 2, 0, 2, 3]
        faces.append(contentsOf: winding.map { start + $0 })
      }
    }
    if let mesh = makeMesh("hub inserts", positions: inserts, indices: faces) {
      wheel.addChild(ModelEntity(mesh: mesh, materials: [finish(0x22282B, roughness: 0.65)]))
    }
    if !hasTyre {
      let tyre = ModelEntity(mesh: .generateBox(size: [0.18, width, 0.18], cornerRadius: 0.03),
                             materials: [finish(0x242526, roughness: 0.88)])
      wheel.addChild(tyre)
    }
    return wheel
  }

  private static func wheelMesh(rings: [SIMD2<Float>], tread: Bool) -> MeshResource? {
    let segments = 24
    var positions: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var uv: [SIMD2<Float>] = []
    let stride = segments + 1
    for (row, ring) in rings.enumerated() {
      for index in 0...segments {
        uv.append([Float(index) / Float(segments), Float(row) / Float(rings.count - 1)])
        let angle = Float(index) * 2 * .pi / Float(segments)
        let radius = tread && ring.x == 0.09 && index.isMultiple(of: 2) ? ring.x - 0.007 : ring.x
        positions.append([radius * cos(angle), ring.y, radius * sin(angle)])
      }
    }
    for ring in 0..<(rings.count - 1) {
      for segment in 0..<segments {
        let a = UInt32(ring * stride + segment)
        let b = a + 1
        let c = a + UInt32(stride)
        let d = b + UInt32(stride)
        indices.append(contentsOf: [a, c, b, b, c, d])
      }
    }
    return makeMesh(tread ? "off-road tyre" : "wheel surface", positions: positions, indices: indices, uv: uv)
  }

  private static func makeMesh(_ name: String, positions: [SIMD3<Float>],
                               indices: [UInt32], uv: [SIMD2<Float>] = []) -> MeshResource? {
    var normals = Array(repeating: SIMD3<Float>.zero, count: positions.count)
    for i in stride(from: 0, to: indices.count, by: 3) {
      let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
      let normal = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
      normals[a] += normal
      normals[b] += normal
      normals[c] += normal
    }
    var descriptor = MeshDescriptor(name: name)
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(normals.map { simd_normalize($0) })
    if !uv.isEmpty { descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv) }
    descriptor.primitives = .triangles(indices)
    return try? MeshResource.generate(from: [descriptor])
  }

  private static func finish(_ rgb: UInt32, roughness: Float, metallic: Bool = false)
    -> SimpleMaterial
  {
    SimpleMaterial(color: color(rgb), roughness: .float(roughness), isMetallic: metallic)
  }

  private static func color(_ rgb: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((rgb >> 16) & 255) / 255,
      green: CGFloat((rgb >> 8) & 255) / 255,
      blue: CGFloat(rgb & 255) / 255, alpha: 1)
  }
}
