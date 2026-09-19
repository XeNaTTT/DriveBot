import Flutter
import UIKit

final class ArRacingViewFactory: NSObject, FlutterPlatformViewFactory {
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
      viewIdentifier: viewId,
      vehicleID: parameters?["vehicleID"] as? String ?? "compact")
  }
}
