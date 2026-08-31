import ARKit
import CoreLocation
import Flutter
import MapKit
import UIKit

private struct GeoSessionOrigin {
  let projection: AppleGeoProjection
  let altitude: Double
  let headingDegrees: Double
  let recalibratedAt: Date
}

/// Converts geographic coordinates with Apple's optimized MapKit projection.
///
/// Keeping the projected origin and scale in one immutable value avoids
/// repeating trigonometry for every anchor during every Flutter sync.
struct AppleGeoProjection {
  let originCoordinate: CLLocationCoordinate2D

  private let originLocation: CLLocation
  private let originPoint: MKMapPoint
  private let metersPerMapPoint: CLLocationDistance

  init?(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

    originCoordinate = coordinate
    originLocation = CLLocation(latitude: latitude, longitude: longitude)
    originPoint = MKMapPoint(coordinate)
    metersPerMapPoint = MKMetersPerMapPointAtLatitude(latitude)
  }

  func eastNorthMeters(
    latitude: CLLocationDegrees,
    longitude: CLLocationDegrees
  ) -> (east: CLLocationDistance, north: CLLocationDistance)? {
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

    let targetPoint = MKMapPoint(coordinate)
    var deltaX = targetPoint.x - originPoint.x
    let worldWidth = MKMapSize.world.width
    if deltaX > worldWidth / 2 { deltaX -= worldWidth }
    if deltaX < -worldWidth / 2 { deltaX += worldWidth }

    return (
      east: deltaX * metersPerMapPoint,
      north: -(targetPoint.y - originPoint.y) * metersPerMapPoint
    )
  }

  func distanceMeters(
    latitude: CLLocationDegrees,
    longitude: CLLocationDegrees
  ) -> CLLocationDistance? {
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
    return originLocation.distance(from: CLLocation(latitude: latitude, longitude: longitude))
  }
}

private struct GeoAnchorPayload {
  let id: String
  let x: Float
  let y: Float
  let z: Float
  let distanceMeters: Double
  let currentLatitude: Double?
  let currentLongitude: Double?
  let currentAltitude: Double?
  let currentHeadingDegrees: Double?
  let targetLatitude: Double?
  let targetLongitude: Double?
  let targetAltitude: Double?
  let type: String?
}

private struct GeoAnchorRecord {
  var anchor: ARAnchor
  var position: SIMD3<Float>
  var lastProjectedPoint: CGPoint?
  var lastRecalibratedAt: Date
}

final class ArKitView: NSObject, FlutterPlatformView, ARSessionDelegate {
  private let sceneView: ARSCNView
  private var sessionStarted = false
  private var anchorsById: [String: GeoAnchorRecord] = [:]
  private var sessionOrigin: GeoSessionOrigin?
  private var lastTrackingQuality = "stable"

  private let movementRecalibrationThresholdMeters = 5.0
  private let headingRecalibrationThresholdDegrees = 8.0
  private let anchorUpdateThresholdMeters: Float = 2.0
  private let smoothingFactor: CGFloat = 0.32
  private let horizonHeightMeters: Float = 0.0

  var isRunning: Bool { sessionStarted }
  var trackingQuality: String = "stable"
  var devicePitchDegrees: Double? {
    currentCameraEulerDegrees?.pitch
  }
  var deviceRollDegrees: Double? {
    currentCameraEulerDegrees?.roll
  }

  private var currentCameraEulerDegrees: (pitch: Double, roll: Double)? {
    guard let frame = sceneView.session.currentFrame else { return nil }
    let euler = frame.camera.eulerAngles
    return (
      pitch: Double(euler.x) * 180.0 / Double.pi,
      roll: Double(euler.z) * 180.0 / Double.pi
    )
  }

