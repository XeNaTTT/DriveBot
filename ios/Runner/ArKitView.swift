import ARKit
import Flutter
import UIKit

final class ArKitView: NSObject, FlutterPlatformView, ARSessionDelegate {
  private let sceneView: ARSCNView
  private var sessionStarted = false
  private var anchorsById: [String: ARAnchor] = [:]
  private var lastAnchorPositions: [String: SCNVector3] = [:]

  var isRunning: Bool { sessionStarted }
  var trackingQuality: String = "stable"

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
    lastAnchorPositions.removeAll()
    sessionStarted = true
    trackingQuality = "stable"
  }

  func pauseSession() {
    sceneView.session.pause()
    anchorsById.removeAll()
    lastAnchorPositions.removeAll()
    sessionStarted = false
  }

  func syncAnchors(_ payloads: [[String: Any]]) -> [[String: Any]] {
    guard sessionStarted, trackingQuality != "unavailable" else {
      return payloads.compactMap { payload in
        guard let id = payload["id"] as? String else { return nil }
        return [
          "id": id,
          "isAnchored": false,
          "trackingQuality": trackingQuality,
          "message": "AR nicht verfügbar"
        ]
      }
    }

    let incomingIds = Set(payloads.compactMap { $0["id"] as? String })
    let staleIds = anchorsById.keys.filter { !incomingIds.contains($0) }
    for id in staleIds {
      if let anchor = anchorsById[id] {
        sceneView.session.remove(anchor: anchor)
      }
      anchorsById.removeValue(forKey: id)
      lastAnchorPositions.removeValue(forKey: id)
    }

    return payloads.compactMap { payload in
      guard
        let id = payload["id"] as? String,
        let x = payload["x"] as? NSNumber,
        let y = payload["y"] as? NSNumber,
        let z = payload["z"] as? NSNumber
      else { return nil }

      let position = SCNVector3(x.floatValue, y.floatValue, z.floatValue)
      if shouldUpdateAnchor(id: id, position: position) {
        if let existing = anchorsById[id] {
          sceneView.session.remove(anchor: existing)
        }
        var transform = matrix_identity_float4x4
        transform.columns.3.x = position.x
        transform.columns.3.y = position.y
        transform.columns.3.z = position.z
        let anchor = ARAnchor(name: id, transform: transform)
        sceneView.session.add(anchor: anchor)
        anchorsById[id] = anchor
        lastAnchorPositions[id] = position
      }

      return [
        "id": id,
        "isAnchored": anchorsById[id] != nil && trackingQuality == "stable",
        "trackingQuality": trackingQuality,
        "distanceMeters": payload["distanceMeters"] ?? 0
      ]
    }
  }

  private func shouldUpdateAnchor(id: String, position: SCNVector3) -> Bool {
    guard let previous = lastAnchorPositions[id] else { return true }
    let dx = position.x - previous.x
    let dy = position.y - previous.y
    let dz = position.z - previous.z
    let delta = sqrt(dx * dx + dy * dy + dz * dz)
    return delta > 5.0
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
}
