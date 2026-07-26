library;

enum AppTrayStatus {
  idle,
  listening,
  processing,
  error,
}

class TrayMenuItem {
  const TrayMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
  });

  final String id;
  final String label;
  final bool enabled;
}

class TrayAction {
  const TrayAction(this.id);

  final String id;
}

enum DictationSessionState {
  idle,
  armed,
  recording,
  transcribing,
  enhancing,
  injecting,
  error,
}
