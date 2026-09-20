import ARKit
import CoreMotion
import DriveBotJolt
import Flutter
import GameController
import RealityKit
import UIKit
import os

/// Entire simulation stays native: Flutter only creates/disposes this view.
/// ARKit/RealityKit use metres and Jolt receives the same world coordinates.
final class ArRacingView: NSObject, FlutterPlatformView, ARSessionDelegate {
  private enum Phase { case scanning, aiming, placing, building, ready, interrupted }
  private struct VehicleAppearance {
    let bodySize: SIMD3<Float>
    let color: UIColor
    let profile: String
  }
  private static let logger = Logger(subsystem: "de.drivebot", category: "ARPlacement")
  private let root = UIView()
  private let arView: ARView
  private let physics = DBJoltWorld()
  private let message = UILabel()
  private let speed = UILabel()
  private let resetButton = UIButton(type: .system)
  private let debugButton = UIButton(type: .system)
  private let scanButton = UIButton(type: .system)
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
  private var placementCandidate: SIMD3<Float>?
  private var placementMarker: ModelEntity?
  private var floorEntities: [UUID: ModelEntity] = [:]
  private var floorAnchors: [UUID: AnchorEntity] = [:]
  private let motion = CMMotionManager()
  private let vehicleID: String
  private var placementGeneration = 0

  private var appearance: VehicleAppearance {
    switch vehicleID {
    case "sport": return VehicleAppearance(bodySize: [0.14, 0.035, 0.30], color: .systemRed, profile: "sport")
    case "offroad": return VehicleAppearance(bodySize: [0.17, 0.075, 0.28], color: .systemGreen, profile: "offroad")
    default: return VehicleAppearance(bodySize: [0.15, 0.055, 0.25], color: .systemBlue, profile: "compact")
    }
  }

  init(frame: CGRect, viewIdentifier: Int64, vehicleID: String) {
    self.vehicleID = vehicleID
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
    startMotionSteering()
  }

