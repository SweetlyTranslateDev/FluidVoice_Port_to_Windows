import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/fluid_card.dart';
import '../../app/widgets/fluid_section_header.dart';
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
        SnackBar(content: Text('Model $modelId ready')),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FluidSpacing.xxl,
        FluidSpacing.xxl,
        FluidSpacing.xxl,
        FluidSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Models', style: theme.textTheme.titleLarge),
          const SizedBox(height: FluidSpacing.sm),
          Text(
            'whisper.cpp models download on first use or when selected.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FluidColors.secondaryText,
            ),
          ),
          const SizedBox(height: FluidSpacing.xl),
          if (_busy && _progressLabel != null) ...[
            Text(
              _progressLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FluidColors.accent,
              ),
            ),
            const SizedBox(height: FluidSpacing.md),
            const LinearProgressIndicator(),
            const SizedBox(height: FluidSpacing.xl),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      const FluidSectionHeader('Available'),
                      FluidCard(
                        padding: EdgeInsets.zero,
                        child: RadioGroup<String>(
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
                              for (var i = 0;
                                  i < WhisperModelStore.availableModelIds.length;
                                  i++) ...[
                                if (i > 0) const Divider(height: 1),
                                RadioListTile<String>(
                                  value:
                                      WhisperModelStore.availableModelIds[i],
                                  title: Text(
                                    WhisperModelStore.availableModelIds[i],
                                  ),
                                  subtitle: Text(
                                    WhisperModelStore.availableModelIds[i] ==
                                            'tiny.en'
                                        ? 'Fastest, English — default'
                                        : 'Higher quality, English — larger download',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: FluidSpacing.xl),
                      const FluidSectionHeader(
                        'Coming later',
                        subtitle: 'Phase 3 under speech_runtime',
                      ),
                      const FluidCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text('ONNX / Parakeet-class'),
                              subtitle: Text('Planned'),
                              enabled: false,
                            ),
                            Divider(height: 1),
                            ListTile(
                              title: Text('Vosk'),
                              subtitle: Text('Planned'),
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
