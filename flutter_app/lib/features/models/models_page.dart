import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/whisper_model_store.dart';
import '../../core/services/settings_manager.dart';
import '../../core/storage/json_settings_store.dart';

class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  final _settings = SettingsManager(JsonSettingsStore());
  final _store = WhisperModelStore();
  bool _loading = true;
  bool _busy = false;
  String? _progressLabel;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
    setState(() {
      _selected =
          _settings.selectedModelId ?? WhisperModelStore.defaultModelId;
      _loading = false;
    });
  }

  Future<void> _select(String modelId) async {
    setState(() {
      _busy = true;
      _progressLabel = 'Downloading $modelId…';
      _selected = modelId;
    });
    try {
      await _store.ensureModel(
        modelId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progressLabel = 'Downloading $modelId… ${(p * 100).round()}%';
          });
        },
      );
      _settings.selectedModelId = modelId;
      await _settings.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model $modelId ready — return to dictation')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model download failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech models')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const ListTile(
                  title: Text('whisper.cpp (speech_runtime)'),
                  subtitle: Text('Models download on first use / selection'),
                ),
                if (_busy && _progressLabel != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_progressLabel!),
                  ),
                RadioGroup<String>(
                  groupValue: _selected,
                  onChanged: _busy
                      ? (_) {}
                      : (id) {
                          if (id != null) {
                            unawaited(_select(id));
                          }
                        },
                  child: Column(
                    children: [
                      for (final id in WhisperModelStore.availableModelIds)
                        RadioListTile<String>(
                          value: id,
                          title: Text(id),
                          subtitle: Text(
                            id == 'tiny.en'
                                ? 'Fastest, English — default'
                                : 'Higher quality, English — larger download',
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                const ListTile(
                  title: Text('ONNX / Parakeet-class'),
                  subtitle: Text('Planned — Phase 3 under speech_runtime'),
                  enabled: false,
                ),
                const ListTile(
                  title: Text('Vosk'),
                  subtitle: Text('Planned — Phase 3 under speech_runtime'),
                  enabled: false,
                ),
              ],
            ),
    );
  }
}
