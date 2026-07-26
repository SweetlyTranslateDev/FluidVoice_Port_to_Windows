import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/models/audio_models.dart';
import '../../core/platform/wasapi_audio_capture.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _capture = WasapiAudioCapture();
  List<AudioDeviceInfo> _mics = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMics();
  }

  Future<void> _loadMics() async {
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Speech models'),
            subtitle: const Text('Select via SpeechEngine facade'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.models),
          ),
          const ListTile(
            title: Text('Hotkey'),
            subtitle: Text('Push-to-talk: hold F8 (WH_KEYBOARD_LL)'),
          ),
          const ListTile(
            title: Text('Microphone (WASAPI)'),
            subtitle: Text('Enumerated via fluidvoice_wasapi.dll'),
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
            ..._mics.map(
              (d) => ListTile(
                leading: Icon(
                  d.isDefault ? Icons.mic : Icons.mic_none,
                ),
                title: Text(d.name),
                subtitle: Text(d.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: d.isDefault ? const Text('Default') : null,
              ),
            ),
          const ListTile(
            title: Text('AI enhancement'),
            subtitle: Text('OpenAI-compatible AIProvider (Dart HTTP)'),
          ),
        ],
      ),
    );
  }
}
