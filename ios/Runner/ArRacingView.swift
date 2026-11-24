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
  private final class DisplayLinkTarget: NSObject {
    weak var view: ArRacingView?

    @MainActor @objc func tick(_ link: CADisplayLink) {
      guard let view else {
        link.invalidate()
        return
      }
      view.frame(link)
    }
  }

  private enum Phase { case scanning, aiming, placing, building, ready, interrupted }
  private enum PlacementPhysicsMode { case fullJolt, visualOnly }
  fileprivate static let logger = Logger(subsystem: "de.drivebot", category: "ARPlacement")
  private let root = UIView()
  private let arView: ARView
  private let physics = SerializedJoltWorld()
  #if DEBUG
    /// Set `DRIVEBOT_VISUAL_ONLY_PLACEMENT=1` in the scheme to isolate RealityKit placement.
    private let placementPhysicsMode: PlacementPhysicsMode =
      ProcessInfo.processInfo.environment["DRIVEBOT_VISUAL_ONLY_PLACEMENT"] == "1"
      ? .visualOnly : .fullJolt
  #else
    private let placementPhysicsMode: PlacementPhysicsMode = .fullJolt
  #endif
  private let message = UILabel()
  private let speed = UILabel()
  private let inputDiagnostics = UILabel()
  private let resetButton = UIButton(type: .system)
  private let diagnosisButton = UIButton(type: .system)
  private let debugButton = UIButton(type: .system)
  private let scanButton = UIButton(type: .system)
  private let steeringPad = UIView()
  private var walkingArrows: [UIImageView] = []
  private let steeringKnob = UIView()
  private let throttleButton = UIButton(type: .system)
  private let brakeButton = UIButton(type: .system)
  private var carAnchor: AnchorEntity?
  private var vehiclePose: Entity?
  private var vehicleVisualRoot: Entity?
  private var wheels: [Entity] = []
  private var phase: Phase = .scanning { didSet { updateMessage() } }
  private var displayLink: CADisplayLink?
  private var previousTime: CFTimeInterval = 0
  private var physicsStepPending = false
  private var physicsFailed = false
  private var trackingInterrupted = false
  private var pedals = RacingPedals()
  private var steering: Float = 0
  private var touchSteering = false
  private enum PlayMode { case driving, exiting, onFoot, entering }
  private var mode: PlayMode = .driving
  private let interaction = UIButton(type: .system)
  private var avatar: RallyWalker?
  private var inventory = RallyInventory()
  private let equipmentButton = UIButton(type: .system)
  private let cycleButton = UIButton(type: .system)
  private var marks: [AnchorEntity] = []
  private var wingModel: Entity?
  private var deployed = false
  private let boostButton = UIButton(type: .system)
  private let district = RallyDistrict()
  @MainActor private lazy var walkingSurface = RallyWalkingSurface(view: arView)
  private var walkInput = SIMD2<Float>.zero
  private var outsideDoor = SIMD3<Float>.zero
  private var transitionTime: Float = 0
  private var lastSpeed = Float.infinity
  private let controls = RallySteeringPreferences()
  private lazy var settingsPanel = MainActor.assumeIsolated {
    RallySteeringPanel(controls: controls) { [weak self] in self?.toggleDebug() }
  }
  private var meshWork: [UUID: DispatchWorkItem] = [:]
  private let meshQueue = DispatchQueue(label: "de.drivebot.mesh", qos: .utility)
  private var debugVisible = false
  private var debugEntities: [UUID: Entity] = [:]
  private var hasFloor = false
  private var hasSceneReconstruction = false
  private var placementCandidate: SIMD3<Float>?
  private var placementPlane: ARPlaneAnchor?
  private var placementFloorY: Float?
  private var placementMarker: ModelEntity?
  private var floorEntities: [UUID: ModelEntity] = [:]
  private var floorAnchors: [UUID: AnchorEntity] = [:]
  private let motion = CMMotionManager()
  private var neutralTilt: Double?
  private let vehicleID: String
  private var placementGeneration = 0
  private var lastSuccessfulOperation = "initialization"

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
    NotificationCenter.default.addObserver(
      self, selector: #selector(resumeIfTracked), name: UIApplication.didBecomeActiveNotification,
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
    config.planeDetection = [.horizontal, .vertical]
    config.environmentTexturing = .automatic
    if #available(iOS 13.4, *),
      ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    {
      config.sceneReconstruction = .meshWithClassification
      hasSceneReconstruction = true
      arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting, .collision]
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
      button.layer.cornerRadius = 14
      button.layer.borderWidth = 1
      button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
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
    inputDiagnostics.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    inputDiagnostics.textColor = .white
    inputDiagnostics.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    inputDiagnostics.textAlignment = .center
    inputDiagnostics.layer.cornerRadius = 8
    inputDiagnostics.clipsToBounds = true
    inputDiagnostics.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(inputDiagnostics)
    style(resetButton, title: "Fahrzeug zurücksetzen")
    style(diagnosisButton, title: "Diagnose kopieren")
    style(debugButton, title: "")
    debugButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
    debugButton.accessibilityLabel = "Steuerung einstellen"
    style(scanButton, title: "Scan anzeigen")
    style(equipmentButton, title: "")
    equipmentButton.setImage(UIImage(systemName: "scope"), for: .normal)
    equipmentButton.accessibilityLabel = "Energieimpuls"
    equipmentButton.addTarget(self, action: #selector(firePulse), for: .touchUpInside)
    style(cycleButton, title: "")
    cycleButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
    cycleButton.accessibilityLabel = "Ausrüstung wechseln"
    cycleButton.addTarget(self, action: #selector(cycleEquipment), for: .touchUpInside)
    style(boostButton, title: "NOS")
    boostButton.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.82)
    boostButton.addTarget(self, action: #selector(toggleBoost), for: .touchUpInside)
    style(interaction, title: "Aussteigen")
    interaction.addTarget(self, action: #selector(interact), for: .touchUpInside)
    style(throttleButton, title: "GAS")
    throttleButton.backgroundColor = UIColor(red: 0.13, green: 0.80, blue: 0.70, alpha: 0.96)
    throttleButton.setTitleColor(.black, for: .normal)
    style(brakeButton, title: "BREMSE")
    NSLayoutConstraint.activate([
      equipmentButton.trailingAnchor.constraint(equalTo: boostButton.trailingAnchor),
      equipmentButton.bottomAnchor.constraint(equalTo: boostButton.bottomAnchor),
      equipmentButton.widthAnchor.constraint(equalToConstant: 54), equipmentButton.heightAnchor.constraint(equalToConstant: 48),
      cycleButton.trailingAnchor.constraint(equalTo: equipmentButton.leadingAnchor, constant: -8),
      cycleButton.bottomAnchor.constraint(equalTo: equipmentButton.bottomAnchor),
      cycleButton.widthAnchor.constraint(equalToConstant: 48), cycleButton.heightAnchor.constraint(equalToConstant: 48),
      boostButton.trailingAnchor.constraint(equalTo: root.safeAreaLayoutGuide.trailingAnchor, constant: -18),
      boostButton.bottomAnchor.constraint(equalTo: throttleButton.topAnchor, constant: -8),
      boostButton.widthAnchor.constraint(equalToConstant: 105), boostButton.heightAnchor.constraint(equalToConstant: 44)
    ])
    resetButton.addTarget(self, action: #selector(resetCar), for: .touchUpInside)
    diagnosisButton.addTarget(self, action: #selector(shareDiagnosis), for: .touchUpInside)
    debugButton.addTarget(self, action: #selector(toggleDebug), for: .touchUpInside)
    scanButton.addTarget(self, action: #selector(toggleScan), for: .touchUpInside)
    throttleButton.addTarget(
      self, action: #selector(throttleDown), for: [.touchDown, .touchDragEnter])
    throttleButton.addTarget(
      self, action: #selector(throttleUp),
      for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    brakeButton.addTarget(self, action: #selector(brakeDown), for: .touchDown)
    brakeButton.addTarget(self, action: #selector(brakeUp), for: .touchUpInside)
    brakeButton.addTarget(
      self, action: #selector(brakeCancelled),
      for: [.touchUpOutside, .touchCancel, .touchDragExit])
    steeringPad.backgroundColor = UIColor.black.withAlphaComponent(0.45)
    steeringPad.layer.cornerRadius = 44
    steeringPad.layer.borderWidth = 1.5
    steeringPad.layer.borderColor = UIColor.systemTeal.withAlphaComponent(0.65).cgColor
    steeringPad.isAccessibilityElement = true
    steeringPad.accessibilityTraits = [.allowsDirectInteraction]
    steeringPad.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(steeringPad)
    for (symbol, dx, dy) in [("chevron.left", -46, 0), ("chevron.right", 46, 0),
                             ("chevron.up", 0, -32), ("chevron.down", 0, 32)] {
      let arrow = UIImageView(image: UIImage(systemName: symbol))
      arrow.tintColor = .white
      arrow.contentMode = .scaleAspectFit
      arrow.translatesAutoresizingMaskIntoConstraints = false
      steeringPad.addSubview(arrow)
      NSLayoutConstraint.activate([
        arrow.widthAnchor.constraint(equalToConstant: 12),
        arrow.heightAnchor.constraint(equalToConstant: 12),
        arrow.centerXAnchor.constraint(equalTo: steeringPad.centerXAnchor, constant: CGFloat(dx)),
        arrow.centerYAnchor.constraint(equalTo: steeringPad.centerYAnchor, constant: CGFloat(dy))
      ])
      if dy != 0 { walkingArrows.append(arrow) }
    }
    steeringKnob.backgroundColor = UIColor.white.withAlphaComponent(0.8)
    steeringKnob.layer.cornerRadius = 21
    steeringKnob.isUserInteractionEnabled = false
    steeringKnob.translatesAutoresizingMaskIntoConstraints = false
    steeringPad.addSubview(steeringKnob)
    let stickTouch = UILongPressGestureRecognizer(target: self, action: #selector(steer(_:)))
    stickTouch.minimumPressDuration = 0
    stickTouch.allowableMovement = .greatestFiniteMagnitude
    steeringPad.addGestureRecognizer(stickTouch)
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
      resetButton.widthAnchor.constraint(equalToConstant: 190),
      resetButton.heightAnchor.constraint(equalToConstant: 44),
      diagnosisButton.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 8),
      diagnosisButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
      diagnosisButton.widthAnchor.constraint(equalToConstant: 190),
      diagnosisButton.heightAnchor.constraint(equalToConstant: 44),
      speed.centerYAnchor.constraint(equalTo: debugButton.centerYAnchor),
      speed.trailingAnchor.constraint(equalTo: resetButton.leadingAnchor, constant: -8),
      speed.widthAnchor.constraint(equalToConstant: 90),
      speed.heightAnchor.constraint(equalToConstant: 36),
      inputDiagnostics.topAnchor.constraint(equalTo: speed.bottomAnchor, constant: 6),
      inputDiagnostics.centerXAnchor.constraint(equalTo: speed.centerXAnchor),
      inputDiagnostics.widthAnchor.constraint(equalToConstant: 210),
      inputDiagnostics.heightAnchor.constraint(equalToConstant: 24),
      steeringPad.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
      steeringPad.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
      steeringPad.widthAnchor.constraint(equalToConstant: 120),
      steeringPad.heightAnchor.constraint(equalToConstant: 88),
      steeringKnob.centerXAnchor.constraint(equalTo: steeringPad.centerXAnchor),
      steeringKnob.centerYAnchor.constraint(equalTo: steeringPad.centerYAnchor),
      steeringKnob.widthAnchor.constraint(equalToConstant: 42),
      steeringKnob.heightAnchor.constraint(equalToConstant: 42),
      interaction.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
      interaction.bottomAnchor.constraint(equalTo: throttleButton.topAnchor, constant: -8),
      interaction.widthAnchor.constraint(equalToConstant: 128),
      interaction.heightAnchor.constraint(equalToConstant: 44),
      throttleButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
      throttleButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
      throttleButton.widthAnchor.constraint(equalToConstant: 92),
      throttleButton.heightAnchor.constraint(equalToConstant: 58),
      brakeButton.trailingAnchor.constraint(equalTo: throttleButton.leadingAnchor, constant: -12),
      brakeButton.centerYAnchor.constraint(equalTo: throttleButton.centerYAnchor),
      brakeButton.widthAnchor.constraint(equalToConstant: 92),
      brakeButton.heightAnchor.constraint(equalToConstant: 58),
    ])
    root.addSubview(settingsPanel)
    NSLayoutConstraint.activate([
      settingsPanel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
      settingsPanel.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
      settingsPanel.widthAnchor.constraint(equalToConstant: 280)
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
    case .aiming:
      message.text = placementCandidate == nil
        ? "Gültigen Boden anvisieren" : "Zum Platzieren auf die Markierung tippen"
    case .placing: message.text = "Auto wird platziert …"
    case .building: message.text = "Fahrzeug wird erstellt …"
    case .ready: message.text = ""
    case .interrupted: message.text = "Tracking eingeschränkt – Fahrt pausiert"
    }
    message.isHidden = phase == .ready
    speed.isHidden = phase != .ready
    let playing = phase == .ready && placementPhysicsMode == .fullJolt && settingsPanel.isHidden
    throttleButton.isHidden = !playing || mode != .driving
    brakeButton.isHidden = throttleButton.isHidden
    steeringPad.isHidden = !playing || (mode != .driving && mode != .onFoot)
    equipmentButton.isHidden = !playing || mode != .onFoot || inventory.held != .blaster
    cycleButton.isHidden = !playing || mode != .onFoot || !inventory.collected.isSuperset(of: [.sword,.blaster])
    boostButton.isHidden = !playing || mode != .driving || inventory.remaining <= 0
    let pickup = avatar.flatMap { district.pickup(at: $0.root.position(relativeTo: nil)) }
    let shop = avatar.flatMap { district.entry(at: $0.root.position(relativeTo: nil)) }
    interaction.isHidden = !playing || !(mode == .driving || (mode == .onFoot && (nearDoor || shop != nil || district.inside != nil)))
    interaction.isEnabled = mode == .onFoot || lastSpeed <= 0.01
    interaction.alpha = interaction.isEnabled ? 1 : 0.45
    for arrow in walkingArrows { arrow.isHidden = mode != .onFoot }
    steeringPad.accessibilityLabel = mode == .onFoot ? "Gehen" : "Lenken"
    interaction.setTitle(mode == .onFoot ? (pickup != nil ? "Aufnehmen" : district.inside != nil ? "Verlassen" : shop != nil ? "Interagieren" : "Einsteigen") : "Aussteigen", for: .normal)
    if mode != .driving { speed.text = "ZU FUSS" }
    else if phase == .ready && lastSpeed.isFinite { speed.text = String(format: "%.2f m/s", lastSpeed) }
    scanButton.isHidden = phase != .ready
    resetButton.isHidden = phase != .ready && !physicsFailed
    diagnosisButton.isHidden = !physicsFailed
    inputDiagnostics.isHidden = phase != .ready || !debugVisible
  }

  @MainActor @objc private func place(_ gesture: UITapGestureRecognizer) {
    Self.logger.notice("[Placement] 01 tap received")
    guard phase == .aiming, let candidate = placementCandidate,
      let plane = placementPlane else { return }
    guard candidate.x.isFinite, candidate.y.isFinite, candidate.z.isFinite else {
      Self.logger.error("placement.reject invalid-transform")
      showPlacementFailure("Ungültiger Bodentreffer – bitte erneut anvisieren")
      return
    }
    Self.logger.notice("[Placement] 02 raycast valid")
    placementGeneration += 1
    phase = .placing
    placementCandidate = nil
    placementPlane = nil
    placementMarker?.isEnabled = false
    Self.logger.notice("[Placement] 03 placement locked")
    // Both operations are queued in order on the same Jolt world.
    installPlaneCollider(plane)
    installCar(at: candidate, generation: placementGeneration)
  }

  @MainActor private func installCar(at p: SIMD3<Float>, generation: Int) {
    guard carAnchor == nil, phase == .placing else { return }
    phase = .building
    let profile = ["sport", "offroad"].contains(vehicleID) ? vehicleID : "compact"
    placementFloorY = p.y
    Self.logger.notice("[Placement] 04 vehicle configuration found")

    let vehicle = RallyVehicleVisual.build(profile: profile)
    let visualRoot = vehicle.root
    let builtWheels = vehicle.wheels
    let bounds = visualRoot.visualBounds(relativeTo: visualRoot)
    let modelLength = bounds.extents.z
    guard modelLength.isFinite, modelLength > 0, builtWheels.count == 4 else {
      showPlacementFailure("Das Fahrzeugmodell enthält ungültige Geometrie.")
      return
    }
    let uniformScale = RallyScale.metres(6.5) / modelLength
    visualRoot.scale = SIMD3(repeating: uniformScale)
    Self.logger.notice("[Placement] 05 visual model loaded")

    let anchor = AnchorEntity(world: p)
    let pose = Entity()
    pose.position.y = 0.011
    pose.addChild(visualRoot)
    anchor.addChild(pose)
    arView.scene.addAnchor(anchor)
    carAnchor = anchor
    vehiclePose = pose
    vehicleVisualRoot = visualRoot
    wheels = builtWheels
    Self.logger.notice("[Placement] 06 model attached")

    if placementPhysicsMode == .visualOnly {
      setScanVisible(false)
      phase = .ready
      Self.logger.notice("[Placement] visual-only ready (Jolt intentionally skipped)")
      return
    }
    physics.prepareVehicle(at: p, heading: 0, profile: profile) {
      [weak self] result in
      guard let self else { return }
      guard generation == self.placementGeneration, self.phase == .building else {
        return
      }
      switch result {
      case .failure(let error):
        Self.logger.error("[Placement] failed: \(error.localizedDescription, privacy: .public)")
        if error is PlacementContactError {
          self.showPlacementFailure(error.localizedDescription)
        } else {
          self.stopAfterPhysicsFailure(error)
        }
      case .success(let state):
        Self.logger.notice("[Placement] 08 Jolt vehicle created")
        guard let transform = state.chassis?.matrix, isFiniteTransform(transform) else {
          self.showPlacementFailure("Jolt lieferte eine ungültige Fahrzeugtransformation.")
          return
        }
        self.applyVehicleTransforms(state, chassisTransform: transform, pose: pose,
                                    visualRoot: visualRoot)
        self.lastSuccessfulOperation = state.operation
        Self.logger.notice("[Placement] 09 initial transform applied")
        self.physics.setPaused(self.trackingInterrupted)
        self.physicsFailed = false
        self.setScanVisible(false)
        self.phase = self.trackingInterrupted ? .interrupted : .ready
        Self.logger.notice("[Placement] 10 driving started")
      }
    }
  }

  private func showPlacementFailure(_ text: String) {
    Self.logger.error("Placement rejected: \(text, privacy: .public)")
    physics.removeVehicle()
    if let carAnchor { arView.scene.removeAnchor(carAnchor) }
    carAnchor = nil
    vehiclePose = nil
    vehicleVisualRoot = nil
    placementFloorY = nil
    wheels.removeAll()
    setScanVisible(true)
    phase = hasFloor ? .aiming : .scanning
    message.text = text
    message.isHidden = false
  }

  @objc private func resetCar() {
    for mark in marks { mark.removeFromParent() }
    marks.removeAll()
    wingModel = nil
    deployed = false
    district.reset()
    inventory = RallyInventory()
    placementGeneration += 1
    avatar?.root.removeFromParent()
    avatar = nil
    mode = .driving
    lastSpeed = .infinity
    releaseInputs()
    physics.setPaused(true)
    physics.removeVehicle()
    physicsFailed = false
    physicsStepPending = false
    previousTime = 0
    displayLink?.isPaused = false
    if let carAnchor { arView.scene.removeAnchor(carAnchor) }
    carAnchor = nil
    vehiclePose = nil
    vehicleVisualRoot = nil
    placementFloorY = nil
    wheels.removeAll()
    setScanVisible(true)
    phase = hasFloor ? .aiming : .scanning
  }
  @objc private func shareDiagnosis() {
    guard let report = PhysicsDiagnostics.load() else { return }
    let controller = UIActivityViewController(activityItems: [report], applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = diagnosisButton
    controller.popoverPresentationController?.sourceRect = diagnosisButton.bounds
    root.window?.rootViewController?.present(controller, animated: true)
  }
  @objc private func toggleDebug() {
    releaseInputs()
    settingsPanel.isHidden.toggle()
    root.bringSubviewToFront(settingsPanel)
    updateMessage()
    calibrateSteering()
  }
  @objc private func toggleScan() { setScanVisible(!debugVisible) }
  private func setScanVisible(_ visible: Bool) {
    debugVisible = visible
    if hasSceneReconstruction {
      if visible { arView.debugOptions.insert(.showSceneUnderstanding) }
      else { arView.debugOptions.remove(.showSceneUnderstanding) }
    }
    for entity in debugEntities.values { entity.isEnabled = debugVisible }
    for entity in floorEntities.values { entity.isEnabled = debugVisible }
    inputDiagnostics.isHidden = !visible || phase != .ready
    scanButton.setTitle(visible ? "Scan ausblenden" : "Scan anzeigen", for: .normal)
  }

  private func startMotionSteering() {
    guard motion.isDeviceMotionAvailable else { return }
    motion.deviceMotionUpdateInterval = 1.0 / 60.0
    motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
      guard let self, let sample, self.phase == .ready, self.settingsPanel.isHidden, !self.touchSteering, self.mode == .driving else { return }
      let rawTilt = self.landscapeTilt(gravity: sample.gravity)
      if self.neutralTilt == nil { self.neutralTilt = rawTilt }
      let target = SteeringInput.normalizedTilt(rawTilt - (self.neutralTilt ?? rawTilt))
      self.steering += (target - self.steering) * 0.28
      self.sendInput()
    }
  }
  @objc private func throttleDown() {
    guard phase == .ready, mode == .driving, settingsPanel.isHidden else { return }
    pedals.setGas(pressed: true)
    sendInput()
  }

  @objc private func throttleUp() {
    pedals.setGas(pressed: false)
    sendInput()
  }

  @objc private func brakeDown() {
    guard phase == .ready, mode == .driving, settingsPanel.isHidden else { return }
    pedals.pressBrake()
    updateBrakeButton()
    sendInput()
  }

  @objc private func brakeUp() {
    pedals.releaseBrake()
    updateBrakeButton()
    sendInput()
  }

  @objc private func brakeCancelled() {
    pedals.releaseBrake(cancelled: true)
    updateBrakeButton()
    sendInput()
  }

  private func updateBrakeButton() {
    let reversing = pedals.isReversing
    brakeButton.setTitle(reversing ? "R" : "BREMSE", for: .normal)
    brakeButton.accessibilityLabel = reversing ? "Rückwärtsfahren" : "Bremse"
    brakeButton.backgroundColor = reversing
      ? UIColor(red: 0.76, green: 0.07, blue: 0.11, alpha: 1)
      : UIColor.black.withAlphaComponent(0.55)
  }
  @objc private func steer(_ pan: UILongPressGestureRecognizer) {
    let point = pan.location(in: steeringPad)
    let active = pan.state == .began || pan.state == .changed
    var input = SIMD2(Float(point.x / steeringPad.bounds.width * 2 - 1),
                      Float(point.y / steeringPad.bounds.height * 2 - 1))
    input /= max(1, simd_length(input))
    if !active { input = .zero }
    steeringKnob.transform = CGAffineTransform(translationX: CGFloat(input.x) * 32,
                                               y: CGFloat(input.y) * 24)
    if mode == .onFoot { walkInput = input; return }
    guard mode == .driving else { return }
    touchSteering = active
    steering = input.x
    sendInput()
  }
  private func sendInput() {
    let requestedAngle = SteeringInput.angle(steering, sensitivity: controls.sensitivity,
                                             inverted: controls.inverted)
    physics.setThrottle(pedals.throttle, brake: pedals.brake, steering: requestedAngle)
    guard !inputDiagnostics.isHidden else { return }
    inputDiagnostics.text = String(
      format: "Gas %+.1f | Bremse %.1f | Lenkung %+.2f", pedals.throttle, pedals.brake, requestedAngle)
  }
  private func calibrateSteering() { neutralTilt = nil }
  private func landscapeTilt(gravity: CMAcceleration) -> Double {
    switch root.window?.windowScene?.interfaceOrientation {
    case .landscapeLeft: return -gravity.y
    case .landscapeRight: return gravity.y
    default: return gravity.x
    }
  }
  private func releaseInputs() {
    if inventory.boosting { inventory.stopBoost(); physics.boost(false) }
    pedals = RacingPedals()
    updateBrakeButton()
    steering = 0
    touchSteering = false
    walkInput = .zero
    steeringKnob.transform = .identity
    sendInput()
  }
  @objc private func interrupted() {
    trackingInterrupted = true
    releaseInputs()
    physics.setPaused(true)
    previousTime = 0
    if phase != .building { phase = .interrupted }
  }

  private var door: SIMD3<Float>? {
    vehiclePose?.convert(position: [-0.017, 0, 0.008], to: nil)
  }
  private var nearDoor: Bool {
    guard let door, let avatar else { return false }
    let local = avatar.root.position(relativeTo: vehiclePose)
    return RallyWalking.canEnter(distance: simd_distance(door, avatar.root.position(relativeTo: nil)),
                                 localX: local.x)
  }

  @MainActor @objc private func cycleEquipment() {
    guard let avatar, mode == .onFoot else { return }
    inventory.cycle()
    equip(avatar)
    updateMessage()
  }

  @MainActor @objc private func firePulse() {
    guard mode == .onFoot, inventory.held == .blaster, phase == .ready, settingsPanel.isHidden else { return }
    let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
    guard let hit = arView.raycast(from: center, allowing: .existingPlaneGeometry, alignment: .any).first,
          hit.anchor is ARPlaneAnchor else { return }
    let anchor = AnchorEntity(world: hit.worldTransform)
    let spot = ModelEntity(mesh: .generateSphere(radius: 0.0018), materials: [UnlitMaterial(color: .systemTeal)])
    spot.scale.y = 0.12
    spot.position.y = 0.00035
    anchor.addChild(spot)
    arView.scene.addAnchor(anchor)
    marks.append(anchor)
    if marks.count > 30 { marks.removeFirst().removeFromParent() }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  @objc private func toggleBoost() {
    guard phase == .ready, mode == .driving, inventory.remaining > 0 else { return }
    if inventory.boosting { inventory.stopBoost() } else { inventory.boosting = true }
    physics.boost(inventory.boosting)
  }

  @MainActor private func equip(_ walker: RallyWalker) {
    walker.root.findEntity(named: "held item")?.removeFromParent()
    if let held = inventory.held, let model = held.model() {
      model.name = "held item"
      model.position = [0.0035,0.006,0.001]
      walker.root.addChild(model)
    }
  }

  @MainActor @objc private func interact() {
    guard phase == .ready, settingsPanel.isHidden, let pose = vehiclePose else { return }
    switch mode {
    case .driving:
      guard lastSpeed <= 0.01, pedals.throttle == 0, let door,
            let anchor = carAnchor else { return }
      let query = ARRaycastQuery(origin: door + SIMD3(0, 0.015, 0), direction: [0,-1,0],
                                 allowing: .existingPlaneGeometry, alignment: .horizontal)
      guard let floor = arView.session.raycast(query).first else { return }
      let y = floor.worldTransform.columns.3.y
      guard abs(y - door.y) < 0.018 else { return }
      let start = SIMD3(door.x, y, door.z)
      for z: Float in [0.008, -0.002, 0.018] {
        let side = pose.convert(position: [-0.023, 0, z], to: nil)
        guard let spot = walkingSurface.position([side.x, y, side.z], from: start,
          vehiclePose: pose, hasSceneReconstruction: hasSceneReconstruction) else { continue }
        releaseInputs()
        physics.setPaused(true)
        let walker = RallyWalker()
        anchor.addChild(walker.root)
        outsideDoor = spot
        walker.root.setPosition(door, relativeTo: nil)
        equip(walker)
        avatar = walker
        mode = .exiting
        transitionTime = 0
        updateMessage()
        return
      }
      message.text = "Neben der Fahrertür ist kein freier Boden erkannt."
      message.isHidden = false
    case .onFoot:
      if let avatar, let item = district.pickup(at: avatar.root.position(relativeTo: nil)), inventory.pick(item) {
        district.collect(item)
        equip(avatar)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateMessage()
        return
      }
      if let avatar, let shop = district.inside ?? district.entry(at: avatar.root.position(relativeTo: nil)) {
        district.toggle(shop, walker: avatar.root)
        updateMessage()
        return
      }
      guard nearDoor, let avatar else { return }
      releaseInputs()
      outsideDoor = avatar.root.position(relativeTo: nil)
      mode = .entering
      transitionTime = 0
      updateMessage()
    default: break
    }
  }

  @MainActor private func tickWalking(_ dt: Float) {
    guard let avatar, settingsPanel.isHidden else { return }
    if mode == .entering || mode == .exiting {
      transitionTime += dt
      let t = min(1, transitionTime / 0.24)
      if let door {
        let progress = mode == .entering ? 1 - t : t
        avatar.root.setPosition(door + (outsideDoor - door) * progress, relativeTo: nil)
        avatar.animate(dt: dt, velocity: (outsideDoor - door) * (mode == .entering ? -4 : 4))
      }
      guard t >= 1 else { return }
      if mode == .entering {
        avatar.root.removeFromParent()
        self.avatar = nil
        inventory.enterVehicle()
        if inventory.wings, wingModel == nil, let wing = RallyItem.wings.model(), let pose = vehiclePose {
          wing.scale *= 2
          wing.position = [0,0.02,-0.006]
          pose.addChild(wing)
          wingModel = wing
          physics.wings(true)
        }
        mode = .driving
        calibrateSteering()
        physics.setPaused(false)
      } else { mode = .onFoot }
      updateMessage()
      return
    }
    let camera = arView.cameraTransform.matrix.columns.0
    let velocity = RallyWalking.velocity(input: walkInput, cameraRight: [camera.x, camera.y, camera.z])
    let start = avatar.root.position(relativeTo: nil)
    let previousPickup = district.pickup(at: start)
    let previousShop = district.entry(at: start)
    let wasNear = nearDoor
    if dt > 0, simd_length(velocity) > 0.001,
      let next = walkingSurface.position(start + velocity * dt, from: start,
        vehiclePose: vehiclePose, hasSceneReconstruction: hasSceneReconstruction) {
      guard district.permits(next) else { return }
      avatar.root.setPosition(next, relativeTo: nil)
      avatar.animate(dt: dt, velocity: velocity)
    } else { avatar.animate(dt: dt, velocity: .zero) }
    if previousPickup != district.pickup(at: avatar.root.position(relativeTo: nil)) || previousShop != district.entry(at: avatar.root.position(relativeTo: nil)) || wasNear != nearDoor { updateMessage() }
  }

  private func startDisplayLink() {
    displayLink?.invalidate()
    let target = DisplayLinkTarget()
    target.view = self
    let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }
  @MainActor private func frame(_ link: CADisplayLink) {
    updatePlacementCandidate()
    guard phase == .ready, let pose = vehiclePose else {
      previousTime = 0
      return
    }
    if mode != .driving {
      let dt = previousTime == 0 ? 0 : min(0.05, link.timestamp - previousTime)
      previousTime = link.timestamp
      tickWalking(Float(dt))
      return
    }
    guard placementPhysicsMode == .fullJolt, !physicsStepPending, !physicsFailed else { return }
    let dt = previousTime == 0 ? 0 : link.timestamp - previousTime
    previousTime = link.timestamp
    physicsStepPending = true
    let generation = placementGeneration
    physics.step(dt) { [weak self, weak pose] result in
      guard let self else { return }
      guard generation == self.placementGeneration else { return }
      self.physicsStepPending = false
      guard let pose, let visualRoot = self.vehicleVisualRoot, self.phase == .ready, self.mode == .driving else { return }
      guard case .success(let state) = result else {
        if case .failure(let error) = result { self.stopAfterPhysicsFailure(error) }
        return
      }
      guard let chassisTransform = state.chassis?.matrix,
        isFiniteTransform(chassisTransform), state.wheels.count == self.wheels.count,
        state.wheels.count == 4,
        state.wheels.enumerated().allSatisfy({ $0.offset == $0.element.wheelIndex && $0.element.matrix != nil })
      else {
        self.stopAfterPhysicsFailure(PhysicsFailure.invalidDecodedState(state))
        return
      }
      if let floorY = self.placementFloorY,
        state.groundedWheelCount == 0, chassisTransform.columns.3.y < floorY - 0.025
      {
        Self.logger.error("Lost floor contact at physics step \(state.simulationStep)")
        self.stopAfterPhysicsFailure(NSError(domain: "de.drivebot.jolt", code: 16, userInfo: [
          NSLocalizedDescriptionKey: "Bodenkontakt verloren. Fahrzeug bitte zurücksetzen."
        ]))
        return
      }
      self.applyVehicleTransforms(state, chassisTransform: chassisTransform, pose: pose,
                                  visualRoot: visualRoot)
      let airborne = self.inventory.wings && state.groundedWheelCount == 0
      if airborne != self.deployed, let wing = self.wingModel {
        self.deployed = airborne
        var transform = wing.transform
        transform.scale.x = RallyScale.factor * (airborne ? 7 : 2)
        wing.move(to: transform, relativeTo: wing.parent, duration: 0.18)
      }
      let wasStopped = self.lastSpeed <= 0.01
      self.lastSpeed = state.speedMetersPerSecond
      if wasStopped != (self.lastSpeed <= 0.01) { self.updateMessage() }
      self.pedals.observe(speed: state.speedMetersPerSecond, appliedBrake: state.appliedBrake)
      self.speed.text = String(format: "%.2f m/s", state.speedMetersPerSecond)
      if self.inventory.boosting {
        let p = chassisTransform.columns.3
        self.inventory.sample([p.x,p.z], elapsed: Float(dt), speed: state.speedMetersPerSecond)
        self.boostButton.setTitle("NOS " + String(Int(ceil(self.inventory.remaining * 10))) + "%", for: .normal)
        if !self.inventory.boosting { self.physics.boost(false); self.updateMessage() }
      }
      self.lastSuccessfulOperation = state.operation
      if state.collided { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
  }

  private func applyVehicleTransforms(
    _ state: DBJoltVehicleState, chassisTransform: simd_float4x4,
    pose: Entity, visualRoot: Entity
  ) {
    pose.setTransformMatrix(chassisTransform, relativeTo: nil)
    let inverseChassis = chassisTransform.inverse
    let scale = visualRoot.scale.x
    for (wheel, value) in zip(wheels, state.wheels) {
      guard let matrix = value.matrix else { continue }
      wheel.transform.matrix = rallyWheelModelTransform(
        chassisLocal: inverseChassis * matrix, visualScale: scale)
    }
  }

  private func stopAfterPhysicsFailure(_ error: Error) {
    guard !physicsFailed else { return }
    physicsFailed = true
    releaseInputs()
    physics.setPaused(true)
    displayLink?.isPaused = true
    phase = .interrupted
    let failure = error as? PhysicsFailure
    let report = PhysicsDiagnostics.make(
      vehicleID: vehicleID, error: error, failure: failure,
      lastSuccessfulOperation: lastSuccessfulOperation)
    PhysicsDiagnostics.save(report)
    message.text = "Physikfehler \(failure?.code ?? (error as NSError).code): \(error.localizedDescription)"
    message.isHidden = false
    Self.logger.error("Physics paused: \(error.localizedDescription, privacy: .public)")
  }

  private func updatePlacementCandidate() {
    guard phase == .aiming || phase == .scanning else {
      placementMarker?.isEnabled = false
      return
    }
    let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
    guard let hit = arView.raycast(
      from: center, allowing: .existingPlaneGeometry, alignment: .horizontal
    ).first(where: { result in
      guard let plane = result.anchor as? ARPlaneAnchor else { return false }
      return plane.extent.x > 0.3 && plane.extent.z > 0.3
    }), let plane = hit.anchor as? ARPlaneAnchor else {
      placementCandidate = nil
      placementPlane = nil
      placementMarker?.isEnabled = false
      if hasFloor { phase = .aiming }
      return
    }
    let position = SIMD3(
      hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y,
      hit.worldTransform.columns.3.z)
    guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return }
    placementCandidate = position
    placementPlane = plane
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

  @objc private func resumeIfTracked() {
    guard UIApplication.shared.applicationState == .active,
          let frame = arView.session.currentFrame,
          case .normal = frame.camera.trackingState else { return }
    trackingInterrupted = false
    guard !physicsFailed, phase == .interrupted else { return }
    physics.setPaused(mode != .driving)
    phase = carAnchor == nil ? (hasFloor ? .aiming : .scanning) : .ready
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    DispatchQueue.main.async {
      switch camera.trackingState {
      case .normal:
        self.resumeIfTracked()
      default: self.interrupted()
      }
    }
  }
  func sessionWasInterrupted(_ session: ARSession) {
    DispatchQueue.main.async { [weak self] in self?.interrupted() }
  }
  func sessionInterruptionEnded(_ session: ARSession) {
    Self.logger.notice("AR interruption ended; waiting for tracking recovery")
  }
  func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
    true
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
      if placementPlane?.identifier == anchor.identifier {
        placementCandidate = nil
        placementPlane = nil
        placementMarker?.isEnabled = false
      }
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
        if carAnchor == nil && !trackingInterrupted && !physicsFailed { phase = .aiming }
        installPlaneCollider(plane)
        visualizeFloor(plane)
        if phase == .ready, let car = vehiclePose?.position(relativeTo: nil) {
          district.expand(on: plane, in: arView, player: avatar?.root.position(relativeTo: nil) ?? car, car: car)
        }
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
    let center = plane.transform * SIMD4(plane.center.x, plane.center.y, plane.center.z, 1)
    let forward = plane.transform.columns.2
    var heading = atan2(forward.x, forward.z)
    var extent = SIMD2(plane.extent.x, plane.extent.z)
    if #available(iOS 16.0, *) {
      heading += plane.planeExtent.rotationOnYAxis
      extent = SIMD2(plane.planeExtent.width, plane.planeExtent.height)
    }
    physics.replaceFloor(at: [center.x, center.y, center.z], extent: extent,
                         heading: heading, identifier: plane.identifier)
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

private func isFiniteTransform(_ transform: simd_float4x4) -> Bool {
  (0..<4).allSatisfy { column in
    (0..<4).allSatisfy { row in transform[column][row].isFinite }
  }
}

private extension DBJoltTransform {
  var matrix: simd_float4x4? {
    let values = [positionX, positionY, positionZ, rotationX, rotationY, rotationZ, rotationW]
    guard values.allSatisfy(\.isFinite) else { return nil }
    let length = sqrt(rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ + rotationW * rotationW)
    guard length > 0.999, length < 1.001 else { return nil }
    var value = simd_float4x4(simd_quatf(ix: rotationX, iy: rotationY, iz: rotationZ, r: rotationW))
    value.columns.3 = SIMD4(positionX, positionY, positionZ, 1)
    return isFiniteTransform(value) ? value : nil
  }
}

private struct PhysicsFailure: LocalizedError {
  let code: Int
  let description: String
  let operation: String
  let simulationStep: Int
  let timeStep: Double
  let expectedWheels: Int
  let outputWheels: Int
  let transformsFinite: Bool
  var errorDescription: String? { description }

  static func invalidDecodedState(_ state: DBJoltVehicleState) -> PhysicsFailure {
    PhysicsFailure(code: 15, description: "Swift-Dekodierung ergab keinen vollständigen, eindeutig zugeordneten Fahrzeugzustand.",
      operation: "step.decode-state", simulationStep: state.simulationStep, timeStep: state.timeStep,
      expectedWheels: 4, outputWheels: state.wheels.count, transformsFinite: false)
  }
}

private enum PhysicsDiagnostics {
  private static let key = "DriveBot.lastPhysicsDiagnostic"
  static func make(vehicleID: String, error: Error, failure: PhysicsFailure?, lastSuccessfulOperation: String) -> String {
    let bundle = Bundle.main
    let appVersion = bundle.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "unbekannt"
    let buildNumber = bundle.object(
      forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? "unbekannt"
    let commit = bundle.object(
      forInfoDictionaryKey: "DriveBotCommit"
    ) as? String ?? "unbekannt"
    let nsError = error as NSError
    let operation = failure?.operation ?? "unbekannt"
    let transformsFinite = failure?.transformsFinite ?? false
    let transformsFiniteDescription = transformsFinite ? "ja" : "nein"
    return [
      "DriveBot Physikdiagnose",
      "App-Version: " + appVersion,
      "Buildnummer: " + buildNumber,
      "Commit: " + commit,
      "Fahrzeug-ID: \(vehicleID)",
      "Fehlercode: \(failure?.code ?? nsError.code)",
      "Fehlerbeschreibung: \(error.localizedDescription)",
      "Operation: " + operation,
      "Letzte erfolgreiche Operation: \(lastSuccessfulOperation)",
      "Simulationsschritt: \(failure?.simulationStep ?? -1)",
      "Zeitschritt: \(failure?.timeStep ?? 0)",
      "Räder erwartet/ausgegeben: \(failure?.expectedWheels ?? 4)/\(failure?.outputWheels ?? 0)",
      "Transformationen endlich: " + transformsFiniteDescription,
    ].joined(separator: "\n")
  }
  static func save(_ report: String) { UserDefaults.standard.set(report, forKey: key) }
  static func load() -> String? { UserDefaults.standard.string(forKey: key) }
}

struct RacingPedals {
  private enum BrakePress { case released, braking, reversing }

  private static let standstillSpeed: Float = 0.01
  private var gasPressed = false
  private var brakePress: BrakePress = .released
  private var reverseArmed = false

  var isReversing: Bool { brakePress == .reversing }
  var brake: Float { brakePress == .braking ? 1 : 0 }
  var throttle: Float {
    switch brakePress {
    case .released: return gasPressed ? 1 : 0
    case .braking: return 0
    case .reversing: return -1
    }
  }

  mutating func setGas(pressed: Bool) {
    gasPressed = pressed
    if pressed && brakePress == .released { reverseArmed = false }
  }

  mutating func pressBrake() {
    guard brakePress == .released else { return }
    brakePress = reverseArmed ? .reversing : .braking
    reverseArmed = false
  }

  mutating func releaseBrake(cancelled: Bool = false) {
    brakePress = .released
    if cancelled || gasPressed { reverseArmed = false }
  }

  mutating func observe(speed: Float, appliedBrake: Float) {
    if speed > Self.standstillSpeed {
      reverseArmed = false
    } else if brakePress == .braking && appliedBrake > 0 {
      reverseArmed = true
    }
  }
}

private struct PlacementContactError: LocalizedError {
  var errorDescription: String? {
    "Kein stabiler Bodenkontakt. Bitte eine freie Bodenfläche anvisieren."
  }
}

/// Owns every Jolt call on one queue. Completions return to the main thread, so
/// the physics boundary never mutates RealityKit or UIKit objects.
private final class SerializedJoltWorld {
  private let queue = DispatchQueue(label: "de.drivebot.physics", qos: .userInteractive)
  private let world = DBJoltWorld()

  func prepareVehicle(
    at position: SIMD3<Float>, heading: Float, profile: String,
    completion: @escaping (Result<DBJoltVehicleState, Error>) -> Void
  ) {
    queue.async { [world] in
      guard world.isOperational() else {
        let error = NSError(
          domain: "de.drivebot.jolt", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Die Jolt-Welt ist nicht bereit."])
        DispatchQueue.main.async { completion(.failure(error)) }
        return
      }
      ArRacingView.logger.notice("[Placement] 07 Jolt world ready")
      do {
        try world.prepareVehicle(at: position, heading: heading, profile: profile)
        // The zero-step snapshot cannot prove suspension contact. Let the
        // unloaded vehicle settle before handing control to the player.
        world.setPaused(false)
        let step = 1.0 / 60.0
        var state = world.step(step)
        for _ in 1..<30 where state.success && state.groundedWheelCount < 4 {
          state = world.step(step)
        }
        world.setPaused(true)
        if state.success && (state.groundedWheelCount < 4 ||
          (state.chassis?.positionY ?? -.infinity) < position.y)
        {
          throw PlacementContactError()
        }
        let result = Self.decode(state)
        if !state.success { world.removeVehicle() }
        DispatchQueue.main.async { completion(result) }
      } catch {
        world.removeVehicle()
        DispatchQueue.main.async { completion(.failure(error)) }
      }
    }
  }

  func removeVehicle() { queue.async { [world] in world.removeVehicle() } }
  func wings(_ enabled: Bool) { queue.async { [world] in world.setWingsInstalled(enabled) } }
  func boost(_ enabled: Bool) { queue.async { [world] in world.setBoostEnabled(enabled) } }
  func setPaused(_ paused: Bool) { queue.async { [world] in world.setPaused(paused) } }
  func setThrottle(_ throttle: Float, brake: Float, steering: Float) {
    queue.async { [world] in
      world.setThrottle(throttle, brake: brake, steering: steering)
    }
  }
  func step(_ elapsed: Double, completion: @escaping (Result<DBJoltVehicleState, Error>) -> Void) {
    queue.async { [world] in
      let state = world.step(elapsed)
      let result: Result<DBJoltVehicleState, Error>
      if state.success, state.wheels.count == 4, state.chassis != nil {
        result = .success(state)
      } else {
        result = Self.decode(state)
      }
      DispatchQueue.main.async { completion(result) }
    }
  }
  private static func decode(_ state: DBJoltVehicleState) -> Result<DBJoltVehicleState, Error> {
    if state.success, state.wheels.count == 4, state.chassis != nil { return .success(state) }
    return .failure(PhysicsFailure(
      code: state.errorCode, description: state.errorMessage ?? "Jolt lieferte keine Fehlerbeschreibung.",
      operation: state.operation, simulationStep: state.simulationStep, timeStep: state.timeStep,
      expectedWheels: state.expectedWheelCount, outputWheels: state.outputWheelCount,
      transformsFinite: state.transformsFinite))
  }
  func replaceStaticMesh(_ id: UUID, vertices: Data, indices: Data) {
    queue.async { [world] in world.replaceStaticMesh(id, vertices: vertices, indices: indices) }
  }
  func replaceFloor(at center: SIMD3<Float>, extent: SIMD2<Float>, heading: Float, identifier: UUID) {
    queue.async { [world] in
      world.replaceFloor(at: center, extent: extent, heading: heading, identifier: identifier)
    }
  }
  func removeStaticMesh(_ id: UUID) {
    queue.async { [world] in world.removeStaticMesh(id) }
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

enum SteeringInput {
  static let deadZone = sin(3.0 * .pi / 180.0)

  static func angle(_ input: Float, sensitivity: Float, inverted: Bool) -> Float {
    let scaled = input * max(0.5, min(2, sensitivity))
    return max(-1, min(1, inverted ? -scaled : scaled))
  }

  static func normalizedTilt(_ tilt: Double) -> Float {
    let magnitude = abs(tilt)
    guard magnitude > deadZone else { return 0 }
    let normalized = (magnitude - deadZone) / (sin(35.0 * .pi / 180.0) - deadZone)
    return Float(min(1, normalized)) * (tilt < 0 ? -1 : 1)
  }
}
