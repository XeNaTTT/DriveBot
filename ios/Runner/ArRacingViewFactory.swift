import Flutter
import UIKit
import RealityKit
import Combine

final class ArRacingViewFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let parameters = args as? [String: Any]
    return ArRacingView(
      frame: frame,
      viewIdentifier: viewId, messenger: messenger,
      vehicleID: parameters?["vehicleID"] as? String ?? "compact")
  }
}

/// The garage uses the race model and its wheel rig without starting an AR session.
final class RallyShowroomFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier: Int64, arguments args: Any?) -> FlutterPlatformView {
    let profile = (args as? [String: Any])?["vehicleID"] as? String ?? "compact"
    return MainActor.assumeIsolated { RallyShowroom(frame: frame, profile: profile) }
  }
}

private final class RallyShowroom: NSObject, FlutterPlatformView {
  private let stage: ARView
  private var rotation: Cancellable?

  @MainActor init(frame: CGRect, profile: String) {
    stage = ARView(frame: frame, cameraMode: .nonAR, automaticallyConfigureSession: false)
    super.init()
    stage.environment.background = .color(UIColor(red: 0.052, green: 0.096, blue: 0.11, alpha: 1))
    let anchor = AnchorEntity(world: SIMD3<Float>.zero)
    let model = RallyVehicleVisual.build(profile: profile).root
    anchor.addChild(model)
    let camera = PerspectiveCamera()
    camera.camera.fieldOfViewInDegrees = 35
    camera.look(at: [0,0.08,0], from: [1.25,0.68,0.94], relativeTo: nil)
    anchor.addChild(camera)
    let key = DirectionalLight()
    key.light.color = UIColor(red: 1, green: 0.85, blue: 0.70, alpha: 1)
    key.light.intensity = 4200
    key.look(at: .zero, from: [2,3,2], relativeTo: nil)
    anchor.addChild(key)
    stage.scene.addAnchor(anchor)
    rotation = stage.scene.subscribe(to: SceneEvents.Update.self) { [weak model] tick in
      model?.orientation *= simd_quatf(angle: Float(tick.deltaTime) * 0.18, axis: [0,1,0])
    }
  }

  func view() -> UIView { stage }
}