  init(frame: CGRect, viewIdentifier viewId: Int64, messenger: FlutterBinaryMessenger) {
    sceneView = ARSCNView(frame: frame)
    super.init()
    sceneView.backgroundColor = UIColor.black
    sceneView.automaticallyUpdatesLighting = false
    sceneView.session.delegate = self
    ArKitRuntimeController.shared.attach(self)
  }

  deinit {
    pauseSession()
    ArKitRuntimeController.shared.detach(self)
  }

  func view() -> UIView {
    sceneView
  }

  func startSession() {
    guard ArKitRuntimeController.shared.isSupported else {
      trackingQuality = "unavailable"
      return
    }

    let configuration = ARWorldTrackingConfiguration()
    configuration.worldAlignment = .gravityAndHeading
    configuration.planeDetection = []
    sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    anchorsById.removeAll()
    sessionOrigin = nil
    sessionStarted = true
    trackingQuality = "stable"
    lastTrackingQuality = trackingQuality
  }

  func pauseSession() {
    sceneView.session.pause()
    anchorsById.removeAll()
    sessionOrigin = nil
    sessionStarted = false
  }

  func syncAnchors(_ payloads: [[String: Any]]) -> [[String: Any]] {
    let parsed = payloads.compactMap(Self.payload(from:))
    guard sessionStarted, trackingQuality != "unavailable" else {
      return parsed.map { payload in
        statePayload(
          id: payload.id,
          isAnchored: false,
          distanceMeters: payload.distanceMeters,
          projectionSource: "fallback",
          isVisible: false,
          hiddenReason: "tracking",
          trackingConfidence: 0,
          message: "AR nicht verfügbar"
        )
      }
    }

    recalibrateIfNeeded(for: parsed)
    removeStaleAnchors(keeping: Set(parsed.map(\.id)))

    return parsed.map { payload in
      let position = worldPosition(for: payload)
      upsertAnchor(id: payload.id, position: position)
      return projectedState(for: payload, position: position)
    }
  }

  private static func payload(from payload: [String: Any]) -> GeoAnchorPayload? {
    guard
      let id = payload["id"] as? String,
      let x = payload["x"] as? NSNumber,
      let y = payload["y"] as? NSNumber,
      let z = payload["z"] as? NSNumber
    else { return nil }

    return GeoAnchorPayload(
      id: id,
      x: x.floatValue,
      y: y.floatValue,
      z: z.floatValue,
      distanceMeters: (payload["distanceMeters"] as? NSNumber)?.doubleValue ?? 0,
      currentLatitude: (payload["currentLatitude"] as? NSNumber)?.doubleValue,
      currentLongitude: (payload["currentLongitude"] as? NSNumber)?.doubleValue,
      currentAltitude: (payload["currentAltitude"] as? NSNumber)?.doubleValue,
      currentHeadingDegrees: (payload["currentHeadingDegrees"] as? NSNumber)?.doubleValue,
      targetLatitude: (payload["targetLatitude"] as? NSNumber)?.doubleValue,
      targetLongitude: (payload["targetLongitude"] as? NSNumber)?.doubleValue,
      targetAltitude: (payload["targetAltitude"] as? NSNumber)?.doubleValue,
      type: payload["type"] as? String
    )
  }

  private func recalibrateIfNeeded(for payloads: [GeoAnchorPayload]) {
    guard let first = payloads.first,
      let latitude = first.currentLatitude,
      let longitude = first.currentLongitude
    else { return }

    let altitude = first.currentAltitude ?? 0
    let heading = first.currentHeadingDegrees ?? 0
    let shouldReset: Bool
    if let origin = sessionOrigin {
      let moved = origin.projection.distanceMeters(
        latitude: latitude,
        longitude: longitude
      ) ?? .infinity
      let headingDelta = abs(Self.normalizedAngle(heading - origin.headingDegrees))
      shouldReset = moved > movementRecalibrationThresholdMeters ||
        headingDelta > headingRecalibrationThresholdDegrees ||
        lastTrackingQuality != trackingQuality
    } else {
      shouldReset = true
    }

    guard shouldReset else { return }
    guard let projection = AppleGeoProjection(latitude: latitude, longitude: longitude) else {
      return
    }
    sessionOrigin = GeoSessionOrigin(
      projection: projection,
      altitude: altitude,
      headingDegrees: heading,
      recalibratedAt: Date()
    )
    lastTrackingQuality = trackingQuality
  }

