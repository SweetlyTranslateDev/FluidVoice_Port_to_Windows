import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/models/audio_models.dart';
import '../../core/models/dictation_mode.dart';
import '../../core/platform/wasapi_audio_capture.dart';
import '../../core/platform/whisper_model_store.dart';
import '../../core/platform/win32_autostart.dart';
import '../../core/platform/win32_credentials_store.dart';
import '../../core/services/local_api_server.dart';
import '../../core/services/settings_manager.dart';
import '../../core/storage/json_settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _capture = WasapiAudioCapture();
  final _settings = SettingsManager(JsonSettingsStore());
  final _autostart = Win32Autostart();
  final _credentials = Win32CredentialsStore();
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();

  List<AudioDeviceInfo> _mics = [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _launchAtLogin = false;
  bool _hasStoredApiKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
    _baseUrlController.text = _settings.aiBaseUrl ?? '';
    try {
      _launchAtLogin = await _autostart.isEnabled();
    } catch (_) {
      _launchAtLogin = false;
    }
    try {
      final existing =
          await _credentials.readSecret(Win32CredentialsStore.aiApiKey);
      _hasStoredApiKey = existing != null && existing.isNotEmpty;
    } catch (_) {
      _hasStoredApiKey = false;
    }

    if (!_capture.isNativeAvailable) {
      setState(() {
        _loading = false;
        _error =
            'fluidvoice_wasapi.dll not loaded (build Flutter Windows to produce it).';
      });
      return;
    }
    try {
      final devices = await _capture.listDevices();
      if (!mounted) return;
      setState(() {
        _mics = devices;
        _loading = false;
        _error = null;
        if ((_settings.selectedMicId == null ||
                _settings.selectedMicId!.isEmpty) &&
            devices.isNotEmpty) {
          final def = devices.where((d) => d.isDefault);
          _settings.selectedMicId =
              def.isNotEmpty ? def.first.id : devices.first.id;
        }
        _settings.selectedModelId ??= WhisperModelStore.defaultModelId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    _settings.aiBaseUrl = _baseUrlController.text.trim();
    await _settings.save();

    try {
      await _autostart.setEnabled(_launchAtLogin);
    } catch (_) {}

    final newKey = _apiKeyController.text.trim();
    if (newKey.isNotEmpty) {
      try {
        await _credentials.writeSecret(Win32CredentialsStore.aiApiKey, newKey);
        _hasStoredApiKey = true;
        _apiKeyController.clear();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _clearApiKey() async {
    try {
      await _credentials.deleteSecret(Win32CredentialsStore.aiApiKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasStoredApiKey = false;
      _apiKeyController.clear();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _persist,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Launch at login'),
            subtitle: const Text('Start FluidVoice when you sign in to Windows'),
            value: _launchAtLogin,
            onChanged: (v) => setState(() => _launchAtLogin = v),
          ),
          ListTile(
            title: const Text('Speech models'),
            subtitle: Text(
              _settings.selectedModelId ?? WhisperModelStore.defaultModelId,
            ),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.models),
          ),
          const ListTile(
            title: Text('Hotkey'),
            subtitle: Text('Push-to-talk: hold F8 (WH_KEYBOARD_LL)'),
          ),
          ListTile(
            title: const Text('Output mode'),
            subtitle: Text(_settings.outputMode.name),
            trailing: DropdownButton<DictationOutputMode>(
              value: _settings.outputMode,
              onChanged: (mode) {
                if (mode == null) return;
                setState(() => _settings.outputMode = mode);
              },
              items: [
                for (final mode in DictationOutputMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(mode.name),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Local API'),
            subtitle: Text(
              'Loopback http://127.0.0.1:${LocalApiServer.defaultPort} '
              '(applied when you return to dictation)',
            ),
            value: _settings.localApiEnabled,
            onChanged: (v) => setState(() => _settings.localApiEnabled = v),
          ),
          SwitchListTile(
            title: const Text('Pause media while dictating'),
            subtitle: const Text('Sends play/pause when recording starts and stops'),
            value: _settings.pauseMediaWhileDictating,
            onChanged: (v) =>
                setState(() => _settings.pauseMediaWhileDictating = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'AI base URL',
                hintText: 'https://api.openai.com/v1',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'AI API key',
                hintText: _hasStoredApiKey
                    ? 'Saved in Credential Manager — enter to replace'
                    : 'Stored in Windows Credential Manager',
                border: const OutlineInputBorder(),
                suffixIcon: _hasStoredApiKey
                    ? IconButton(
                        tooltip: 'Clear stored key',
                        onPressed: _clearApiKey,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
          ),
          const ListTile(
            title: Text('Microphone (WASAPI)'),
            subtitle: Text('Selection is saved under AppData'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            )
          else if (_mics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No capture devices found.'),
            )
          else
            RadioGroup<String>(
              groupValue: _settings.selectedMicId,
              onChanged: (id) {
                if (id == null) return;
                setState(() => _settings.selectedMicId = id);
              },
              child: Column(
                children: [
                  for (final d in _mics)
                    RadioListTile<String>(
                      value: d.id,
                      title: Text(d.name),
                      subtitle: Text(
                        d.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: d.isDefault ? const Text('Default') : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
