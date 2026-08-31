import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class FloatingNavigationItem {
  const FloatingNavigationItem({
    required this.id,
    required this.label,
    required this.systemImage,
  });

  final String id;
  final String label;
  final String systemImage;

  Map<String, Object> toMessage() => {
    'id': id,
    'label': label,
    'systemImage': systemImage,
  };
}

class FloatingNavigationBar extends StatefulWidget {
  const FloatingNavigationBar({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  static const double height = 64;
  static const String viewType = 'drivebot/floating_navigation_bar';

  final List<FloatingNavigationItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<FloatingNavigationBar> createState() => _FloatingNavigationBarState();
}

class _FloatingNavigationBarState extends State<FloatingNavigationBar> {
  MethodChannel? _channel;

  Map<String, Object> get _stateMessage => {
    'items': widget.items.map((item) => item.toMessage()).toList(),
    'selectedId': widget.selectedId,
  };

  @override
  void didUpdateWidget(FloatingNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId ||
        !listEquals(oldWidget.items, widget.items)) {
      _channel?.invokeMethod<void>('setState', _stateMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _FlutterDevelopmentBar(
        items: widget.items,
        selectedId: widget.selectedId,
        onSelected: widget.onSelected,
      );
    }

    return UiKitView(
      key: const Key('native-floating-navigation-bar'),
      viewType: FloatingNavigationBar.viewType,
      creationParams: _stateMessage,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (viewId) {
        final channel = MethodChannel(
          'drivebot/floating_navigation_bar/$viewId',
        );
        _channel = channel;
        channel.setMethodCallHandler((call) async {
          if (call.method == 'didSelect' && call.arguments is String) {
            widget.onSelected(call.arguments as String);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}

class _FlutterDevelopmentBar extends StatelessWidget {
  const _FlutterDevelopmentBar({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<FloatingNavigationItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('floating-navigation-fallback'),
    color: const Color(0xEE17202B),
    borderRadius: BorderRadius.circular(32),
    child: Row(
      children: [
        for (final item in items)
          Expanded(
            child: Semantics(
              selected: item.id == selectedId,
              button: true,
              label: item.label,
              child: SizedBox(
                height: 48,
                child: TextButton(
                  key: Key('floating-navigation-${item.id}'),
                  onPressed: () => onSelected(item.id),
                  child: FittedBox(child: Text(item.label)),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