  private func removeStaleAnchors(keeping incomingIds: Set<String>) {
    for id in anchorsById.keys.filter({ !incomingIds.contains($0) }) {
      sceneView.session.remove(anchor: anchorsById[id]!.anchor)
      anchorsById.removeValue(forKey: id)
    }
  }

  private func worldPosition(for payload: GeoAnchorPayload) -> SIMD3<Float> {
    guard let origin = sessionOrigin,
      let targetLatitude = payload.targetLatitude,
      let targetLongitude = payload.targetLongitude
    else {
      return SIMD3<Float>(payload.x, payload.y, payload.z)
    }

    guard let enu = origin.projection.eastNorthMeters(
      latitude: targetLatitude,
      longitude: targetLongitude
    ) else {
      return SIMD3<Float>(payload.x, payload.y, payload.z)
    }
    let up: Float
    if let targetAltitude = payload.targetAltitude {
      up = Float(targetAltitude - origin.altitude)
    } else {
      up = horizonHeightMeters
    }
    return SIMD3<Float>(Float(enu.east), up, -Float(enu.north))
  }

  private func upsertAnchor(id: String, position: SIMD3<Float>) {
    if let record = anchorsById[id], simd_distance(record.position, position) <= anchorUpdateThresholdMeters {
      return
    }

    if let existing = anchorsById[id] {
      sceneView.session.remove(anchor: existing.anchor)
    }

    var transform = matrix_identity_float4x4
    transform.columns.3.x = position.x
    transform.columns.3.y = position.y
    transform.columns.3.z = position.z
    let anchor = ARAnchor(name: id, transform: transform)
    sceneView.session.add(anchor: anchor)
    anchorsById[id] = GeoAnchorRecord(
      anchor: anchor,
      position: position,
      lastProjectedPoint: anchorsById[id]?.lastProjectedPoint,
      lastRecalibratedAt: Date()
    )
  }

  private func projectedState(for payload: GeoAnchorPayload, position: SIMD3<Float>) -> [String: Any] {
    guard trackingQuality == "stable" else {
      return statePayload(
        id: payload.id,
        isAnchored: anchorsById[payload.id] != nil,
        distanceMeters: payload.distanceMeters,
        projectionSource: "native",
        isVisible: false,
        hiddenReason: "tracking",
        trackingConfidence: trackingConfidence,
        message: "Tracking eingeschränkt"
      )
    }

    guard let frame = sceneView.session.currentFrame else {
      return statePayload(
        id: payload.id,
        isAnchored: anchorsById[payload.id] != nil,
        distanceMeters: payload.distanceMeters,
        projectionSource: "fallback",
        isVisible: false,
        hiddenReason: "tracking",
        trackingConfidence: trackingConfidence,
        message: "ARFrame nicht verfügbar"
      )
    }

    let cameraSpace = simd_inverse(frame.camera.transform) * SIMD4<Float>(position.x, position.y, position.z, 1)
    guard cameraSpace.z < 0 else {
      return statePayload(
        id: payload.id,
        isAnchored: anchorsById[payload.id] != nil,
        distanceMeters: payload.distanceMeters,
        projectionSource: "native",
        isVisible: false,
        hiddenReason: "fov",
        trackingConfidence: trackingConfidence
      )
    }

    let viewportSize = sceneView.bounds.size
    let projected = frame.camera.projectPoint(
      position,
      orientation: interfaceOrientation,
      viewportSize: viewportSize
    )
    guard projected.x.isFinite, projected.y.isFinite else {
      return statePayload(
        id: payload.id,
        isAnchored: anchorsById[payload.id] != nil,
        distanceMeters: payload.distanceMeters,
        projectionSource: "native",
        isVisible: false,
        hiddenReason: "fov",
        trackingConfidence: trackingConfidence
      )
    }

    let margin: CGFloat = 80
    guard projected.x >= -margin,
      projected.x <= viewportSize.width + margin,
      projected.y >= -margin,
      projected.y <= viewportSize.height + margin,
      viewportSize.width > 0,
      viewportSize.height > 0
    else {
      return statePayload(
        id: payload.id,
        isAnchored: anchorsById[payload.id] != nil,
        distanceMeters: payload.distanceMeters,
        projectionSource: "native",
        isVisible: false,
        hiddenReason: "fov",
        trackingConfidence: trackingConfidence
      )
    }

    let smoothed = smoothProjectedPoint(projected, id: payload.id)
    return statePayload(
      id: payload.id,
      isAnchored: anchorsById[payload.id] != nil,
      distanceMeters: payload.distanceMeters,
      projectionSource: "native",
      normalizedX: Double((smoothed.x / viewportSize.width).clamped(to: 0...1)),
      top: Double((smoothed.y / viewportSize.height).clamped(to: 0...1)),
      isVisible: true,
      trackingConfidence: trackingConfidence
    )
  }

