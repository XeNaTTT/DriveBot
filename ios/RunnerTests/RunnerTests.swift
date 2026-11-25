import Flutter
import DriveBotJolt
import RealityKit
import simd
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testPackedMeshLastVertexEndsAtBufferBoundary() {
    let coordinates = (0..<192).map { Float($0) }
    coordinates.withUnsafeBytes { bytes in
      XCTAssertEqual(bytes.count, 768)
      XCTAssertEqual(RallyMeshSnapshot.packedVertex(bytes, offset: 63 * 12), SIMD3(189, 190, 191))
    }
  }

  @MainActor func testMiniatureScaleAndBuildingClearances() {
    XCTAssertEqual(RallyScale.metres(6.5), 0.05, accuracy: 0.00001)
    XCTAssertLessThan(RallyScale.metres(1.8), RallyScale.metres(2.1))
    XCTAssertTrue(RallyDistrict.canReach([0.009,0,0], item: .zero))
    XCTAssertFalse(RallyDistrict.canReach([0.011,0,0], item: .zero))
    let far = SIMD3<Float>(1,0,0)
    XCTAssertTrue(RallyDistrict.clearSite(.zero, player: far, car: far, occupied: []))
    XCTAssertFalse(RallyDistrict.clearSite(.zero, player: .zero, car: far, occupied: []))
    XCTAssertFalse(RallyDistrict.clearSite(.zero, player: far, car: far, occupied: [[0.08,0,0]]))
  }

  func testBoostChangesEngineLimitAndRestoresItForEachVehicle() throws {
    let world = DBJoltWorld()
    for profile in ["compact","sport","offroad"] {
      try world.prepareVehicle(at: .zero, heading: 0, profile: profile)
      let baseline = world.step(0)
      XCTAssertTrue(baseline.success)
      XCTAssertGreaterThan(baseline.engineLimitRPM, 0)
      world.setBoostEnabled(true)
      XCTAssertEqual(world.step(0).engineLimitRPM, baseline.engineLimitRPM * 1.5)
      world.setBoostEnabled(false)
      XCTAssertEqual(world.step(0).engineLimitRPM, baseline.engineLimitRPM)
    }
  }

  @MainActor func testBundledArtLoadsWithPositiveBounds() throws {
    for name in ["compact","sport","offroad","RallyPilot","Shop0","Shop1","Shop2","Shop3","Item0","Item1","Item2","Item3"] {
      let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "RallyAssets"))
      let entity = try Entity.load(contentsOf: url)
      XCTAssertGreaterThan(entity.visualBounds(relativeTo: entity).extents.y, 0, name)
    }
  }

  @MainActor func testEntranceRangeUsesFrontAndMatchingFloor() {
    XCTAssertTrue(RallyDistrict.nearEntrance([0,0,RallyScale.metres(2)]))
    XCTAssertFalse(RallyDistrict.nearEntrance([0,0,RallyScale.metres(4)]))
    XCTAssertFalse(RallyDistrict.nearEntrance([0,0,-0.01]))
    XCTAssertFalse(RallyDistrict.nearEntrance([0,0.02,0]))
  }

  func testAutomaticVisitWaitsTwoSecondsFromActualEntry() {
    let threshold = SIMD3<Float>(0,0,0.02)
    let outside = SIMD3<Float>(0,0,0.04)
    var visit = RallyVisit(index: 2, start: [0.01,0,0.05], entry: threshold, exit: outside, began: 10)
    XCTAssertFalse(visit.sample(at: 10.1).hidden)
    XCTAssertTrue(visit.sample(at: 12).hidden)
    XCTAssertTrue(visit.sample(at: 13.999).hidden)
    let emerging = visit.sample(at: 14)
    XCTAssertFalse(emerging.hidden)
    XCTAssertFalse(emerging.done)
    XCTAssertEqual(emerging.position, threshold)
    let restored = visit.sample(at: 15)
    XCTAssertTrue(restored.done)
    XCTAssertEqual(restored.position, outside)
    var bag = RallyInventory()
    XCTAssertTrue(bag.pick(.blaster))
    XCTAssertFalse(bag.pick(.blaster))
    XCTAssertEqual(bag.held, .blaster)
  }

  func testTransportInstallConsumptionAndLanding() {
    var bag = RallyInventory()
    XCTAssertTrue(bag.pick(.nos))
    XCTAssertFalse(bag.pick(.nos))
    XCTAssertTrue(bag.pick(.wings))
    XCTAssertEqual(bag.remaining, 0)
    XCTAssertFalse(bag.shouldGlide(groundedWheels: 0))
    bag.enterVehicle()
    XCTAssertEqual(bag.remaining, 10)
    XCTAssertTrue(bag.shouldGlide(groundedWheels: 0))
    XCTAssertFalse(bag.shouldGlide(groundedWheels: 1))
    bag.boosting = true
    for step in 0...10 { bag.sample([Float(step) * 0.1,0], elapsed: 0.1, speed: 1) }
    XCTAssertEqual(bag.remaining, 9, accuracy: 0.0001)
    bag.sample([20,0], elapsed: 0.1, speed: 1)
    XCTAssertEqual(bag.remaining, 9, accuracy: 0.0001)
    bag.stopBoost()
    bag.sample([30,0], elapsed: 0.1, speed: 1)
    XCTAssertEqual(bag.remaining, 9, accuracy: 0.0001)
    bag.boosting = true
    for step in 0...100 { bag.sample([Float(step) * 0.1,0], elapsed: 0.1, speed: 1) }
    XCTAssertFalse(bag.boosting)
    bag.enterVehicle()
    XCTAssertEqual(bag.remaining, 0)
    XCTAssertTrue(bag.wings)
  }

  func testWalkingEquipmentSurvivesReentry() {
    var bag = RallyInventory()
    XCTAssertTrue(bag.pick(.sword))
    XCTAssertTrue(bag.pick(.blaster))
    bag.enterVehicle()
    XCTAssertEqual(bag.held, .blaster)
    bag.cycle()
    XCTAssertEqual(bag.held, .sword)
  }

  func testReverseRequiresReleasingBrakeAfterStandstillAndPressingAgain() {
    var pedals = RacingPedals()
    pedals.setGas(pressed: true)
    XCTAssertEqual(pedals.throttle, 1)
    pedals.pressBrake()
    XCTAssertEqual(pedals.throttle, 0)
    XCTAssertEqual(pedals.brake, 1)
    pedals.setGas(pressed: false)

    pedals.observe(speed: 0.2, appliedBrake: 1)
    pedals.releaseBrake()
    pedals.pressBrake()
    XCTAssertEqual(pedals.brake, 1)

    pedals.observe(speed: 0.005, appliedBrake: 1)
    pedals.pressBrake()
    XCTAssertFalse(pedals.isReversing)
    XCTAssertEqual(pedals.brake, 1)

    pedals.releaseBrake()
    pedals.pressBrake()
    XCTAssertTrue(pedals.isReversing)
    XCTAssertEqual(pedals.throttle, -1)
    XCTAssertEqual(pedals.brake, 0)

    pedals.releaseBrake()
    XCTAssertFalse(pedals.isReversing)
    XCTAssertEqual(pedals.throttle, 0)
    pedals.observe(speed: 0.2, appliedBrake: 0)
    pedals.pressBrake()
    XCTAssertEqual(pedals.brake, 1)
  }

  func testCancelledBrakePressAndResumingGasDisarmReverse() {
    var pedals = RacingPedals()
    pedals.pressBrake()
    pedals.observe(speed: 0, appliedBrake: 1)
    pedals.releaseBrake(cancelled: true)
    pedals.pressBrake()
    XCTAssertEqual(pedals.brake, 1)

    pedals.observe(speed: 0, appliedBrake: 1)
    pedals.releaseBrake()
    pedals.setGas(pressed: true)
    pedals.setGas(pressed: false)
    pedals.pressBrake()
    XCTAssertEqual(pedals.brake, 1)
  }

  func testHeldPedalsAccelerateCoastAndBrakeOnDetectedFloor() throws {
    let world = DBJoltWorld()
    let ground: SIMD3<Float> = [0.8, -1.1, -0.6]
    world.replaceFloor(at: ground, extent: [6, 6], heading: 0.4, identifier: UUID())
    try world.prepareVehicle(at: ground, heading: 0, profile: "compact")
    world.setPaused(false)
    func advance(_ frames: Int, file: StaticString = #filePath, line: UInt = #line) -> DBJoltVehicleState {
      var state = world.step(0)
      let initialStep = state.simulationStep
      for _ in 0..<frames {
        state = world.step(1.0 / 60.0)
        guard state.success else {
          XCTFail(state.errorMessage ?? "Jolt step failed", file: file, line: line)
          return state
        }
      }
      XCTAssertEqual(state.simulationStep, initialStep + frames, file: file, line: line)
      print("Pedal phase at line \(line): step=\(state.simulationStep) speed=\(state.speedMetersPerSecond) throttle=\(state.appliedThrottle) brake=\(state.appliedBrake) contacts=\(state.groundedWheelCount) z=\(String(describing: state.chassis?.positionZ))")
      return state
    }
    let parked = advance(60)
    XCTAssertEqual(parked.groundedWheelCount, 4)
    XCTAssertLessThan(parked.speedMetersPerSecond, 0.01)
    world.setThrottle(1, brake: 0, steering: 0)
    let early = advance(12)
    let accelerating = advance(24)
    XCTAssertEqual(accelerating.appliedThrottle, 1)
    XCTAssertGreaterThan(accelerating.speedMetersPerSecond, early.speedMetersPerSecond + 0.01)
    XCTAssertGreaterThan(try XCTUnwrap(accelerating.chassis).positionZ, ground.z + 0.01)
    world.setThrottle(0, brake: 0, steering: 0)
    let justReleased = advance(12)
    XCTAssertEqual(justReleased.appliedThrottle, 0)
    XCTAssertEqual(justReleased.appliedBrake, 0)
    XCTAssertGreaterThan(justReleased.speedMetersPerSecond, 0.01)
    XCTAssertGreaterThan(try XCTUnwrap(justReleased.chassis).positionZ,
                         try XCTUnwrap(accelerating.chassis).positionZ)
    // The driven wheels can still transfer momentum just after throttle release.
    // Measure deceleration over one second of coasting on the level floor.
    let coasting = advance(48)
    XCTAssertEqual(coasting.appliedThrottle, 0)
    XCTAssertEqual(coasting.appliedBrake, 0)
    XCTAssertGreaterThan(coasting.speedMetersPerSecond, 0.01)
    XCTAssertLessThan(coasting.speedMetersPerSecond, justReleased.speedMetersPerSecond)
    XCTAssertLessThan(coasting.speedMetersPerSecond, accelerating.speedMetersPerSecond)
    world.setThrottle(1, brake: 1, steering: 0)
    let stopped = advance(30)
    XCTAssertEqual(stopped.appliedThrottle, 0)
    XCTAssertEqual(stopped.appliedBrake, 1)
    XCTAssertLessThan(stopped.speedMetersPerSecond, coasting.speedMetersPerSecond * 0.5)
    world.setThrottle(0, brake: 0, steering: 0)
    let released = advance(30)
    XCTAssertEqual(released.appliedBrake, 0)
    XCTAssertLessThan(released.speedMetersPerSecond, 0.01)
    XCTAssertEqual(released.groundedWheelCount, 4)

    world.setThrottle(-1, brake: 0, steering: 0)
    let reversing = advance(90)
    XCTAssertTrue(reversing.success, reversing.errorMessage ?? "Reverse step failed")
    XCTAssertEqual(reversing.appliedThrottle, -1)
    XCTAssertEqual(reversing.appliedBrake, 0)
    XCTAssertGreaterThan(reversing.speedMetersPerSecond, 0.01)
    XCTAssertLessThan(try XCTUnwrap(reversing.chassis).positionZ,
                      try XCTUnwrap(released.chassis).positionZ - 0.01)
  }

  func testDetectedFloorSupportsAllMiniaturesAndCanBeRefined() throws {
    // A nonzero world origin and rotated finite surface match the AR path.
    let floor = SIMD3<Float>(0.82, -1.15, -0.63)
    for profile in ["compact", "sport", "offroad"] {
      let world = DBJoltWorld()
      let id = UUID()
      world.replaceFloor(at: floor, extent: [0.65, 0.44], heading: 0.48, identifier: id)
      try world.prepareVehicle(at: floor, heading: 0, profile: profile)
      world.setPaused(false)
      var state = world.step(1.0 / 60.0)
      for frame in 1...150 {
        if frame == 50 {
          world.replaceFloor(at: floor, extent: [0.82, 0.53], heading: 0.45, identifier: id)
        }
        state = world.step(1.0 / 60.0)
        XCTAssertTrue(state.success, state.errorMessage ?? profile)
        XCTAssertGreaterThan(try XCTUnwrap(state.chassis).positionY, floor.y)
      }
      XCTAssertEqual(state.groundedWheelCount, 4, profile)
    }
  }

  func testRallyWheelModelTransformScalesOffsetWithoutScalingWheelBasis() {
    var local = matrix_identity_float4x4
    local.columns.3 = SIMD4(0.0115, -0.006, 0.0165, 1)
    let model = rallyWheelModelTransform(chassisLocal: local, visualScale: 0.05)
    XCTAssertEqual(model.columns.0, local.columns.0)
    XCTAssertEqual(model.columns.1, local.columns.1)
    XCTAssertEqual(model.columns.2, local.columns.2)
    XCTAssertEqual(model.columns.3.x, 0.23, accuracy: 0.0001)
    XCTAssertEqual(model.columns.3.y, -0.12, accuracy: 0.0001)
    XCTAssertEqual(model.columns.3.z, 0.33, accuracy: 0.0001)
  }
  @MainActor
  func testRallyVehicleVisualsHaveDistinctBodiesAndFourWheelPivots() {
    let variants = [
      ("compact", "camper shell"),
      ("sport", "overcab berth"),
      ("offroad", "roof rack crossbar"),
    ]
    for (profile, feature) in variants {
      let visual = RallyVehicleVisual.build(profile: profile)
      XCTAssertNotNil(visual.root.findEntity(named: feature))
      XCTAssertEqual(visual.wheels.map(\.name),
                     ["front right", "front left", "rear right", "rear left"])
      for wheel in visual.wheels {
        XCTAssertTrue(wheel.parent === visual.root)
        XCTAssertGreaterThanOrEqual(wheel.children.count, 2)
      }
      let bounds = visual.root.visualBounds(relativeTo: visual.root)
      XCTAssertEqual(bounds.extents.z, 1, accuracy: 0.025)
      XCTAssertGreaterThan(bounds.max.y, 0.24)
      XCTAssertEqual(bounds.min.y, -0.22, accuracy: 0.005)
    }
  }

  func testAppleGeoProjectionUsesEastNorthAxes() throws {
    let projection = try XCTUnwrap(AppleGeoProjection(latitude: 52.52, longitude: 13.405))
    let east = try XCTUnwrap(projection.eastNorthMeters(latitude: 52.52, longitude: 13.406))
    let north = try XCTUnwrap(projection.eastNorthMeters(latitude: 52.521, longitude: 13.405))

    XCTAssertGreaterThan(east.east, 60)
    XCTAssertEqual(east.north, 0, accuracy: 0.01)
    XCTAssertGreaterThan(north.north, 100)
    XCTAssertEqual(north.east, 0, accuracy: 0.01)
  }

  func testAppleGeoProjectionUsesShortestDatelineDistance() throws {
    let projection = try XCTUnwrap(AppleGeoProjection(latitude: 0, longitude: 179.999))
    let offset = try XCTUnwrap(projection.eastNorthMeters(latitude: 0, longitude: -179.999))
    let distance = try XCTUnwrap(projection.distanceMeters(latitude: 0, longitude: -179.999))

    // A 0.002-degree equatorial arc is about 222.64 m on WGS84.
    // At the equator the parallel is also a geodesic.
    XCTAssertEqual(offset.east, 222.64, accuracy: 0.01)
    XCTAssertEqual(offset.north, 0, accuracy: 0.01)
    XCTAssertEqual(distance, offset.east, accuracy: 0.01)
    let reverse = try XCTUnwrap(AppleGeoProjection(latitude: 0, longitude: -179.999))
    let west = try XCTUnwrap(reverse.eastNorthMeters(latitude: 0, longitude: 179.999))
    XCTAssertEqual(west.east, -offset.east, accuracy: 0.01)
  }

  func testJoltBridgeProducesStableTypedStateAndCanReset() throws {
    let world = DBJoltWorld()
    XCTAssertTrue(world.isOperational())
    installGround(in: world)
    try world.prepareVehicle(at: SIMD3<Float>(0, 0, 0), heading: 0, profile: "compact")

    let first = world.step(0)
    assertCompleteFiniteState(first, expectedStep: 0)
    world.setPaused(false)

    world.setThrottle(1, brake: 0, steering: 0)
    var peakSpeed: Float = 0
    for step in 1...120 {
      let state = world.step(1.0 / 60.0)
      assertCompleteFiniteState(state, expectedStep: step)
      peakSpeed = max(peakSpeed, state.speedMetersPerSecond)
    }
    XCTAssertGreaterThan(peakSpeed, 0.001, "Throttle must move the real Jolt vehicle")

    world.setThrottle(1, brake: 0, steering: -1)
    let left = world.step(1.0 / 60.0)
    XCTAssertLessThan(left.appliedSteering, 0)
    world.setThrottle(1, brake: 0, steering: 1)
    let right = world.step(1.0 / 60.0)
    XCTAssertGreaterThan(right.appliedSteering, 0)

    let speedBeforeBrake = right.speedMetersPerSecond
    world.setThrottle(1, brake: 1, steering: 0)
    var braking = right
    for _ in 0..<60 { braking = world.step(1.0 / 60.0) }
    XCTAssertEqual(braking.appliedThrottle, 0)
    XCTAssertEqual(braking.appliedBrake, 1)
    XCTAssertLessThan(braking.speedMetersPerSecond, speedBeforeBrake)

    world.removeVehicle()
    let missing = world.step(1.0 / 60.0)
    XCTAssertFalse(missing.success)
    XCTAssertEqual(missing.errorCode, 11)
    XCTAssertTrue(missing.errorMessage?.contains("vier Räder") == true)

    try world.prepareVehicle(at: SIMD3<Float>(0, 0, 0), heading: 0, profile: "compact")
    assertCompleteFiniteState(world.step(0), expectedStep: 0)
  }

  func testFiveCentimetreVehicleHasOneChassisAndPlausibleWheelLayout() throws {
    let world = DBJoltWorld()
    installGround(in: world)
    try world.prepareVehicle(at: .zero, heading: 0, profile: "compact")
    let state = world.step(0)
    XCTAssertNotNil(state.chassis)
    XCTAssertEqual(state.wheels.count, 4)
    let xs = state.wheels.map(\.positionX)
    let zs = state.wheels.map(\.positionZ)
    XCTAssertLessThanOrEqual((xs.max() ?? 0) - (xs.min() ?? 0), 0.03)
    XCTAssertLessThanOrEqual((zs.max() ?? 0) - (zs.min() ?? 0), 0.04)

    world.setPaused(false)
    var settled = state
    for _ in 0..<120 { settled = world.step(1.0 / 60.0) }
    XCTAssertTrue(settled.success)
    XCTAssertGreaterThan(try XCTUnwrap(settled.chassis).positionY, 0)
  }

  @MainActor func testRepeatedPulsesPreserveWalkingAndDoorEligibility() throws {
    let effects = RallyPulseEffects()
    let stick = SIMD2<Float>(0.3,-0.8)
    let right = SIMD3<Float>(1,0,0)
    let walking = RallyWalking.velocity(input: stick, cameraRight: right)
    XCTAssertGreaterThan(simd_length(walking),0)
    for (time, accepted) in [(1.0,true),(1.01,false),(1.2,true),(1.4,true)] {
      XCTAssertEqual(effects.acceptShot(at: time), accepted)
      let retained = RallyWalking.horizontalRight([0,1,0], previous: right)
      XCTAssertEqual(RallyWalking.velocity(input: stick, cameraRight: retained), walking)
    }
    XCTAssertTrue(RallyWalking.canEnter(distance: 0.02, localX: -0.023))
    let heading = try XCTUnwrap(RallyPulseEffects.heading([3,0,4]))
    XCTAssertEqual(heading.y, 0)
    XCTAssertEqual(RallyPulseEffects.heading([3,8,4]),heading)
    XCTAssertEqual(RallyPulseEffects.heading([3,-12,4]),heading)
    XCTAssertNil(RallyPulseEffects.heading([0,1,0]))
  }

  func testWalkerUsesCameraAxesAndDoorSide() {
    let forward = RallyWalking.velocity(input: [0,-1], cameraRight: [0,0,1])
    XCTAssertEqual(forward.x, 0.026, accuracy: 0.0001)
    XCTAssertEqual(forward.y, 0)
    let diagonal = RallyWalking.velocity(input: [1,1], cameraRight: [1,0,0])
    XCTAssertEqual(simd_length(diagonal), 0.026, accuracy: 0.0001)
    XCTAssertEqual(RallyWalking.velocity(input: .zero, cameraRight: [1,0,0]), .zero)
    XCTAssertTrue(RallyWalking.canEnter(distance: 0.02, localX: -0.023))
    XCTAssertFalse(RallyWalking.canEnter(distance: 0.04, localX: -0.023))
    XCTAssertFalse(RallyWalking.canEnter(distance: 0.02, localX: 0.023))
  }

  @MainActor
  func testSteeringPanelPersistsControlEventsAndCloses() throws {
    let suite = UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = RallySteeringPreferences(defaults: defaults)
    var closed = false
    let panel = RallySteeringPanel(controls: preferences) { closed = true }
    let row = try XCTUnwrap(panel.arrangedSubviews.compactMap { $0 as? UIStackView }.first)
    let toggle = try XCTUnwrap(row.arrangedSubviews.compactMap { $0 as? UISwitch }.first)
    let slider = try XCTUnwrap(panel.arrangedSubviews.compactMap { $0 as? UISlider }.first)
    toggle.isOn = true
    toggle.sendActions(for: .valueChanged)
    slider.value = 2
    slider.sendActions(for: .valueChanged)
    let restored = RallySteeringPreferences(defaults: defaults)
    XCTAssertTrue(restored.inverted)
    XCTAssertEqual(restored.sensitivity, 2)
    let done = try XCTUnwrap(panel.arrangedSubviews.compactMap { $0 as? UIButton }.first)
    done.sendActions(for: .touchUpInside)
    XCTAssertTrue(closed)
  }

  func testSteeringPreferencesSurviveRecreation() throws {
    let suite = UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let initial = RallySteeringPreferences(defaults: defaults)
    XCTAssertEqual(initial.sensitivity, 1)
    XCTAssertFalse(initial.inverted)
    initial.inverted = true
    initial.sensitivity = 1.5
    let restored = RallySteeringPreferences(defaults: defaults)
    XCTAssertTrue(restored.inverted)
    XCTAssertEqual(restored.sensitivity, 1.5)
  }

  func testSteeringGainAndInversionSaturateInBothDirections() {
    XCTAssertEqual(SteeringInput.angle(0.5, sensitivity: 0.5, inverted: false), 0.25)
    XCTAssertEqual(SteeringInput.angle(0.5, sensitivity: 1, inverted: false), 0.5)
    XCTAssertEqual(SteeringInput.angle(0.5, sensitivity: 1.5, inverted: true), -0.75)
    XCTAssertEqual(SteeringInput.angle(-0.9, sensitivity: 2, inverted: true), 1)
  }

  func testSteeringMappingDeadZoneAndBothLandscapeSigns() {
    XCTAssertEqual(SteeringInput.normalizedTilt(0), 0)
    XCTAssertEqual(SteeringInput.normalizedTilt(SteeringInput.deadZone * 0.5), 0)
    XCTAssertLessThan(SteeringInput.normalizedTilt(-0.3), 0)
    XCTAssertGreaterThan(SteeringInput.normalizedTilt(0.3), 0)
  }

  private func installGround(in world: DBJoltWorld) {
    let vertices: [SIMD3<Float>] = [[-5, 0, -5], [5, 0, -5], [5, 0, 5], [-5, 0, 5]]
    let indices: [UInt32] = [0, 2, 1, 0, 3, 2]
    world.replaceStaticMesh(UUID(), vertices: vertices.withUnsafeBytes { Data($0) },
      indices: indices.withUnsafeBytes { Data($0) })
  }

  private func assertCompleteFiniteState(_ state: DBJoltVehicleState, expectedStep: Int) {
    XCTAssertTrue(state.success, state.errorMessage ?? "Jolt step failed")
    XCTAssertEqual(state.simulationStep, expectedStep)
    XCTAssertNotNil(state.chassis)
    XCTAssertTrue(isFinite(state.chassis!))
    XCTAssertEqual(state.expectedWheelCount, 4)
    XCTAssertEqual(state.outputWheelCount, 4)
    XCTAssertEqual(state.wheels.map(\.wheelIndex), [0, 1, 2, 3])
    XCTAssertTrue(state.transformsFinite)
    for wheel in state.wheels { XCTAssertTrue(isFinite(wheel)) }
  }

  private func isFinite(_ value: DBJoltTransform) -> Bool {
    [value.positionX, value.positionY, value.positionZ, value.rotationX,
      value.rotationY, value.rotationZ, value.rotationW].allSatisfy { $0.isFinite }
  }

  func testInvalidScalarBridgeDataIsDetectableBySwift() {
    let value = DBJoltTransform()
    value.rotationW = .nan
    XCTAssertFalse(isFinite(value))
    let norm = value.rotationX * value.rotationX + value.rotationY * value.rotationY
      + value.rotationZ * value.rotationZ + value.rotationW * value.rotationW
    XCTAssertFalse(norm.isFinite)
  }

  func testStepWithoutVehicleReturnsSpecificBridgeError() {
    let state = DBJoltWorld().step(1.0 / 60.0)
    XCTAssertFalse(state.success)
    XCTAssertEqual(state.errorCode, 11)
    XCTAssertEqual(state.operation, "step.validate-vehicle")
    XCTAssertEqual(state.expectedWheelCount, 4)
    XCTAssertEqual(state.outputWheelCount, 0)
  }

}
