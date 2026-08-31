import Flutter
import SwiftUI
import UIKit

private struct NavigationItem: Equatable, Identifiable {
  let id: String
  let label: String
  let systemImage: String
}

private final class FloatingNavigationModel: ObservableObject {
  @Published var items: [NavigationItem] = []
  @Published var selectedID = ""
  var onSelect: ((String) -> Void)?
  var onUpdate: (() -> Void)?

  func update(from message: Any?) {
    guard let state = message as? [String: Any] else { return }
    let decodedItems: [NavigationItem] = (state["items"] as? [[String: Any]] ?? [])
      .compactMap { value -> NavigationItem? in
        guard
          let id = value["id"] as? String,
          let label = value["label"] as? String,
          let systemImage = value["systemImage"] as? String
        else { return nil }
        return NavigationItem(id: id, label: label, systemImage: systemImage)
      }
    items = decodedItems
    selectedID = state["selectedId"] as? String ?? ""
    onUpdate?()
  }

  func select(_ id: String) {
    guard items.contains(where: { $0.id == id }) else { return }
    selectedID = id
    onSelect?(id)
  }
}

@available(iOS 26.0, *)
private struct LiquidGlassNavigationBar: View {
  @ObservedObject var model: FloatingNavigationModel

  var body: some View {
    GlassEffectContainer(spacing: 8) {
      HStack(spacing: 8) {
        ForEach(model.items) { item in
          Button {
            model.select(item.id)
          } label: {
            Label(item.label, systemImage: item.systemImage)
              .font(.body.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
              .frame(minWidth: 44, minHeight: 44)
              .padding(.horizontal, 8)
              .foregroundStyle(model.selectedID == item.id ? Color.accentColor : Color.primary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(item.label)
          .accessibilityAddTraits(
            model.selectedID == item.id ? AccessibilityTraits.isSelected : AccessibilityTraits()
          )
          .accessibilityIdentifier("floating-navigation-\(item.id)")
        }
      }
      .padding(6)
      .glassEffect(.regular, in: .capsule)
    }
  }
}

final class FloatingNavigationBarViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    FloatingNavigationBarPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

private final class FloatingNavigationBarPlatformView: NSObject, FlutterPlatformView {
  private let rootView: UIView
  private let model = FloatingNavigationModel()
  private let channel: FlutterMethodChannel
  private var hostingController: UIViewController?

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "drivebot/floating_navigation_bar/\(viewId)",
      binaryMessenger: messenger
    )
    model.update(from: args)

    if #available(iOS 26.0, *) {
      let controller = UIHostingController(rootView: LiquidGlassNavigationBar(model: model))
      controller.view.backgroundColor = .clear
      rootView = controller.view
      hostingController = controller
    } else {
      let legacyView = LegacyFloatingNavigationBar(model: model)
      rootView = legacyView
      model.onUpdate = { [weak legacyView] in legacyView?.rebuildButtons() }
    }
    rootView.frame = frame
    rootView.backgroundColor = .clear
    rootView.accessibilityIdentifier = "native-floating-navigation-bar"
    super.init()

    model.onSelect = { [weak channel] id in
      channel?.invokeMethod("didSelect", arguments: id)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setState" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.model.update(from: call.arguments)
      result(nil)
    }
  }

  func view() -> UIView { rootView }
}

private final class LegacyFloatingNavigationBar: UIVisualEffectView {
  private let model: FloatingNavigationModel
  private let stack = UIStackView()

  init(model: FloatingNavigationModel) {
    self.model = model
    super.init(effect: UIBlurEffect(style: .systemMaterial))
    clipsToBounds = true
    layer.cornerCurve = .continuous
    stack.axis = .horizontal
    stack.alignment = .fill
    stack.distribution = .fillEqually
    stack.spacing = 8
    contentView.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
      stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
    ])
    rebuildButtons()
  }

  required init?(coder: NSCoder) { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }

  fileprivate func rebuildButtons() {
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for item in model.items {
      var configuration = UIButton.Configuration.plain()
      configuration.title = item.label
      configuration.image = UIImage(systemName: item.systemImage)
      configuration.imagePadding = 6
      configuration.baseForegroundColor = model.selectedID == item.id ? tintColor : .label
      let button = UIButton(configuration: configuration)
      button.accessibilityLabel = item.label
      button.accessibilityIdentifier = "floating-navigation-\(item.id)"
      button.accessibilityTraits = model.selectedID == item.id ? [.button, .selected] : .button
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
      button.addAction(UIAction { [weak self] _ in self?.didSelect(item.id) }, for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
  }

  private func didSelect(_ id: String) {
    model.select(id)
    rebuildButtons()
  }
}
