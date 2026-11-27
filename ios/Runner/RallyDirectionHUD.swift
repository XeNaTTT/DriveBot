import ARKit
import UIKit

/// Passive overlays, updated by the existing display link in ARView coordinates.
@MainActor
final class RallyDirectionHUD {
  private final class Badge: UIView {
    let pointer = UIImageView(image: UIImage(systemName: "arrowtriangle.right.fill"))
    var shown = false

    init(icon: String, color: UIColor) {
      super.init(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
      isUserInteractionEnabled = false
      backgroundColor = UIColor.black.withAlphaComponent(0.63)
      layer.cornerRadius = 18
      let symbol = UIImageView(image: UIImage(systemName: icon))
      symbol.tintColor = color
      symbol.contentMode = .scaleAspectFit
      symbol.frame = CGRect(x: 8, y: 9, width: 19, height: 18)
      addSubview(symbol)
      pointer.tintColor = color
      pointer.contentMode = .scaleAspectFit
      pointer.bounds.size = CGSize(width: 10, height: 10)
      addSubview(pointer)
      alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("Storyboard initialization unsupported") }

    func show(_ value: Bool) {
      guard value != shown else { return }
      shown = value
      UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState,.allowUserInteraction]) {
        self.alpha = value ? 1 : 0
      }
    }
  }

  private let gate = Badge(icon:"flag.checkered",color:.systemYellow)
  private let car = Badge(icon: "car.fill", color: .systemPink)
  private let person = Badge(icon: "figure.walk", color: .systemTeal)
  init(root: UIView) {
    root.addSubview(gate)
    root.addSubview(car)
    root.addSubview(person)
  }

  func hide() {
    gate.show(false)
    car.show(false)
    person.show(false)
  }

  func update(root: UIView, camera: ARCamera, orientation: UIInterfaceOrientation,
              vehicle: SIMD3<Float>?, vehicleRadius: Float, walker: SIMD3<Float>?, walkerRadius: Float, checkpoint: SIMD3<Float>? = nil,
              avoiding controls: [UIView]) {
    let size = root.bounds.size
    guard size.width > 50, size.height > 50, orientation != .unknown else { hide(); return }
    let safe = root.bounds.inset(by: root.safeAreaInsets)
    let pad: CGFloat = 24
    let inset = safe.insetBy(dx: pad, dy: pad)
    let rim = rect(inset)
    let projection = camera.projectionMatrix(for: orientation, viewportSize: size, zNear: 0.001, zFar: 100)
    let matrix = projection * camera.viewMatrix(for: orientation)
    var blocked = controls.filter { !$0.isHidden && $0.alpha > 0.01 }.map {
      rect($0.convert($0.bounds, to: root).insetBy(dx: -pad, dy: -pad))
    }
    // The race-close affordance is drawn by Flutter above this native view.
    blocked.append(rect(CGRect(origin: safe.origin, size: CGSize(width: 64, height: 64)).insetBy(dx: -pad, dy: -pad)))

    func place(_ badge: Badge, target: SIMD3<Float>?, radius: Float) {
      guard let target else { badge.show(false); return }
      let clip = matrix * SIMD4(target.x,target.y,target.z,1)
      let fx = projection.columns.0.x, fy = projection.columns.1.y
      let direction = rrIndicator(Double(clip.x), Double(clip.y), Double(clip.w),
        Double(radius * sqrt(1 + fx*fx)), Double(radius * sqrt(1 + fy*fy)), Double(radius),
        size.width, size.height, rim, badge.shown)
      var point = RRPoint()
      guard direction.visible, rrFreeEdge(direction.edge,rim,blocked,Int32(blocked.count),&point)
      else { badge.show(false); return }
      badge.center = CGPoint(x: point.x, y: point.y)
      let angle = direction.angle
      badge.pointer.center = CGPoint(x: 18 + 16*cos(angle), y: 18 + 16*sin(angle))
      badge.pointer.transform = CGAffineTransform(rotationAngle: angle)
      badge.show(true)
      blocked.append(rect(badge.frame.insetBy(dx: -pad, dy: -pad)))
    }
    place(gate,target:checkpoint,radius:0.085)
    place(car,target: vehicle,radius: vehicleRadius)
    place(person,target: walker,radius: walkerRadius)
  }

  private func rect(_ r: CGRect) -> RRRect {
    RRRect(left: r.minX, top: r.minY, right: r.maxX, bottom: r.maxY)
  }
}
