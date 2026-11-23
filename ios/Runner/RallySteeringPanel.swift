import UIKit

final class RallySteeringPreferences {
  private let defaults: UserDefaults
  var inverted: Bool {
    didSet { defaults.set(inverted, forKey: "rally.inverted") }
  }
  var sensitivity: Float {
    didSet { defaults.set(sensitivity, forKey: "rally.sensitivity") }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    inverted = defaults.bool(forKey: "rally.inverted")
    let saved = defaults.object(forKey: "rally.sensitivity") as? NSNumber
    sensitivity = max(0.5, min(2, saved?.floatValue ?? 1))
  }
}

final class RallySteeringPanel: UIStackView {
  private let controls: RallySteeringPreferences
  private let sensitivityLabel = UILabel()
  private let onClose: () -> Void

  init(controls: RallySteeringPreferences, onClose: @escaping () -> Void) {
    self.controls = controls
    self.onClose = onClose
    super.init(frame: .zero)
    let invert = UISwitch()
    invert.isOn = controls.inverted
    invert.accessibilityLabel = "Lenkung invertieren"
    invert.addTarget(self, action: #selector(changeInversion(_:)), for: .valueChanged)
    let title = UILabel()
    title.text = "Steuerung"
    title.font = .boldSystemFont(ofSize: 22)
    let inversionLabel = UILabel()
    inversionLabel.text = "Lenkung invertieren"
    let row = UIStackView(arrangedSubviews: [inversionLabel, invert])
    let slider = UISlider()
    slider.minimumValue = 0.5
    slider.maximumValue = 2
    slider.value = controls.sensitivity
    slider.accessibilityLabel = "Lenkempfindlichkeit"
    slider.addTarget(self, action: #selector(changeSensitivity(_:)), for: .valueChanged)
    sensitivityLabel.text = String(format: "Lenkempfindlichkeit %.1f", slider.value)
    let close = UIButton(type: .system)
    close.setTitle("Fertig", for: .normal)
    close.addTarget(self, action: #selector(closePanel), for: .touchUpInside)
    for label in [title, inversionLabel, sensitivityLabel] { label.textColor = .white }
    for item in [title, row, sensitivityLabel, slider, close] as [UIView] {
      addArrangedSubview(item)
    }
    axis = .vertical
    spacing = 10
    backgroundColor = UIColor(white: 0.08, alpha: 0.97)
    layer.cornerRadius = 18
    isLayoutMarginsRelativeArrangement = true
    layoutMargins = UIEdgeInsets(top: 16, left: 18, bottom: 12, right: 18)
    translatesAutoresizingMaskIntoConstraints = false
    isHidden = true
  }

  @objc private func changeSensitivity(_ slider: UISlider) {
    controls.sensitivity = slider.value
    sensitivityLabel.text = String(format: "Lenkempfindlichkeit %.1f", slider.value)
  }
  @objc private func changeInversion(_ toggle: UISwitch) {
    controls.inverted = toggle.isOn
  }

  required init(coder: NSCoder) { fatalError("Use init(controls:onClose:)") }
  @objc private func closePanel() { onClose() }
}
