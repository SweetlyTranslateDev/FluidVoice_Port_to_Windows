/// Key/value settings persistence (see [JsonSettingsStore] for AppData JSON).
abstract class SettingsStore {
  Future<Map<String, String>> readAll();

  Future<void> writeAll(Map<String, String> values);
}

/// In-memory store for Phase 0 scaffold / tests.
class InMemorySettingsStore implements SettingsStore {
  final Map<String, String> _values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);

  @override
  Future<void> writeAll(Map<String, String> values) async {
    _values
      ..clear()
      ..addAll(values);
  }
}
