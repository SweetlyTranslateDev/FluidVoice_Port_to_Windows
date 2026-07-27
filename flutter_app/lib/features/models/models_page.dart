import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/fluid_card.dart';
import '../../app/widgets/fluid_section_header.dart';
import '../../core/platform/speech_model_store.dart';
import '../../core/services/settings_manager.dart';
import '../../core/storage/json_settings_store.dart';

class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  final _settings = SettingsManager(JsonSettingsStore());
  final _store = SpeechModelStore();
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
          _settings.selectedModelId ?? SpeechModelStore.defaultModelId;
      _loading = false;
    });
  }

  Future<void> _select(String modelId) async {
    setState(() {
      _busy = true;
      _progressLabel = 'Preparing $modelId…';
      _selected = modelId;
    });
    try {
      await _store.ensureModel(
        modelId,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _progressLabel = status);
        },
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progressLabel =
                'Downloading $modelId… ${(p * 100).round()}%';
          });
        },
      );
      _settings.selectedModelId = modelId;
      await _settings.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Model $modelId ready — Home will load it on next dictate',
          ),
        ),
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
            'Whisper ggml and Parakeet ONNX download on first use or when selected.',
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
                                  i <
                                      SpeechModelStore
                                          .availableModelIds.length;
                                  i++) ...[
                                if (i > 0) const Divider(height: 1),
                                RadioListTile<String>(
                                  value:
                                      SpeechModelStore.availableModelIds[i],
                                  title: Text(
                                    SpeechModelStore.availableModelIds[i],
                                  ),
                                  subtitle: Text(
                                    SpeechModelStore.subtitleFor(
                                      SpeechModelStore.availableModelIds[i],
                                    ),
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
                        subtitle: 'Additional backends under speech_runtime',
                      ),
                      const FluidCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
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
