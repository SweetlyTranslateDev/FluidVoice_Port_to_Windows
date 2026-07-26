import 'package:flutter_test/flutter_test.dart';
import 'package:fluidvoice_app/app/app.dart';

void main() {
  testWidgets('FluidVoice app shell loads', (tester) async {
    await tester.pumpWidget(const FluidVoiceApp());
    expect(find.text('FluidVoice'), findsOneWidget);
    expect(find.textContaining('Phase 0'), findsOneWidget);
  });
}
