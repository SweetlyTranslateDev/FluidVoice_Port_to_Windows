import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads and caches speech models (Whisper ggml + Parakeet ONNX).
class SpeechModelStore {
  SpeechModelStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultModelId = 'tiny.en';

  static const _hfWhisper =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  /// Built-in selectable ids (catalog downloads).
  static const availableModelIds = <String>[
    'tiny.en',
    'base.en',
    'small.en',
    'tiny',
    'base',
    'small',
    'medium.en',
    'medium',
    'parakeet-tdt-0.6b-v2-int8',
  ];

  static const _catalog = <String, _ModelSpec>{
    'tiny.en': _ModelSpec.file(
      fileName: 'ggml-tiny.en.bin',
      url: '$_hfWhisper/ggml-tiny.en.bin',
      minBytes: 1_000_000,
    ),
    'base.en': _ModelSpec.file(
      fileName: 'ggml-base.en.bin',
      url: '$_hfWhisper/ggml-base.en.bin',
      minBytes: 1_000_000,
    ),
    'small.en': _ModelSpec.file(
      fileName: 'ggml-small.en.bin',
      url: '$_hfWhisper/ggml-small.en.bin',
      minBytes: 1_000_000,
    ),
    'tiny': _ModelSpec.file(
      fileName: 'ggml-tiny.bin',
      url: '$_hfWhisper/ggml-tiny.bin',
      minBytes: 1_000_000,
    ),
    'base': _ModelSpec.file(
      fileName: 'ggml-base.bin',
      url: '$_hfWhisper/ggml-base.bin',
      minBytes: 1_000_000,
    ),
    'small': _ModelSpec.file(
      fileName: 'ggml-small.bin',
      url: '$_hfWhisper/ggml-small.bin',
      minBytes: 1_000_000,
    ),
    'medium.en': _ModelSpec.file(
      fileName: 'ggml-medium.en.bin',
      url: '$_hfWhisper/ggml-medium.en.bin',
      minBytes: 1_000_000,
    ),
    'medium': _ModelSpec.file(
      fileName: 'ggml-medium.bin',
      url: '$_hfWhisper/ggml-medium.bin',
      minBytes: 1_000_000,
    ),
    'parakeet-tdt-0.6b-v2-int8': _ModelSpec.archive(
      dirName: 'parakeet-tdt-0.6b-v2-int8',
      archiveName: 'sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2',
    ),
  };

  /// English-only Whisper ids end with `.en`; multilingual Whisper has no suffix.
  static bool isMultilingualWhisper(String modelId) {
    if (modelId.startsWith('parakeet')) return false;
    if (modelId.endsWith('.en')) return false;
    if (_catalog.containsKey(modelId) && !_catalog[modelId]!.isArchive) {
      return true;
    }
    // Custom ggml without .en is treated as multilingual.
    return !modelId.contains('.en');
  }

  static String subtitleFor(String modelId) {
    switch (modelId) {
      case 'tiny.en':
        return 'Whisper — fastest English (ggml)';
      case 'base.en':
        return 'Whisper — higher quality English (ggml)';
      case 'small.en':
        return 'Whisper — best English quality in built-ins (ggml, larger)';
      case 'tiny':
        return 'Whisper multilingual — fastest, auto language detect (ggml)';
      case 'base':
        return 'Whisper multilingual — higher quality, auto language detect';
      case 'small':
        return 'Whisper multilingual — higher quality (ggml, larger download)';
      case 'medium.en':
        return 'Whisper English medium — high quality (ggml, ~1.5GB)';
      case 'medium':
        return 'Whisper multilingual medium — high quality (ggml, ~1.5GB)';
      case 'parakeet-tdt-0.6b-v2-int8':
        return 'Parakeet TDT 0.6B int8 — English ONNX (~400MB)';
      default:
        return 'Custom Whisper ggml';
    }
  }

  static String? idFromGgmlFileName(String fileName) {
    final base = p.basename(fileName);
    if (!base.startsWith('ggml-') || !base.endsWith('.bin')) return null;
    return base.substring('ggml-'.length, base.length - '.bin'.length);
  }

