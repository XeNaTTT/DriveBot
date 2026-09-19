import ARKit
import DriveBotJolt
import Flutter
import GameController
import RealityKit
import UIKit

/// Entire simulation stays native: Flutter only creates/disposes this view.
/// ARKit/RealityKit use metres and Jolt receives the same world coordinates.
final class ArRacingView: NSObject, FlutterPlatformView, ARSessionDelegate {
  private enum Phase { case scanning, floorFound, placeCar, ready, interrupted }
  private let root = UIView()
  private let arView: ARView
  private let physics = DBJoltWorld()
  private let message = UILabel()
  private let speed = UILabel()
  private let resetButton = UIButton(type: .system)
  private let debugButton = UIButton(type: .system)
  private let steeringPad = UIView()
  private let steeringKnob = UIView()
  private let throttleButton = UIButton(type: .system)
  private let brakeButton = UIButton(type: .system)
  private var carAnchor: AnchorEntity?
  private var chassis: ModelEntity?
  private var wheels: [ModelEntity] = []
  private var phase: Phase = .scanning { didSet { updateMessage() } }
  private var displayLink: CADisplayLink?
  private var previousTime: CFTimeInterval = 0
  private var throttle: Float = 0, brake: Float = 0, steering: Float = 0
  private var meshWork: [UUID: DispatchWorkItem] = [:]
  private let meshQueue = DispatchQueue(label: "de.drivebot.mesh", qos: .utility)
  private var debugVisible = false
  private var debugEntities: [UUID: Entity] = [:]
  private var hasFloor = false
  private var hasSceneReconstruction = false

