# Native floating navigation on iOS

The HUD owns the navigation entries, selected state, and callbacks. Its
`FloatingNavigationBar` serializes only immutable display data (`id`, localized
label, and SF Symbol name) into the iOS platform view. Selection events travel
back over the view-scoped method channel; no navigation or business state is
owned by Swift.

On iOS 26 and later, `LiquidGlassNavigationBar` uses SwiftUI's public
`GlassEffectContainer` and `.glassEffect(.regular, in: .capsule)` APIs. The bar
has one glass surface; labels and icons do not add nested effects. On older iOS
versions, the same model is rendered by a `UIVisualEffectView` using
`UIBlurEffect.Style.systemMaterial`. Both implementations use system colors,
SF Symbols, accessibility labels and identifiers, and at least 44-point action
heights so system appearance and accessibility settings remain authoritative.

The platform view is constrained to the visible 64-point bar instead of a
screen-sized overlay. Flutter content therefore continues behind it and owns
all gestures outside the bar. The assistant's scroll view receives bottom
padding for the bar and safe area, allowing its final line to scroll fully
above the controls.

The native contract intentionally uses Flutter's standard codec rather than a
Pigeon dependency: it is a view-local, three-field immutable DTO with one
event, validated on both sides. If the navigation model grows beyond this
small visual contract, migrate it to generated Pigeon messages.
