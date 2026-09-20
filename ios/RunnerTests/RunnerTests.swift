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

  func testJoltVehicleProducesFourFiniteWheelTransformsForTenSteps() throws {
    let world = DBJoltWorld()
    XCTAssertTrue(world.isOperational())
    try world.prepareVehicle(at: SIMD3<Float>(0, 1, 0), heading: 0, profile: "compact")
    world.setPaused(false)

    for _ in 0..<10 {
      let state = world.step(1.0 / 60.0)
      XCTAssertTrue(state.success, state.errorMessage ?? "Jolt step failed")
      XCTAssertTrue(isFiniteMatrix(state.chassisTransform))
      XCTAssertEqual(state.wheelTransforms.count, 4)
      for value in state.wheelTransforms {
        var transform = matrix_identity_float4x4
        value.getValue(&transform)
        XCTAssertTrue(isFiniteMatrix(transform))
      }
    }
  }

  private func isFiniteMatrix(_ matrix: simd_float4x4) -> Bool {
    (0..<4).allSatisfy { column in
      (0..<4).allSatisfy { row in matrix[column][row].isFinite }
    }
  }

}
