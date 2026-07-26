import 'package:flutter/material.dart';

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech models')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('whisper.cpp'),
            subtitle: Text('speech_runtime backend — Phase 1'),
          ),
          ListTile(
            title: Text('ONNX / Parakeet-class'),
            subtitle: Text('speech_runtime backend — Phase 3'),
          ),
          ListTile(
            title: Text('Vosk'),
            subtitle: Text('speech_runtime backend — Phase 3'),
          ),
        ],
      ),
    );
  }
}
