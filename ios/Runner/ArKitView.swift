import ARKit
import Flutter
import UIKit

final class ArKitView: NSObject, FlutterPlatformView, ARSessionDelegate {
  private let sceneView: ARSCNView
  private var sessionStarted = false

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
    sessionStarted = true
    trackingQuality = "stable"
  }

  func pauseSession() {
    sceneView.session.pause()
    sessionStarted = false
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