  init(frame: CGRect, viewIdentifier: Int64) {
    arView = ARView(frame: frame, cameraMode: .ar, automaticallyConfigureSession: false)
    super.init()
    root.backgroundColor = .black
    root.addSubview(arView)
    arView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      arView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      arView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      arView.topAnchor.constraint(equalTo: root.topAnchor),
      arView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])
    configureHUD()
    arView.session.delegate = self
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification,
      object: nil)
    requestCameraAndStart()
  }

  deinit {
    displayLink?.invalidate()
    NotificationCenter.default.removeObserver(self)
    arView.session.pause()
  }
  func view() -> UIView { root }

  private func requestCameraAndStart() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: startSession()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async { granted ? self?.startSession() : self?.showCameraDenied() }
      }
    default: showCameraDenied()
    }
  }

  private func showCameraDenied() {
    phase = .interrupted
    message.text = "Kamerazugriff in Einstellungen erlauben"
  }

  private func startSession() {
    guard ARWorldTrackingConfiguration.isSupported else {
      message.text = "AR World Tracking nicht unterstützt"
      return
    }
    let config = ARWorldTrackingConfiguration()
    config.worldAlignment = .gravity
    config.planeDetection = [.horizontal]
    config.environmentTexturing = .automatic
    if #available(iOS 13.4, *),
      ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    {
      config.sceneReconstruction = .meshWithClassification
      hasSceneReconstruction = true
      arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting]
    }
    arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    phase = .scanning
    startDisplayLink()
  }

  private func configureHUD() {
    func style(_ button: UIButton, title: String) {
      button.setTitle(title, for: .normal)
      button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
      button.tintColor = .white
      button.setTitleColor(.white, for: .normal)
      button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
      button.layer.cornerRadius = 22
      button.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(button)
    }
    message.font = .systemFont(ofSize: 14, weight: .semibold)
    message.textColor = .white
    message.textAlignment = .center
    message.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    message.layer.cornerRadius = 12
    message.clipsToBounds = true
    message.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(message)
    speed.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
    speed.textColor = .white
    speed.text = "0.0 m/s"
    speed.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    speed.textAlignment = .center
    speed.layer.cornerRadius = 14
    speed.clipsToBounds = true
    speed.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(speed)
    style(resetButton, title: "↻")
    style(debugButton, title: "⚙︎")
    style(throttleButton, title: "GAS")
    style(brakeButton, title: "BREMSE")
    resetButton.addTarget(self, action: #selector(resetCar), for: .touchUpInside)
    debugButton.addTarget(self, action: #selector(toggleDebug), for: .touchUpInside)
    throttleButton.addTarget(
      self, action: #selector(throttleDown), for: [.touchDown, .touchDragEnter])
    throttleButton.addTarget(
      self, action: #selector(throttleUp),
      for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    brakeButton.addTarget(self, action: #selector(brakeDown), for: [.touchDown, .touchDragEnter])
    brakeButton.addTarget(
      self, action: #selector(brakeUp),
      for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    steeringPad.backgroundColor = UIColor.black.withAlphaComponent(0.45)
    steeringPad.layer.cornerRadius = 44
    steeringPad.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(steeringPad)
    steeringKnob.backgroundColor = UIColor.white.withAlphaComponent(0.8)
    steeringKnob.layer.cornerRadius = 21
    steeringKnob.isUserInteractionEnabled = false
    steeringKnob.translatesAutoresizingMaskIntoConstraints = false
    steeringPad.addSubview(steeringKnob)
    steeringPad.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(steer(_:))))
    arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(place(_:))))
    let guide = root.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      message.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      message.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
      message.heightAnchor.constraint(equalToConstant: 34),
      message.widthAnchor.constraint(lessThanOrEqualToConstant: 330),
      debugButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      debugButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
      debugButton.widthAnchor.constraint(equalToConstant: 44),
      debugButton.heightAnchor.constraint(equalToConstant: 44),
      resetButton.centerYAnchor.constraint(equalTo: debugButton.centerYAnchor),
      resetButton.trailingAnchor.constraint(equalTo: debugButton.leadingAnchor, constant: -8),
      resetButton.widthAnchor.constraint(equalToConstant: 44),
      resetButton.heightAnchor.constraint(equalToConstant: 44),
      speed.centerYAnchor.constraint(equalTo: debugButton.centerYAnchor),
      speed.trailingAnchor.constraint(equalTo: resetButton.leadingAnchor, constant: -8),
      speed.widthAnchor.constraint(equalToConstant: 90),
      speed.heightAnchor.constraint(equalToConstant: 36),
      steeringPad.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
      steeringPad.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
      steeringPad.widthAnchor.constraint(equalToConstant: 120),
      steeringPad.heightAnchor.constraint(equalToConstant: 88),
      steeringKnob.centerXAnchor.constraint(equalTo: steeringPad.centerXAnchor),
      steeringKnob.centerYAnchor.constraint(equalTo: steeringPad.centerYAnchor),
      steeringKnob.widthAnchor.constraint(equalToConstant: 42),
      steeringKnob.heightAnchor.constraint(equalToConstant: 42),
      throttleButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
      throttleButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
      throttleButton.widthAnchor.constraint(equalToConstant: 92),
      throttleButton.heightAnchor.constraint(equalToConstant: 58),
      brakeButton.trailingAnchor.constraint(equalTo: throttleButton.leadingAnchor, constant: -12),
      brakeButton.centerYAnchor.constraint(equalTo: throttleButton.centerYAnchor),
      brakeButton.widthAnchor.constraint(equalToConstant: 92),
      brakeButton.heightAnchor.constraint(equalToConstant: 58),
    ])
    updateMessage()
  }

  private func updateMessage() {
    switch phase {
    case .scanning:
      message.text =
        hasSceneReconstruction
        ? "Umgebung erfassen …" : "Boden erfassen (Hindernisse nur mit LiDAR)"
    case .floorFound, .placeCar: message.text = "Auf bestätigten Boden tippen"
    case .ready: message.text = ""
    case .interrupted: message.text = "Tracking eingeschränkt – Fahrt pausiert"
    }
    message.isHidden = phase == .ready
  }

  @objc private func place(_ gesture: UITapGestureRecognizer) {
    guard hasFloor, phase != .interrupted else { return }
    let point = gesture.location(in: arView)
    guard
      let hit = arView.raycast(
        from: point, allowing: .existingPlaneGeometry, alignment: .horizontal
      ).first
    else { return }
    installCar(
      at: SIMD3(
        hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y,
        hit.worldTransform.columns.3.z))
  }

  private func installCar(at p: SIMD3<Float>) {
    carAnchor?.removeFromParent()
    wheels.removeAll()
    let anchor = AnchorEntity(world: p)
    let body = ModelEntity(
      mesh: .generateBox(size: [0.15, 0.05, 0.30], cornerRadius: 0.015),
      materials: [SimpleMaterial(color: .systemOrange, roughness: 0.35, isMetallic: true)])
    anchor.addChild(body)
    let positions: [SIMD3<Float>] = [
      SIMD3(0.075, -0.025, 0.105),
      SIMD3(-0.075, -0.025, 0.105),
      SIMD3(0.075, -0.025, -0.105),
      SIMD3(-0.075, -0.025, -0.105),
    ]
    for pos in positions {
      let wheel = ModelEntity(
        mesh: .generateCylinder(height: 0.018, radius: 0.025),
        materials: [SimpleMaterial(color: .darkGray, isMetallic: false)])
      wheel.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
      wheel.position = pos
      anchor.addChild(wheel)
      wheels.append(wheel)
    }
    arView.scene.addAnchor(anchor)
    carAnchor = anchor
    chassis = body
    physics.reset(at: p, heading: 0)
    physics.setPaused(false)
    phase = .ready
  }

  @objc private func resetCar() {
    releaseInputs()
    carAnchor?.removeFromParent()
    carAnchor = nil
    phase = hasFloor ? .placeCar : .scanning
  }
  @objc private func toggleDebug() {
    debugVisible.toggle()
    debugEntities.values.forEach { $0.isEnabled = debugVisible }
  }
  @objc private func throttleDown() {
    throttle = 1
    sendInput()
  }

  @objc private func throttleUp() {
    throttle = 0
    sendInput()
  }

  @objc private func brakeDown() {
    brake = 1
    sendInput()
  }

  @objc private func brakeUp() {
    brake = 0
    sendInput()
  }
  @objc private func steer(_ pan: UIPanGestureRecognizer) {
    let x = Float(pan.location(in: steeringPad).x / steeringPad.bounds.width * 2 - 1)
    steering = pan.state == .ended || pan.state == .cancelled ? 0 : min(1, max(-1, x))
    steeringKnob.transform = CGAffineTransform(translationX: CGFloat(steering) * 32, y: 0)
    sendInput()
  }
  private func sendInput() { physics.setThrottle(throttle, brake: brake, steering: steering) }
  private func releaseInputs() {
    throttle = 0
    brake = 0
    steering = 0
    steeringKnob.transform = .identity
    sendInput()
  }
  @objc private func interrupted() {
    releaseInputs()
    physics.setPaused(true)
    phase = .interrupted
  }

  private func startDisplayLink() {
    displayLink?.invalidate()
    let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }
  @objc private func frame(_ link: CADisplayLink) {
    guard phase == .ready, let anchor = carAnchor else {
      previousTime = link.timestamp
      return
    }
    let dt = previousTime == 0 ? 0 : link.timestamp - previousTime
    previousTime = link.timestamp
    let state = physics.step(dt)
    anchor.transform.matrix = state.chassisTransform
    speed.text = String(format: "%.1f m/s", state.speedMetersPerSecond)
    for (i, value) in state.wheelTransforms.enumerated() where i < wheels.count {
      var matrix = matrix_identity_float4x4
      value.getValue(&matrix)
      wheels[i].transformMatrix(relativeTo: nil) = matrix
    }
    if state.collided { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    DispatchQueue.main.async {
      switch camera.trackingState {
      case .normal:
        self.physics.setPaused(false)
        self.phase = self.carAnchor == nil ? (self.hasFloor ? .placeCar : .scanning) : .ready
      default: self.interrupted()
      }
    }
  }
  func sessionWasInterrupted(_ session: ARSession) { interrupted() }
  func sessionInterruptionEnded(_ session: ARSession) {
    releaseInputs()
    carAnchor?.removeFromParent()
    carAnchor = nil
    hasFloor = false
    startSession()
  }
  func session(_ session: ARSession, didFailWithError error: Error) {
    DispatchQueue.main.async {
      self.interrupted()
      self.message.text = "AR-Fehler: \(error.localizedDescription)"
    }
  }
  func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { process(anchors) }
  func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { process(anchors) }
  func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    for anchor in anchors {
      meshWork[anchor.identifier]?.cancel()
      meshWork.removeValue(forKey: anchor.identifier)
      DispatchQueue.main.async {
        self.physics.removeStaticMesh(anchor.identifier)
        self.debugEntities.removeValue(forKey: anchor.identifier)?.removeFromParent()
      }
    }
  }

  private func process(_ anchors: [ARAnchor]) {
    for anchor in anchors {
      if let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal, plane.extent.x > 0.3,
        plane.extent.z > 0.3
      {
        hasFloor = true
        DispatchQueue.main.async { if self.carAnchor == nil { self.phase = .placeCar } }
        installPlaneCollider(plane)
      }
      if #available(iOS 13.4, *), let mesh = anchor as? ARMeshAnchor { schedule(mesh) }
    }
  }
  private func installPlaneCollider(_ plane: ARPlaneAnchor) {
    let e = plane.extent
    let local: [SIMD4<Float>] = [
      [-e.x / 2, 0, -e.z / 2, 1], [e.x / 2, 0, -e.z / 2, 1], [e.x / 2, 0, e.z / 2, 1],
      [-e.x / 2, 0, e.z / 2, 1],
    ]
    let v = local.map { p -> SIMD3<Float> in
      let w = plane.transform * p
      return [w.x, w.y, w.z]
    }
    replaceCollider(id: plane.identifier, vertices: v, indices: [0, 1, 2, 0, 2, 3])
  }
  @available(iOS 13.4, *) private func schedule(_ anchor: ARMeshAnchor) {
    meshWork[anchor.identifier]?.cancel()
    let geometry = anchor.geometry
    let transform = anchor.transform
    let id = anchor.identifier
    let item = DispatchWorkItem { [weak self] in
      var vertices: [SIMD3<Float>] = []
      vertices.reserveCapacity(geometry.vertices.count)
      for i in 0..<geometry.vertices.count {
        let p = geometry.vertex(at: i)
        let world = transform * SIMD4(p.x, p.y, p.z, 1)
        vertices.append([world.x, world.y, world.z])
      }
      var indices: [UInt32] = []
      indices.reserveCapacity(geometry.faces.count * 3)
      for f in 0..<geometry.faces.count {
        if geometry.classificationOf(faceWithIndex: f) == .floor { continue }
        for j in 0..<3 { indices.append(geometry.faces.index(of: f, j: j)) }
      }
      self?.replaceCollider(id: id, vertices: vertices, indices: indices)
    }
    meshWork[id] = item
    meshQueue.asyncAfter(deadline: .now() + 0.35, execute: item)
  }
  private func replaceCollider(id: UUID, vertices: [SIMD3<Float>], indices: [UInt32]) {
    guard !vertices.isEmpty, !indices.isEmpty else { return }
    if !Thread.isMainThread {
      DispatchQueue.main.async {
        self.replaceCollider(id: id, vertices: vertices, indices: indices)
      }
      return
    }
    let vertexData = vertices.withUnsafeBytes { Data($0) }
    let indexData = indices.withUnsafeBytes { Data($0) }
    physics.replaceStaticMesh(id, vertices: vertexData, indices: indexData)
  }
}

@available(iOS 13.4, *) extension ARMeshGeometry {
  fileprivate func vertex(at i: Int) -> SIMD3<Float> {
    let p = vertices.buffer.contents().advanced(by: vertices.offset + i * vertices.stride)
    return p.assumingMemoryBound(to: SIMD3<Float>.self).pointee
  }
  fileprivate func index(of face: Int, j: Int) -> UInt32 {
    let p = faces.buffer.contents().advanced(
      by: (face * faces.indexCountPerPrimitive + j) * faces.bytesPerIndex)
    return faces.bytesPerIndex == 2
      ? UInt32(p.assumingMemoryBound(to: UInt16.self).pointee)
      : p.assumingMemoryBound(to: UInt32.self).pointee
  }
}
