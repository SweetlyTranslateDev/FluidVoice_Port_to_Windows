import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads and caches Whisper ggml models under app support / models.
class WhisperModelStore {
  WhisperModelStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultModelId = 'tiny.en';

  static const availableModelIds = <String>['tiny.en', 'base.en'];

  static const _catalog = <String, _ModelSpec>{
    'tiny.en': _ModelSpec(
      fileName: 'ggml-tiny.en.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
    ),
    'base.en': _ModelSpec(
      fileName: 'ggml-base.en.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
    ),
  };

  Future<Directory> modelsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'FluidVoice', 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ensure [modelId] is on disk; download if needed. Returns absolute path.
  Future<String> ensureModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final spec = _catalog[modelId];
    if (spec == null) {
      throw ArgumentError('Unknown model id: $modelId');
    }

    final dir = await modelsDir();
    final file = File(p.join(dir.path, spec.fileName));
    if (await file.exists() && await file.length() > 1_000_000) {
      return file.path;
    }

    final uri = Uri.parse(spec.url);
    final request = http.Request('GET', uri);
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Model download failed (${response.statusCode}) for $modelId',
        uri: uri,
      );
    }

    final total = response.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
    await sink.close();
    return file.path;
  }
}

class _ModelSpec {
  const _ModelSpec({required this.fileName, required this.url});

  final String fileName;
  final String url;
}
