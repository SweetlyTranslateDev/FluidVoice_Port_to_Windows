import 'dart:async';

import 'package:file_picker/file_picker.dart';
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
  List<String> _customIds = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
    final custom = await _store.listCustomModelIds();
    if (!mounted) return;
    setState(() {
      _selected =
          _settings.selectedModelId ?? SpeechModelStore.defaultModelId;
      _customIds = custom;
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

  Future<void> _importLocal() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import Whisper ggml model',
      type: FileType.custom,
      allowedExtensions: const ['bin'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _progressLabel = 'Importing model…';
    });
    try {
      final id = await _store.importLocalGgml(path);
      await _select(id);
      final custom = await _store.listCustomModelIds();
      if (!mounted) return;
      setState(() => _customIds = custom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
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

  Future<void> _downloadFromUrl() async {
    final urlController = TextEditingController();
    final idController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Download Whisper ggml'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Paste a direct Hugging Face (or other) URL to a ggml-*.bin file.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: FluidColors.secondaryText,
                      ),
                ),
                const SizedBox(height: FluidSpacing.md),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Model URL',
                    hintText:
                        'https://huggingface.co/.../ggml-small.bin',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: FluidSpacing.md),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Model id (optional)',
                    hintText: 'small  or  my-custom',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
    final url = urlController.text.trim();
    final idHint = idController.text.trim();
    urlController.dispose();
    idController.dispose();
    if (ok != true || url.isEmpty) return;

    setState(() {
      _busy = true;
      _progressLabel = 'Downloading…';
    });
    try {
      final id = await _store.downloadFromUrl(
        url,
        modelId: idHint.isEmpty ? null : idHint,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _progressLabel = status);
        },
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progressLabel = 'Downloading… ${(p * 100).round()}%';
          });
        },
      );
      await _select(id);
      final custom = await _store.listCustomModelIds();
      if (!mounted) return;
      setState(() => _customIds = custom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
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
            'Pick a built-in Whisper/Parakeet model, import a local ggml .bin, or download from a Hugging Face URL.',
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
                      _modelGroup(
                        title: 'Whisper — English',
                        subtitle: 'Faster when you only need English',
                        ids: const ['tiny.en', 'base.en', 'small.en', 'medium.en'],
                      ),
                      const SizedBox(height: FluidSpacing.xl),
                      _modelGroup(
                        title: 'Whisper — Multilingual',
                        subtitle:
                            'Auto-detects language (from Hugging Face whisper.cpp builds)',
                        ids: const ['tiny', 'base', 'small', 'medium'],
                      ),
                      const SizedBox(height: FluidSpacing.xl),
                      _modelGroup(
                        title: 'Parakeet',
                        subtitle: 'English ONNX via sherpa-onnx',
                        ids: const ['parakeet-tdt-0.6b-v2-int8'],
                      ),
                      const SizedBox(height: FluidSpacing.xl),
                      const FluidSectionHeader(
                        'Custom models',
                        subtitle:
                            'Import a ggml .bin you already have, or download from a direct URL',
                      ),
                      FluidCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Import local ggml…'),
                              subtitle: const Text(
                                'Choose a ggml-*.bin Whisper model from disk',
                              ),
                              trailing: const Icon(Icons.upload_file_outlined),
                              enabled: !_busy,
                              onTap: _busy ? null : () => unawaited(_importLocal()),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('Download from URL…'),
                              subtitle: const Text(
                                'Hugging Face resolve link to a ggml .bin',
                              ),
                              trailing: const Icon(Icons.cloud_download_outlined),
                              enabled: !_busy,
                              onTap: _busy
                                  ? null
                                  : () => unawaited(_downloadFromUrl()),
                            ),
                          ],
                        ),
                      ),
                      if (_customIds.isNotEmpty) ...[
                        const SizedBox(height: FluidSpacing.lg),
                        _modelGroup(
                          title: 'Imported / custom',
                          subtitle: 'Models found in your FluidVoice models folder',
                          ids: _customIds,
                        ),
                      ],
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

  Widget _modelGroup({
    required String title,
    required String subtitle,
    required List<String> ids,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluidSectionHeader(title, subtitle: subtitle),
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
                for (var i = 0; i < ids.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  RadioListTile<String>(
                    value: ids[i],
                    title: Text(ids[i]),
                    subtitle: Text(SpeechModelStore.subtitleFor(ids[i])),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
