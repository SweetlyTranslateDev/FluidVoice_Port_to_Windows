import 'package:flutter_test/flutter_test.dart';
import 'package:fluidvoice_app/app/app.dart';

void main() {
  testWidgets('FluidVoice app shell loads', (tester) async {
    await tester.pumpWidget(const FluidVoiceApp());
    await tester.pump();
    expect(find.text('FluidVoice'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
