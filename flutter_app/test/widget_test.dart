import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluidvoice_app/app/app.dart';

void main() {
  testWidgets('FluidVoice app shell loads', (tester) async {
    await tester.pumpWidget(const FluidVoiceApp());
    expect(find.text('FluidVoice'), findsOneWidget);
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
  });
}
