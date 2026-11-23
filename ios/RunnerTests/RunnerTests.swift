import Flutter
import DriveBotJolt
import RealityKit
import simd
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testHeldPedalsAccelerateCoastAndBrakeOnDetectedFloor() throws {
    let world = DBJoltWorld()
    let ground: SIMD3<Float> = [0.8, -1.1, -0.6]
    world.replaceFloor(at: ground, extent: [6, 6], heading: 0.4, identifier: UUID())
    try world.prepareVehicle(at: ground, heading: 0, profile: "compact")
    world.setPaused(false)
    func advance(_ frames: Int) -> DBJoltVehicleState {
      var state = world.step(0)
      for _ in 0..<frames { state = world.step(1.0 / 60.0) }
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
    let coasting = advance(12)
    XCTAssertEqual(coasting.appliedThrottle, 0)
    XCTAssertGreaterThan(coasting.speedMetersPerSecond, 0.01)
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

    XCTAssertGreaterThan(offset.east, 200)
    XCTAssertLessThan(offset.east, 230)
    XCTAssertEqual(distance, offset.east, accuracy: 0.01)
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