  private var interfaceOrientation: UIInterfaceOrientation {
    if let orientation = sceneView.window?.windowScene?.interfaceOrientation {
      return orientation
    }
    return .portrait
  }

  private var trackingConfidence: Double {
    switch trackingQuality {
    case "stable": return 1.0
    case "limited": return 0.35
    default: return 0.0
    }
  }

  private func smoothProjectedPoint(_ point: CGPoint, id: String) -> CGPoint {
    guard var record = anchorsById[id] else { return point }
    let previous = record.lastProjectedPoint ?? point
    let smoothed = CGPoint(
      x: previous.x + (point.x - previous.x) * smoothingFactor,
      y: previous.y + (point.y - previous.y) * smoothingFactor
    )
    record.lastProjectedPoint = smoothed
    anchorsById[id] = record
    return smoothed
  }

  private func statePayload(
    id: String,
    isAnchored: Bool,
    distanceMeters: Double,
    projectionSource: String,
    normalizedX: Double? = nil,
    top: Double? = nil,
    isVisible: Bool,
    hiddenReason: String? = nil,
    trackingConfidence: Double,
    message: String? = nil
  ) -> [String: Any] {
    var result: [String: Any] = [
      "id": id,
      "isAnchored": isAnchored,
      "trackingQuality": trackingQuality,
      "distanceMeters": distanceMeters,
      "projectionSource": projectionSource,
      "isVisible": isVisible,
      "trackingConfidence": trackingConfidence,
      "lastRecalibrationAgeSeconds": lastRecalibrationAgeSeconds(for: id)
    ]
    if let normalizedX { result["normalizedX"] = normalizedX }
    if let top { result["top"] = top }
    if let hiddenReason { result["hiddenReason"] = hiddenReason }
    if let message { result["message"] = message }
    return result
  }

  private func lastRecalibrationAgeSeconds(for id: String) -> Double {
    let date = sessionOrigin?.recalibratedAt ?? anchorsById[id]?.lastRecalibratedAt ?? Date()
    return Date().timeIntervalSince(date)
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    switch camera.trackingState {
    case .normal:
      trackingQuality = "stable"
    case .notAvailable:
      trackingQuality = "unavailable"
    case .limited:
      trackingQuality = "limited"
    }
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    trackingQuality = "limited"
    sessionStarted = false
  }

  private static func normalizedAngle(_ degrees: Double) -> Double {
    var normalized = degrees.truncatingRemainder(dividingBy: 360)
    if normalized > 180 { normalized -= 360 }
    if normalized < -180 { normalized += 360 }
    return normalized
  }

}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