  deinit {
    displayLink?.invalidate()
    NotificationCenter.default.removeObserver(self)
    arView.session.pause()
    motion.stopDeviceMotionUpdates()
    physics.removeVehicle()
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
    setScanVisible(true)
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
    style(scanButton, title: "Scan anzeigen")
    style(throttleButton, title: "GAS")
    style(brakeButton, title: "BREMSE")
    resetButton.addTarget(self, action: #selector(resetCar), for: .touchUpInside)
    debugButton.addTarget(self, action: #selector(toggleDebug), for: .touchUpInside)
    scanButton.addTarget(self, action: #selector(toggleDebug), for: .touchUpInside)
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
      message.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 64),
      message.trailingAnchor.constraint(lessThanOrEqualTo: resetButton.leadingAnchor, constant: -12),
      message.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
      message.heightAnchor.constraint(equalToConstant: 34),
      message.widthAnchor.constraint(lessThanOrEqualToConstant: 330),
      debugButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      debugButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
      debugButton.widthAnchor.constraint(equalToConstant: 44),
      debugButton.heightAnchor.constraint(equalToConstant: 44),
      scanButton.topAnchor.constraint(equalTo: debugButton.bottomAnchor, constant: 8),
      scanButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
      scanButton.widthAnchor.constraint(equalToConstant: 128),
      scanButton.heightAnchor.constraint(equalToConstant: 44),
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
        ? "iPhone langsam über Boden und Umgebung bewegen"
        : "Eingeschränkter Modus: nur Flächenerkennung"
    case .aiming: message.text = "Gültigen Boden anvisieren"
    case .placing: message.text = "Auto wird platziert …"
    case .building: message.text = "Fahrzeug wird erstellt …"
    case .ready: message.text = ""
    case .interrupted: message.text = "Tracking eingeschränkt – Fahrt pausiert"
    }
    message.isHidden = phase == .ready
    speed.isHidden = phase != .ready
    throttleButton.isHidden = phase != .ready
    brakeButton.isHidden = phase != .ready
    steeringPad.isHidden = true
    scanButton.isHidden = phase != .ready
    resetButton.isHidden = phase != .ready
  }

  @objc private func place(_ gesture: UITapGestureRecognizer) {
    guard phase == .aiming, let candidate = placementCandidate else { return }
    guard candidate.x.isFinite, candidate.y.isFinite, candidate.z.isFinite else {
      Self.logger.error("placement.reject invalid-transform")
      showPlacementFailure("Ungültiger Bodentreffer – bitte erneut anvisieren")
      return
    }
    placementGeneration += 1
    phase = .placing
    installCar(at: candidate, generation: placementGeneration)
  }

  private func installCar(at p: SIMD3<Float>, generation: Int) {
    Self.logger.notice("placement.begin generation=\(generation) vehicle=\(self.vehicleID, privacy: .public)")
    guard carAnchor == nil, phase == .placing else { return }
    phase = .building
    let anchor = AnchorEntity(world: p)
    let body = ModelEntity(
      mesh: .generateBox(size: appearance.bodySize, cornerRadius: 0.015),
      materials: [SimpleMaterial(color: appearance.color, roughness: 0.35, isMetallic: true)])
    anchor.addChild(body)
    let positions: [SIMD3<Float>] = [
      SIMD3(0.075, -0.025, 0.105),
      SIMD3(-0.075, -0.025, 0.105),
      SIMD3(0.075, -0.025, -0.105),
      SIMD3(-0.075, -0.025, -0.105),
    ]
    var builtWheels: [ModelEntity] = []
    for pos in positions {
      let wheel = ModelEntity(
        mesh: wheelMesh(),
        materials: [SimpleMaterial(color: .darkGray, isMetallic: false)])
      wheel.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
      wheel.position = pos
      anchor.addChild(wheel)
      builtWheels.append(wheel)
    }
    anchor.generateCollisionShapes(recursive: true)
    guard containsCollisionComponent(anchor) else {
      Self.logger.error("placement.collision-shapes-failed generation=\(generation)")
      showPlacementFailure(
        "Für das ausgewählte Fahrzeug konnte keine Kollisionsgeometrie erzeugt werden.")
      return
    }
    do {
      try physics.prepareVehicle(at: p, heading: 0, profile: appearance.profile)
    } catch {
      Self.logger.error(
        "placement.physics-failed generation=\(generation) error=\(error.localizedDescription, privacy: .public)")
      showPlacementFailure(error.localizedDescription)
      return
    }
    guard generation == placementGeneration else {
      physics.removeVehicle()
      Self.logger.error("placement.cancelled stale-generation=\(generation)")
      return
    }
    arView.scene.addAnchor(anchor)
    carAnchor = anchor
    chassis = body
    wheels = builtWheels
    physics.setPaused(false)
    setScanVisible(false)
    phase = .ready
    Self.logger.notice("placement.ready generation=\(generation)")
  }

  private func showPlacementFailure(_ text: String) {
    physics.removeVehicle()
    carAnchor?.removeFromParent()
    carAnchor = nil
    wheels.removeAll()
    phase = hasFloor ? .aiming : .scanning
    message.text = text
    message.isHidden = false
  }

  private func wheelMesh() -> MeshResource {
    if #available(iOS 18.0, *) {
      return .generateCylinder(height: 0.018, radius: 0.025)
    }

    // Before iOS 18 RealityKit has no synchronous cylinder generator. A rounded
    // 18 x 50 x 50 mm mesh preserves the wheel envelope and the common rotation.
    return .generateBox(size: [0.05, 0.018, 0.05], cornerRadius: 0.0125)
  }

  @objc private func resetCar() {
    placementGeneration += 1
    releaseInputs()
    physics.setPaused(true)
    physics.removeVehicle()
    carAnchor?.removeFromParent()
    carAnchor = nil
    wheels.removeAll()
    setScanVisible(true)
    phase = hasFloor ? .aiming : .scanning
  }
  @objc private func toggleDebug() {
    setScanVisible(!debugVisible)
  }
  private func setScanVisible(_ visible: Bool) {
    debugVisible = visible
    if hasSceneReconstruction {
      if visible { arView.debugOptions.insert(.showSceneUnderstanding) }
      else { arView.debugOptions.remove(.showSceneUnderstanding) }
    }
    for entity in debugEntities.values { entity.isEnabled = debugVisible }
    for entity in floorEntities.values { entity.isEnabled = debugVisible }
    scanButton.setTitle(visible ? "Scan ausblenden" : "Scan anzeigen", for: .normal)
  }

