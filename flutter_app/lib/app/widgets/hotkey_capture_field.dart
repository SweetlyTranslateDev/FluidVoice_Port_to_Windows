import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/hotkey_models.dart';
import '../../core/platform/hotkey_vk.dart';
import '../../core/platform/win32_hotkey_source.dart';

/// Tap to capture any key combination for the dictation hotkey.
class HotkeyCaptureField extends StatefulWidget {
  const HotkeyCaptureField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HotkeyShortcut value;
  final ValueChanged<HotkeyShortcut> onChanged;

  @override
  State<HotkeyCaptureField> createState() => _HotkeyCaptureFieldState();
}

class _HotkeyCaptureFieldState extends State<HotkeyCaptureField> {
  bool _listening = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() => _listening = true);
    _focus.requestFocus();
  }

  void _stopListening() {
    setState(() => _listening = false);
    _focus.unfocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_listening || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _stopListening();
      return KeyEventResult.handled;
    }
    if (isModifierLogicalKey(key)) {
      return KeyEventResult.handled;
    }
    final vk = vkFromLogicalKey(key);
    if (vk == null) {
      return KeyEventResult.handled;
    }
    final mods = modifiersFromKeyboard(HardwareKeyboard.instance);
    final shortcut = HotkeyShortcut(
      keyCode: vk,
      modifiers: mods,
    );
    widget.onChanged(
      HotkeyShortcut(
        keyCode: shortcut.keyCode,
        modifiers: shortcut.modifiers,
        label: formatHotkeyShortcut(shortcut),
      ),
    );
    _stopListening();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final label = formatHotkeyShortcut(widget.value);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: ListTile(
        title: const Text('Dictation hotkey'),
        subtitle: Text(
          _listening ? 'Press a key combo… (Esc cancels)' : label,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_listening)
              TextButton(
                onPressed: () {
                  widget.onChanged(kDefaultHotkeyShortcut);
                },
                child: const Text('F8'),
              ),
            TextButton(
              onPressed: () {
                if (_listening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              child: Text(_listening ? 'Cancel' : 'Change'),
            ),
          ],
        ),
        onTap: _listening ? null : _startListening,
      ),
    );
  }
}
