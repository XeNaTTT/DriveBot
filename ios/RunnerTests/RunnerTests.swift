import Flutter
import DriveBotJolt
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

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
