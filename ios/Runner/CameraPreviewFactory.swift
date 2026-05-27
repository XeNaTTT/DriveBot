import AVFoundation
import Flutter
import UIKit

final class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    CameraPreviewPlatformView(frame: frame)
  }
}

final class CameraPreviewPlatformView: NSObject, FlutterPlatformView {
  private let previewView: CameraPreviewView

  init(frame: CGRect) {
    previewView = CameraPreviewView(frame: frame)
    super.init()
  }

  func view() -> UIView {
    previewView
  }
}

final class CameraPreviewView: UIView {
  private let session = AVCaptureSession()
  private var layerPreview: AVCaptureVideoPreviewLayer?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    setupSession()
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layerPreview?.frame = bounds
  }

  private func setupSession() {
    guard
      let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: camera),
      session.canAddInput(input)
    else {
      return
    }

    session.addInput(input)
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = bounds
    layer.addSublayer(previewLayer)
    layerPreview = previewLayer
    session.startRunning()
  }

  deinit {
    session.stopRunning()
  }
}
