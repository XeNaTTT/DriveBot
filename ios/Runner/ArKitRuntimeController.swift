import ARKit
import Flutter
import UIKit

final class ArKitRuntimeController: NSObject {
  static let shared = ArKitRuntimeController()

  private weak var activeView: ArKitView?
  private var hasRequestedStart = false

  var isSupported: Bool {
    if #available(iOS 11.0, *) {
      return ARWorldTrackingConfiguration.isSupported
    }
    return false
  }

  func register(channel messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "drivebot/arkit_runtime",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "arkit_missing", message: "AR nicht verfügbar", details: nil))
        return
      }

      switch call.method {
      case "isSupported":
        result(self.isSupported)
      case "start":
        self.hasRequestedStart = true
        self.activeView?.startSession()
        result(nil)
      case "stop":
        self.hasRequestedStart = false
        self.activeView?.pauseSession()
        result(nil)
      case "currentState":
        result(self.currentState())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func attach(_ view: ArKitView) {
    activeView = view
    if hasRequestedStart {
      view.startSession()
    }
  }

  func detach(_ view: ArKitView) {
    if activeView === view {
      activeView = nil
    }
  }

  func currentState() -> [String: Any] {
    guard isSupported else {
      return [
        "isSupported": false,
        "isRunning": false,
        "trackingQuality": "unavailable",
        "fallbackReason": "AR nicht verfügbar"
      ]
    }

    let quality = activeView?.trackingQuality ?? "stable"
    return [
      "isSupported": true,
      "isRunning": activeView?.isRunning ?? hasRequestedStart,
      "trackingQuality": quality
    ]
  }
}