  private func startMotionSteering() {
    guard motion.isDeviceMotionAvailable else { return }
    motion.deviceMotionUpdateInterval = 1.0 / 60.0
    motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
      guard let self, let sample, self.phase == .ready else { return }
      let target = Float(sample.gravity.x * 1.45)
      self.steering += (min(1, max(-1, target)) - self.steering) * 0.22
      if abs(self.steering) < 0.04 { self.steering = 0 }
      self.sendInput()
    }
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
    updatePlacementCandidate()
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
      wheels[i].setTransformMatrix(matrix, relativeTo: nil)
    }
    if state.collided { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
  }

  private func updatePlacementCandidate() {
    guard phase == .aiming || phase == .scanning else {
      placementMarker?.isEnabled = false
      return
    }
    let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
    guard let hit = arView.raycast(
      from: center, allowing: .existingPlaneGeometry, alignment: .horizontal
    ).first else {
      placementCandidate = nil
      placementMarker?.isEnabled = false
      if hasFloor { phase = .aiming }
      return
    }
    let position = SIMD3(
      hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y,
      hit.worldTransform.columns.3.z)
    guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return }
    placementCandidate = position
    if placementMarker == nil {
      let marker = ModelEntity(
        mesh: .generateBox(size: [0.12, 0.002, 0.12], cornerRadius: 0.02),
        materials: [SimpleMaterial(color: .systemTeal.withAlphaComponent(0.72), isMetallic: false)])
      let anchor = AnchorEntity(world: position)
      anchor.addChild(marker)
      arView.scene.addAnchor(anchor)
      placementMarker = marker
    }
    placementMarker?.isEnabled = true
    placementMarker?.setPosition(position + SIMD3(0, 0.003, 0), relativeTo: nil)
    phase = .aiming
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    DispatchQueue.main.async {
      switch camera.trackingState {
      case .normal:
        self.physics.setPaused(false)
        self.phase = self.carAnchor == nil ? (self.hasFloor ? .aiming : .scanning) : .ready
      default: self.interrupted()
      }
    }
  }
  func sessionWasInterrupted(_ session: ARSession) {
    DispatchQueue.main.async { [weak self] in self?.interrupted() }
  }
  func sessionInterruptionEnded(_ session: ARSession) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.releaseInputs()
      self.physics.removeVehicle()
      self.carAnchor?.removeFromParent()
      self.carAnchor = nil
      self.chassis = nil
      self.wheels.removeAll()
      self.hasFloor = false
      self.startSession()
    }
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
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.session(session, didRemove: anchors) }
      return
    }
    for anchor in anchors {
      meshWork[anchor.identifier]?.cancel()
      meshWork.removeValue(forKey: anchor.identifier)
      physics.removeStaticMesh(anchor.identifier)
      debugEntities.removeValue(forKey: anchor.identifier)?.removeFromParent()
      floorEntities.removeValue(forKey: anchor.identifier)?.removeFromParent()
      floorAnchors.removeValue(forKey: anchor.identifier)?.removeFromParent()
    }
  }

  private func process(_ anchors: [ARAnchor]) {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.process(anchors) }
      return
    }
    for anchor in anchors {
      if let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal, plane.extent.x > 0.3,
        plane.extent.z > 0.3
      {
        hasFloor = true
        if carAnchor == nil { phase = .aiming }
        installPlaneCollider(plane)
        visualizeFloor(plane)
      }
      if #available(iOS 13.4, *), let mesh = anchor as? ARMeshAnchor { schedule(mesh) }
    }
  }
  private func visualizeFloor(_ plane: ARPlaneAnchor) {
    let size = SIMD3<Float>(max(0.01, plane.extent.x), 0.001, max(0.01, plane.extent.z))
    let isNew = floorEntities[plane.identifier] == nil
    let entity = floorEntities[plane.identifier] ?? ModelEntity(
      mesh: .generateBox(size: size),
      materials: [SimpleMaterial(color: .systemTeal.withAlphaComponent(0.12), isMetallic: false)])
    entity.model?.mesh = .generateBox(size: size)
    let anchor = floorAnchors[plane.identifier] ?? AnchorEntity(world: plane.transform)
    anchor.transform.matrix = plane.transform
    entity.position = plane.center + SIMD3(0, 0.002, 0)
    entity.isEnabled = debugVisible
    entity.model?.materials = [
      SimpleMaterial(color: .systemTeal.withAlphaComponent(isNew ? 0.28 : 0.20), isMetallic: false)
    ]
    if entity.parent == nil {
      anchor.addChild(entity)
      arView.scene.addAnchor(anchor)
    }
    floorAnchors[plane.identifier] = anchor
    floorEntities[plane.identifier] = entity
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak entity] in
      entity?.model?.materials = [
        SimpleMaterial(color: .systemTeal.withAlphaComponent(0.12), isMetallic: false)
      ]
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
      let faces: ARGeometryElement = geometry.faces
      let indicesPerFace: Int = faces.indexCountPerPrimitive
      guard faces.primitiveType == .triangle, indicesPerFace == 3,
        let indicesPerFace32 = UInt32(exactly: indicesPerFace),
        let vertexCount32 = UInt32(exactly: geometry.vertices.count)
      else { return }

      for faceIndex in 0..<faces.count {
        // Plane anchors already provide the floor collider. Classification is
        // optional, so an absent/unknown value must not discard valid geometry.
        if geometry.classification(at: faceIndex) == .floor { continue }
        guard let faceIndex32 = UInt32(exactly: faceIndex) else { continue }

        var triangleIndices: [UInt32] = []
        triangleIndices.reserveCapacity(indicesPerFace)
        for cornerIndex in UInt32(0)..<indicesPerFace32 {
          guard let vertexIndex = geometry.vertexIndex(
            of: faceIndex32, corner: cornerIndex),
            vertexIndex < vertexCount32
          else {
            triangleIndices.removeAll()
            break
          }
          triangleIndices.append(vertexIndex)
        }
        indices.append(contentsOf: triangleIndices)
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

private func containsCollisionComponent(_ entity: Entity) -> Bool {
  if entity.components[CollisionComponent.self] != nil {
    return true
  }

  return entity.children.contains { child in
    containsCollisionComponent(child)
  }
}

@available(iOS 13.4, *) extension ARMeshGeometry {
  fileprivate func vertex(at i: Int) -> SIMD3<Float> {
    let p = vertices.buffer.contents().advanced(by: vertices.offset + i * vertices.stride)
    return p.assumingMemoryBound(to: SIMD3<Float>.self).pointee
  }
  fileprivate func vertexIndex(of face: UInt32, corner: UInt32) -> UInt32? {
    let faces: ARGeometryElement = self.faces
    guard let faceIndex = Int(exactly: face), let cornerIndex = Int(exactly: corner),
      faceIndex < faces.count, cornerIndex < faces.indexCountPerPrimitive,
      faces.bytesPerIndex == MemoryLayout<UInt16>.size
        || faces.bytesPerIndex == MemoryLayout<UInt32>.size
    else { return nil }

    let (primitiveOffset, primitiveOverflow) = faceIndex.multipliedReportingOverflow(
      by: faces.indexCountPerPrimitive)
    let (flatIndex, indexOverflow) = primitiveOffset.addingReportingOverflow(cornerIndex)
    let (byteOffset, byteOffsetOverflow) = flatIndex.multipliedReportingOverflow(
      by: faces.bytesPerIndex)
    let (bufferEnd, bufferEndOverflow) = byteOffset.addingReportingOverflow(faces.bytesPerIndex)
    guard !primitiveOverflow, !indexOverflow, !byteOffsetOverflow, !bufferEndOverflow,
      byteOffset >= 0, bufferEnd <= faces.buffer.length
    else { return nil }

    let pointer = faces.buffer.contents().advanced(by: byteOffset)
    if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
      return UInt32(pointer.load(as: UInt16.self))
    }
    return pointer.load(as: UInt32.self)
  }

  fileprivate func classification(at face: Int) -> ARMeshClassification {
    guard face >= 0, let classifications = classification,
      face < faces.count, face < classifications.count,
      classifications.format == .uchar, classifications.offset >= 0,
      classifications.stride > 0
    else { return .none }

    let (faceOffset, overflow) = face.multipliedReportingOverflow(by: classifications.stride)
    guard !overflow else { return .none }
    let (byteOffset, additionOverflow) = classifications.offset.addingReportingOverflow(faceOffset)
    guard !additionOverflow, byteOffset >= 0, byteOffset < classifications.buffer.length else {
      return .none
    }

    let rawValue = classifications.buffer.contents().advanced(by: byteOffset).load(as: UInt8.self)
    return ARMeshClassification(rawValue: Int(rawValue)) ?? .none
  }
}
