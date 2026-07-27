import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads and caches speech models (Whisper ggml + Parakeet ONNX).
class SpeechModelStore {
  SpeechModelStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultModelId = 'tiny.en';

  static const availableModelIds = <String>[
    'tiny.en',
    'base.en',
    'parakeet-tdt-0.6b-v2-int8',
  ];

  static const _catalog = <String, _ModelSpec>{
    'tiny.en': _ModelSpec.file(
      fileName: 'ggml-tiny.en.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
      minBytes: 1_000_000,
    ),
    'base.en': _ModelSpec.file(
      fileName: 'ggml-base.en.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
      minBytes: 1_000_000,
    ),
    'parakeet-tdt-0.6b-v2-int8': _ModelSpec.archive(
      dirName: 'parakeet-tdt-0.6b-v2-int8',
      archiveName: 'sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2',
    ),
  };

  static String subtitleFor(String modelId) {
    switch (modelId) {
      case 'tiny.en':
        return 'Whisper — fastest English (ggml)';
      case 'base.en':
        return 'Whisper — higher quality English (ggml)';
      case 'parakeet-tdt-0.6b-v2-int8':
        return 'Parakeet TDT 0.6B int8 — English ONNX (~400MB)';
      default:
        return modelId;
    }
  }

  Future<Directory> modelsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'FluidVoice', 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ensure [modelId] is on disk; download if needed.
  /// Returns ggml file path or Parakeet model directory path.
  Future<String> ensureModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final spec = _catalog[modelId];
    if (spec == null) {
      throw ArgumentError('Unknown model id: $modelId');
    }

    final dir = await modelsDir();
    if (spec.isArchive) {
      return _ensureArchiveModel(dir, spec, onProgress: onProgress);
    }
    return _ensureFileModel(dir, spec, modelId, onProgress: onProgress);
  }

  Future<String> _ensureFileModel(
    Directory dir,
    _ModelSpec spec,
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File(p.join(dir.path, spec.fileName!));
    if (await file.exists() && await file.length() > spec.minBytes) {
      return file.path;
    }

    await _downloadToFile(
      Uri.parse(spec.url),
      file,
      onProgress: onProgress,
    );
    return file.path;
  }

  Future<String> _ensureArchiveModel(
    Directory dir,
    _ModelSpec spec, {
    void Function(double progress)? onProgress,
  }) async {
    final modelDir = Directory(p.join(dir.path, spec.dirName!));
    if (await _isReadyParakeetDir(modelDir)) {
      return modelDir.path;
    }

    final archiveFile = File(p.join(dir.path, spec.archiveName!));
    if (!await archiveFile.exists() || await archiveFile.length() < 1_000_000) {
      await _downloadToFile(
        Uri.parse(spec.url),
        archiveFile,
        onProgress: onProgress,
      );
    } else if (onProgress != null) {
      onProgress(1.0);
    }

    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
    await modelDir.create(recursive: true);

    final bytes = await archiveFile.readAsBytes();
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    for (final entry in archive) {
      final name = entry.name.replaceAll('\\', '/');
      // Strip a single top-level folder if present.
      final parts = name.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) continue;
      final relative = parts.length > 1
          ? p.joinAll(parts.sublist(1))
          : parts.first;
      if (relative.isEmpty || relative == '.') continue;

      final outPath = p.join(modelDir.path, relative);
      if (entry.isDirectory || name.endsWith('/')) {
        await Directory(outPath).create(recursive: true);
        continue;
      }
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }

    if (!await _isReadyParakeetDir(modelDir)) {
      throw StateError(
        'Parakeet archive extracted but required ONNX files were not found',
      );
    }

    // Keep archive for re-extract; optional delete to save space:
    // await archiveFile.delete();

    return modelDir.path;
  }

  Future<bool> _isReadyParakeetDir(Directory dir) async {
    if (!await dir.exists()) return false;
    final tokens = File(p.join(dir.path, 'tokens.txt'));
    if (!await tokens.exists()) return false;
    var hasEncoder = false;
    var hasDecoder = false;
    var hasJoiner = false;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('encoder') && name.endsWith('.onnx')) {
        hasEncoder = true;
      } else if (name.startsWith('decoder') && name.endsWith('.onnx')) {
        hasDecoder = true;
      } else if (name.startsWith('joiner') && name.endsWith('.onnx')) {
        hasJoiner = true;
      }
    }
    return hasEncoder && hasDecoder && hasJoiner;
  }

  Future<void> _downloadToFile(
    Uri uri,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', uri);
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Model download failed (${response.statusCode})',
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
  }
}

class _ModelSpec {
  const _ModelSpec.file({
    required this.fileName,
    required this.url,
    required this.minBytes,
  })  : dirName = null,
        archiveName = null,
        isArchive = false;

  const _ModelSpec.archive({
    required this.dirName,
    required this.archiveName,
    required this.url,
  })  : fileName = null,
        minBytes = 0,
        isArchive = true;

  final String? fileName;
  final String? dirName;
  final String? archiveName;
  final String url;
  final int minBytes;
  final bool isArchive;
}
