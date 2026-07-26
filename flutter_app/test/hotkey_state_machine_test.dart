import 'package:flutter_test/flutter_test.dart';
import 'package:fluidvoice_app/core/models/hotkey_models.dart';
import 'package:fluidvoice_app/core/services/hotkey_state_machine.dart';

void main() {
  test('push-to-talk emits start on keyDown and stop on keyUp', () async {
    final machine = HotkeyStateMachine(
      mode: HotkeyActivationMode.pushToTalk,
      shortcut: const HotkeyShortcut(keyCode: 32),
    );
    final actions = <HotkeyMachineAction>[];
    final sub = machine.actions.listen(actions.add);

    machine.handle(
      const HotkeyEvent(type: HotkeyEventType.keyDown, keyCode: 32),
    );
    machine.handle(
      const HotkeyEvent(type: HotkeyEventType.keyUp, keyCode: 32),
    );

    await Future<void>.delayed(Duration.zero);
    expect(actions, [
      HotkeyMachineAction.startRecording,
      HotkeyMachineAction.stopRecording,
    ]);

    await sub.cancel();
    await machine.dispose();
  });
}
