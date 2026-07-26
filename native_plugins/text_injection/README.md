# text_injection

Insert text into the focused Windows control and read the current selection.

## Strategies (`fv_inject_text`)

1. **SendInput** Unicode key events
2. **Clipboard** paste (`Ctrl+V`) with prior `CF_UNICODETEXT` restore
3. **UIA-assisted WM_CHAR** to the focused native HWND (last resort)

## Selection (`fv_inject_read_selection`)

1. UI Automation `TextPattern` selection
2. Clipboard `Ctrl+C` with restore

## Build

Produced as `fluidvoice_inject.dll` with the Flutter Windows runner.
