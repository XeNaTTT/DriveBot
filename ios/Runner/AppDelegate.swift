import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let permissionChannel = FlutterMethodChannel(
        name: "drivebot/camera_permission",
        binaryMessenger: controller.binaryMessenger
      )
      permissionChannel.setMethodCallHandler { call, result in
        guard call.method == "request" else {
          result(FlutterMethodNotImplemented)
          return
        }
        AVCaptureDevice.requestAccess(for: .video) { granted in
          DispatchQueue.main.async {
            if granted {
              result("granted")
            } else {
              let status = AVCaptureDevice.authorizationStatus(for: .video)
              result(status == .denied ? "permanentlyDenied" : "denied")
            }
          }
        }
      }

      registrar(forPlugin: "DriveBotCameraPreview")?.register(
        CameraPreviewFactory(),
        withId: "drivebot/camera_preview"
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
