import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerArKitFoundation(with: engineBridge.pluginRegistry)
  }

  private func registerArKitFoundation(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "DriveBotArKitView") else {
      return
    }
    registrar.register(
      ArKitViewFactory(messenger: registrar.messenger()),
      withId: "drivebot/arkit_view"
    )
    ArKitRuntimeController.shared.register(messenger: registrar.messenger())
  }
}
