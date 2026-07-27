import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/fluid_card.dart';
import '../../core/services/history_manager.dart';
import '../../core/services/settings_manager.dart';
import '../../core/storage/json_history_store.dart';
import '../../core/storage/json_settings_store.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  final _history = HistoryManager(JsonHistoryStore());
  final _settings = SettingsManager(JsonSettingsStore());
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _load() async {
    await _settings.load();
    await _history.load(retentionDays: _settings.historyRetentionDays);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FluidColors.elevatedCardBackground,
        title: const Text('Clear history?'),
        content: const Text('This removes all saved transcripts on this PC.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _history.clear();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _history.entries;

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
                child: Text('History', style: theme.textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Clear',
                onPressed: entries.isEmpty ? null : _clear,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: FluidSpacing.sm),
          Text(
            'Recent transcripts saved on this PC.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FluidColors.secondaryText,
            ),
          ),
          const SizedBox(height: FluidSpacing.xl),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? FluidCard(
                        child: Center(
                          child: Text(
                            'No transcripts yet.\nHold your hotkey on Home to dictate.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: FluidColors.tertiaryText,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: FluidSpacing.md),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          return FluidCard(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: FluidSpacing.lg,
                                vertical: FluidSpacing.sm,
                              ),
                              title: Text(e.text),
                              subtitle: Text(
                                e.createdAt.toLocal().toString(),
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                tooltip: 'Copy',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: e.text),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied')),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
