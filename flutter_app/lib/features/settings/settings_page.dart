import 'package:flutter/material.dart';

import '../../app/shell/shell_navigation.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/fluid_card.dart';
import '../../app/widgets/fluid_section_header.dart';
import '../../app/widgets/hotkey_capture_field.dart';
import '../../core/ai/deepl_translator.dart';
import '../../core/models/audio_models.dart';
import '../../core/models/dictation_mode.dart';
import '../../core/models/hotkey_models.dart';
import '../../core/platform/wasapi_audio_capture.dart';
import '../../core/platform/whisper_model_store.dart';
import '../../core/platform/win32_autostart.dart';
import '../../core/platform/win32_credentials_store.dart';
import '../../core/platform/win32_hotkey_source.dart';
import '../../core/platform/window_chrome_channel.dart';
import '../../core/services/dictation_hud_controller.dart';
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
  final _windowChrome = WindowChromeChannel();
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _deeplApiKeyController = TextEditingController();

  List<AudioDeviceInfo> _mics = [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _launchAtLogin = false;
  bool _hasStoredApiKey = false;
  bool _hasStoredDeeplApiKey = false;
  HotkeyShortcut _hotkey = kDefaultHotkeyShortcut;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
    _baseUrlController.text = _settings.aiBaseUrl ?? '';
    _hotkey = _settings.hotkeyShortcut ?? kDefaultHotkeyShortcut;
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
    try {
      final deepl =
          await _credentials.readSecret(Win32CredentialsStore.deeplApiKey);
      _hasStoredDeeplApiKey = deepl != null && deepl.isNotEmpty;
    } catch (_) {
      _hasStoredDeeplApiKey = false;
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
    _settings.hotkeyShortcut = _hotkey;
    await _settings.save();

    try {
      await _autostart.setEnabled(_launchAtLogin);
    } catch (_) {}

    try {
      await _windowChrome.setAlwaysOnTop(_settings.alwaysOnTop);
      await _windowChrome.setAcrylic(_settings.acrylicEnabled);
      await _windowChrome.setMinimizeToTray(_settings.minimizeToTray);
      DictationHudController.instance.setEnabled(_settings.floatingPillEnabled);
    } catch (_) {}

    final newKey = _apiKeyController.text.trim();
    if (newKey.isNotEmpty) {
      try {
        await _credentials.writeSecret(Win32CredentialsStore.aiApiKey, newKey);
        _hasStoredApiKey = true;
        _apiKeyController.clear();
      } catch (_) {}
    }

    final newDeeplKey = _deeplApiKeyController.text.trim();
    if (newDeeplKey.isNotEmpty) {
      try {
        await _credentials.writeSecret(
          Win32CredentialsStore.deeplApiKey,
          newDeeplKey,
        );
        _hasStoredDeeplApiKey = true;
        _deeplApiKeyController.clear();
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

  Future<void> _clearDeeplApiKey() async {
    try {
      await _credentials.deleteSecret(Win32CredentialsStore.deeplApiKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasStoredDeeplApiKey = false;
      _deeplApiKeyController.clear();
    });
  }

  void _openModels() {
    ShellNavigation.maybeOf(context)?.goTo(ShellPage.models);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _deeplApiKeyController.dispose();
    _capture.dispose();
    super.dispose();
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
          Row(
            children: [
              Expanded(
                child: Text('Settings', style: theme.textTheme.titleLarge),
              ),
              FilledButton(
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
          const SizedBox(height: FluidSpacing.xl),
          Expanded(
            child: ListView(
              children: [
                const FluidSectionHeader(
                  'General',
                  subtitle: 'Startup and capture defaults',
                ),
                FluidCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Launch at login'),
                        subtitle: const Text(
                          'Start FluidVoice when you sign in to Windows',
                        ),
                        value: _launchAtLogin,
                        onChanged: (v) => setState(() => _launchAtLogin = v),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Speech models'),
                        subtitle: Text(
                          _settings.selectedModelId ??
                              WhisperModelStore.defaultModelId,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openModels,
                      ),
                      const Divider(height: 1),
                      HotkeyCaptureField(
                        value: _hotkey,
                        onChanged: (shortcut) {
                          setState(() => _hotkey = shortcut);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('History retention'),
                        subtitle: Text(
                          HistoryRetention.label(_settings.historyRetentionDays),
                        ),
                        trailing: DropdownButton<int>(
                          value: _settings.historyRetentionDays,
                          underline: const SizedBox.shrink(),
                          onChanged: (days) {
                            if (days == null) return;
                            setState(
                              () => _settings.historyRetentionDays = days,
                            );
                          },
                          items: [
                            for (final days in HistoryRetention.options)
                              DropdownMenuItem(
                                value: days,
                                child: Text(HistoryRetention.label(days)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FluidSpacing.xl),
                const FluidSectionHeader(
                  'Window',
                  subtitle: 'Desktop chrome and layering',
                ),
                FluidCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Always on top'),
                        subtitle: const Text(
                          'Keep FluidVoice above other windows',
                        ),
                        value: _settings.alwaysOnTop,
                        onChanged: (v) async {
                          setState(() => _settings.alwaysOnTop = v);
                          try {
                            await _windowChrome.setAlwaysOnTop(v);
                          } catch (_) {}
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Acrylic transparency'),
                        subtitle: const Text(
                          'Blurred desktop shows through the shell (sidebar / gaps). Cards stay denser for readability.',
                        ),
                        value: _settings.acrylicEnabled,
                        onChanged: (v) async {
                          setState(() => _settings.acrylicEnabled = v);
                          try {
                            await _windowChrome.setAcrylic(v);
                          } catch (_) {}
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Minimize to tray'),
                        subtitle: const Text(
                          'Off: normal Windows minimize to the taskbar. On: hide to the system tray icon (pill can stay visible).',
                        ),
                        value: _settings.minimizeToTray,
                        onChanged: (v) async {
                          setState(() => _settings.minimizeToTray = v);
                          try {
                            await _windowChrome.setMinimizeToTray(v);
                            await _settings.save();
                          } catch (_) {}
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Floating dictation pill'),
                        subtitle: const Text(
                          'Separate always-on-top WaveVisualizer pill + transcript. Use the pill ✕ to restore this window. The window Close button quits the app.',
                        ),
                        value: _settings.floatingPillEnabled,
                        onChanged: (v) async {
                          setState(() => _settings.floatingPillEnabled = v);
                          DictationHudController.instance.setEnabled(v);
                          try {
                            await _settings.save();
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FluidSpacing.xl),
                const FluidSectionHeader(
                  'Output',
                  subtitle: 'How transcribed text is delivered',
                ),
                FluidCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Output mode'),
                        subtitle: Text(_settings.outputMode.name),
                        trailing: DropdownButton<DictationOutputMode>(
                          value: _settings.outputMode,
                          underline: const SizedBox.shrink(),
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
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Local API'),
                        subtitle: Text(
                          'Loopback http://127.0.0.1:${LocalApiServer.defaultPort}',
                        ),
                        value: _settings.localApiEnabled,
                        onChanged: (v) =>
                            setState(() => _settings.localApiEnabled = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Pause media while dictating'),
                        subtitle: const Text(
                          'Sends play/pause when recording starts and stops',
                        ),
                        value: _settings.pauseMediaWhileDictating,
                        onChanged: (v) => setState(
                          () => _settings.pauseMediaWhileDictating = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FluidSpacing.xl),
                const FluidSectionHeader(
                  'Translation',
                  subtitle:
                      'Optional DeepL — inject translated text instead of raw STT',
                ),
                FluidCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Translate before inject'),
                        subtitle: const Text(
                          'Speech is transcribed locally, then sent to DeepL '
                          'using your API key. Only the translation is injected.',
                        ),
                        value: _settings.translationEnabled,
                        onChanged: (v) =>
                            setState(() => _settings.translationEnabled = v),
                      ),
                      const SizedBox(height: FluidSpacing.md),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Target language',
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: DeepLTargetLang.isSupported(
                              _settings.deeplTargetLang,
                            )
                                ? _settings.deeplTargetLang
                                : 'DE',
                            items: [
                              for (final entry
                                  in DeepLTranslator.targetLanguages.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    '${entry.value} (${entry.key})',
                                  ),
                                ),
                            ],
                            onChanged: _settings.translationEnabled
                                ? (code) {
                                    if (code == null) return;
                                    setState(
                                      () => _settings.deeplTargetLang = code,
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: FluidSpacing.md),
                      TextField(
                        controller: _deeplApiKeyController,
                        obscureText: true,
                        enabled: _settings.translationEnabled,
                        decoration: InputDecoration(
                          labelText: 'DeepL API key',
                          hintText: _hasStoredDeeplApiKey
                              ? 'Saved — enter to replace'
                              : 'Free key from deepl.com/pro-api',
                          helperText:
                              'Stored in Windows Credential Manager. '
                              'Free keys end with :fx and use api-free.deepl.com.',
                          suffixIcon: _hasStoredDeeplApiKey
                              ? IconButton(
                                  tooltip: 'Clear stored key',
                                  onPressed: _clearDeeplApiKey,
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FluidSpacing.xl),
                const FluidSectionHeader(
                  'AI',
                  subtitle: 'Optional enhancement providers',
                ),
                FluidCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'AI base URL',
                          hintText: 'https://api.openai.com/v1',
                        ),
                      ),
                      const SizedBox(height: FluidSpacing.md),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'AI API key',
                          hintText: _hasStoredApiKey
                              ? 'Saved — enter to replace'
                              : 'Stored in Windows Credential Manager',
                          suffixIcon: _hasStoredApiKey
                              ? IconButton(
                                  tooltip: 'Clear stored key',
                                  onPressed: _clearApiKey,
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FluidSpacing.xl),
                const FluidSectionHeader(
                  'Microphone',
                  subtitle: 'WASAPI capture device',
                ),
                FluidCard(
                  padding: EdgeInsets.zero,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(FluidSpacing.lg),
                          child: LinearProgressIndicator(),
                        )
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(FluidSpacing.lg),
                              child: Text(
                                _error!,
                                style: fluidText(color: FluidColors.danger),
                              ),
                            )
                          : _mics.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(FluidSpacing.lg),
                                  child: Text('No capture devices found.'),
                                )
                              : RadioGroup<String>(
                                  groupValue: _settings.selectedMicId,
                                  onChanged: (id) {
                                    if (id == null) return;
                                    setState(
                                      () => _settings.selectedMicId = id,
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < _mics.length; i++) ...[
                                        if (i > 0) const Divider(height: 1),
                                        RadioListTile<String>(
                                          value: _mics[i].id,
                                          title: Text(_mics[i].name),
                                          subtitle: Text(
                                            _mics[i].id,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          secondary: _mics[i].isDefault
                                              ? Text(
                                                  'Default',
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: FluidColors.accent,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ],
                                  ),
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