  Future<Directory> modelsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'FluidVoice', 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Built-in catalog plus any `ggml-*.bin` already on disk (imported/custom).
  Future<List<String>> listSelectableModelIds() async {
    final ids = <String>{...availableModelIds};
    final dir = await modelsDir();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final id = idFromGgmlFileName(entity.path);
      if (id != null && id.isNotEmpty) {
        ids.add(id);
      }
    }
    final sorted = ids.toList()
      ..sort((a, b) {
        final ai = availableModelIds.indexOf(a);
        final bi = availableModelIds.indexOf(b);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        if (ai >= 0) return -1;
        if (bi >= 0) return 1;
        return a.compareTo(b);
      });
    return sorted;
  }

  Future<List<String>> listCustomModelIds() async {
    final all = await listSelectableModelIds();
    return all.where((id) => !availableModelIds.contains(id)).toList();
  }

  /// Ensure [modelId] is on disk; download if needed.
  /// Returns ggml file path or Parakeet model directory path.
  Future<String> ensureModel(
    String modelId, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final dir = await modelsDir();
    final local = File(p.join(dir.path, 'ggml-$modelId.bin'));
    if (await local.exists() && await local.length() > 500_000) {
      return local.path;
    }

    final spec = _catalog[modelId];
    if (spec == null) {
      throw ArgumentError(
        'Unknown model id: $modelId. Import a ggml .bin or download from URL.',
      );
    }

    if (spec.isArchive) {
      return _ensureArchiveModel(
        dir,
        spec,
        onProgress: onProgress,
        onStatus: onStatus,
      );
    }
    onStatus?.call('Downloading $modelId…');
    return _ensureFileModel(dir, spec, modelId, onProgress: onProgress);
  }

  /// Copy a local Whisper ggml `.bin` into the models folder and return its id.
  Future<String> importLocalGgml(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ArgumentError('File not found: $sourcePath');
    }
    var name = p.basename(sourcePath);
    if (!name.toLowerCase().endsWith('.bin')) {
      throw ArgumentError('Expected a Whisper ggml .bin file');
    }
    if (!name.startsWith('ggml-')) {
      name = 'ggml-$name';
    }
    final id = idFromGgmlFileName(name);
    if (id == null || id.isEmpty) {
      throw ArgumentError('Could not derive model id from $name');
    }
    final dest = File(p.join((await modelsDir()).path, name));
    if (p.normalize(source.absolute.path) != p.normalize(dest.absolute.path)) {
      await source.copy(dest.path);
    }
    return id;
  }

  /// Download a Whisper ggml from a direct URL (e.g. Hugging Face resolve link).
  Future<String> downloadFromUrl(
    String url, {
    String? modelId,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final uri = Uri.parse(url.trim());
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError('URL must be http(s)');
    }

    var fileName = p.basename(uri.path);
    if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.bin')) {
      final id = (modelId == null || modelId.isEmpty) ? 'custom' : modelId;
      fileName = id.startsWith('ggml-') ? '$id.bin' : 'ggml-$id.bin';
    }
    if (!fileName.startsWith('ggml-')) {
      fileName = 'ggml-$fileName';
    }
    final id = modelId?.trim().isNotEmpty == true
        ? modelId!.trim()
        : idFromGgmlFileName(fileName)!;
    final destName = 'ggml-$id.bin';
    final dest = File(p.join((await modelsDir()).path, destName));

    onStatus?.call('Downloading $id…');
    await _downloadToFile(uri, dest, onProgress: onProgress);
    if (await dest.length() < 500_000) {
      await dest.delete();
      throw StateError('Downloaded file looks too small to be a ggml model');
    }
    return id;
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
    void Function(String status)? onStatus,
  }) async {
    final modelDir = Directory(p.join(dir.path, spec.dirName!));
    if (await _isReadyParakeetDir(modelDir)) {
      return modelDir.path;
    }

    final archiveFile = File(p.join(dir.path, spec.archiveName!));
    if (!await archiveFile.exists() || await archiveFile.length() < 1_000_000) {
      onStatus?.call('Downloading ${spec.dirName}…');
      await _downloadToFile(
        Uri.parse(spec.url),
        archiveFile,
        onProgress: onProgress,
      );
    } else if (onProgress != null) {
      onProgress(1.0);
    }

    onStatus?.call('Extracting ${spec.dirName}…');
    onProgress?.call(1.0);
    await Isolate.run(
      () => _extractParakeetArchiveSync(
        archiveFile.path,
        modelDir.path,
      ),
    );

    if (!await _isReadyParakeetDir(modelDir)) {
      throw StateError(
        'Parakeet archive extracted but required ONNX files were not found',
      );
    }

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

void _extractParakeetArchiveSync(String archivePath, String modelDirPath) {
  final modelDir = Directory(modelDirPath);
  if (modelDir.existsSync()) {
    modelDir.deleteSync(recursive: true);
  }
  modelDir.createSync(recursive: true);

  final bytes = File(archivePath).readAsBytesSync();
  final tarBytes = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tarBytes);

  for (final entry in archive) {
    final name = entry.name.replaceAll('\\', '/');
    final parts = name.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) continue;
    final relative =
        parts.length > 1 ? p.joinAll(parts.sublist(1)) : parts.first;
    if (relative.isEmpty || relative == '.') continue;

    final outPath = p.join(modelDirPath, relative);
    if (entry.isDirectory || name.endsWith('/')) {
      Directory(outPath).createSync(recursive: true);
      continue;
    }
    final outFile = File(outPath);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(entry.content as List<int>);
  }
}
