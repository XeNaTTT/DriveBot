/// UI-agnostic profile metadata stored for authenticated users.
final class UserProfile {
  const UserProfile({
    required this.userId,
    this.email,
    this.displayName,
    this.acceptedTermsAt,
  });

  final String userId;
  final String? email;
  final String? displayName;
  final DateTime? acceptedTermsAt;
}

/// UI-agnostic per-user settings that can safely default in guest mode.
final class UserSettings {
  const UserSettings({
    required this.userId,
    this.preferredCameraZoom,
    this.useLiveData = true,
    this.showDebugSourceLabels = false,
  });

  const UserSettings.guest()
    : userId = 'guest',
      preferredCameraZoom = null,
      useLiveData = true,
      showDebugSourceLabels = false;

  final String userId;
  final double? preferredCameraZoom;
  final bool useLiveData;
  final bool showDebugSourceLabels;

  UserSettings copyWith({
    String? userId,
    double? preferredCameraZoom,
    bool clearPreferredCameraZoom = false,
    bool? useLiveData,
    bool? showDebugSourceLabels,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      preferredCameraZoom: clearPreferredCameraZoom
          ? null
          : preferredCameraZoom ?? this.preferredCameraZoom,
      useLiveData: useLiveData ?? this.useLiveData,
      showDebugSourceLabels:
          showDebugSourceLabels ?? this.showDebugSourceLabels,
    );
  }
}
