import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/models/audio_models.dart';
import '../../core/platform/wasapi_audio_capture.dart';
import '../../core/platform/whisper_model_store.dart';
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
  List<AudioDeviceInfo> _mics = [];
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
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
    await _settings.save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  void dispose() {
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
          SwitchListTile(
            title: const Text('AI enhancement'),
            subtitle: const Text('OpenAI-compatible post-process (optional)'),
            value: _settings.aiEnhancementEnabled,
            onChanged: (v) => setState(() => _settings.aiEnhancementEnabled = v),
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
