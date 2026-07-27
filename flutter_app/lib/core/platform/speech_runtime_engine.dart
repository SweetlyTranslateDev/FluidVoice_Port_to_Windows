import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../interfaces/speech_engine.dart';
import '../models/audio_models.dart';
import '../models/transcript_models.dart';
import 'speech_model_store.dart';
import 'speech_runtime_binding.dart';

/// [SpeechEngine] backed by native speech_runtime (Whisper / Parakeet).
///
/// All FFI calls run on one long-lived worker isolate so ONNX Runtime is not
/// created on the UI thread and then used from a different thread (hang risk).
class SpeechRuntimeEngine implements SpeechEngine {
  SpeechRuntimeEngine({
    SpeechModelStore? modelStore,
  }) : _models = modelStore ?? SpeechModelStore();

  final SpeechModelStore _models;
  final _transcriptController = StreamController<TranscriptEvent>.broadcast();

  SendPort? _worker;
  Future<void>? _workerReady;
  int _nextRequestId = 1;
  final _pending = <int, Completer<Object?>>{};
  StreamSubscription<dynamic>? _replySub;
  ReceivePort? _replies;
  String? _readyModelId;

  /// Currently prepared model id, if any.
  String? get readyModelId => _readyModelId;

  bool get isNativeAvailable => SpeechRuntimeBinding.tryOpen() != null;

  @override
  Stream<TranscriptEvent> get transcripts => _transcriptController.stream;

  Future<void> _ensureWorker() async {
    if (_worker != null) return;
    final existing = _workerReady;
    if (existing != null) {
      await existing;
      return;
    }

    final handshake = Completer<void>();
    _workerReady = handshake.future;

    final replies = ReceivePort();
    _replies = replies;
    _replySub = replies.listen((message) {
      if (message is _SpeechWorkerReady) {
        _worker = message.sendPort;
        if (!handshake.isCompleted) handshake.complete();
        return;
      }
      if (message is _SpeechWorkerResponse) {
        final c = _pending.remove(message.id);
        if (c == null) return;
        if (message.error != null) {
          c.completeError(StateError(message.error!));
        } else {
          c.complete(message.result);
        }
      }
    });

    try {
      await Isolate.spawn(_speechWorkerMain, replies.sendPort);
      await handshake.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Speech worker isolate failed to start');
        },
      );
    } catch (e) {
      _workerReady = null;
      await _replySub?.cancel();
      _replySub = null;
      replies.close();
      _replies = null;
      rethrow;
    }
  }

  Future<Object?> _callWorker(String method, Object? args) async {
    await _ensureWorker();
    final worker = _worker;
    if (worker == null) {
      throw StateError('Speech worker not ready');
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    worker.send(_SpeechWorkerRequest(id: id, method: method, args: args));
    return completer.future;
  }

  @override
  Future<void> prepare({required String modelId}) async {
    if (_readyModelId == modelId) {
      return;
    }
    final path = await _models.ensureModel(modelId);
    await _callWorker('prepare', path);
    _readyModelId = modelId;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> streamAudio(AudioChunk chunk) async {
    // Batch path for MVP; streaming segments come later.
  }

  @override
  Future<TranscriptResult> transcribe(AudioBuffer audio) async {
    if (_readyModelId == null) {
      await prepare(modelId: SpeechModelStore.defaultModelId);
    }
    final samples = Float32List.fromList(
      audio.samples.map((e) => e.toDouble()).toList(growable: false),
    );
    final text = await _callWorker('transcribe', <Object?>[
          samples,
          audio.sampleRate,
        ]) as String? ??
        '';
    final result = TranscriptResult(text: text, rawText: text);
    if (!_transcriptController.isClosed && text.isNotEmpty) {
      _transcriptController.add(
        TranscriptEvent(text: text, isFinal: true),
      );
    }
    return result;
  }

  @override
  Future<void> dispose() async {
    if (_worker != null) {
      try {
        await _callWorker('shutdown', null);
      } catch (_) {}
    }
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('Speech engine disposed'));
      }
    }
    _pending.clear();
    await _replySub?.cancel();
    _replySub = null;
    _replies?.close();
    _replies = null;
    _worker = null;
    _workerReady = null;
    _readyModelId = null;
    await _transcriptController.close();
  }
}

final class _SpeechWorkerReady {
  _SpeechWorkerReady(this.sendPort);
  final SendPort sendPort;
}

final class _SpeechWorkerRequest {
  _SpeechWorkerRequest({
    required this.id,
    required this.method,
    required this.args,
  });

  final int id;
  final String method;
  final Object? args;
}

final class _SpeechWorkerResponse {
  _SpeechWorkerResponse({
    required this.id,
    this.result,
    this.error,
  });

  final int id;
  final Object? result;
  final String? error;
}

void _speechWorkerMain(SendPort replies) {
  final commands = ReceivePort();
  replies.send(_SpeechWorkerReady(commands.sendPort));

  SpeechRuntimeBinding? binding;
  var initialized = false;

  SpeechRuntimeBinding open() {
    final existing = binding;
    if (existing != null) return existing;
    final opened = SpeechRuntimeBinding.tryOpen();
    if (opened == null) {
      throw StateError(
        'fluidvoice_speech.dll not found. Build Flutter Windows to produce it.',
      );
    }
    binding = opened;
    return opened;
  }

  commands.listen((message) {
    if (message is! _SpeechWorkerRequest) return;
    try {
      final b = open();
      switch (message.method) {
        case 'prepare':
          if (!initialized) {
            b.init();
            initialized = true;
          }
          b.prepare(message.args! as String);
          replies.send(_SpeechWorkerResponse(id: message.id));
        case 'transcribe':
          if (!initialized) {
            b.init();
            initialized = true;
          }
          final args = message.args! as List<Object?>;
          final samples = args[0] as Float32List;
          final sampleRate = args[1] as int;
          final text = b.transcribeFloats(samples, sampleRate: sampleRate);
          replies.send(_SpeechWorkerResponse(id: message.id, result: text));
        case 'shutdown':
          if (initialized) {
            b.shutdown();
            initialized = false;
          }
          replies.send(_SpeechWorkerResponse(id: message.id));
        default:
          replies.send(
            _SpeechWorkerResponse(
              id: message.id,
              error: 'Unknown speech worker method: ${message.method}',
            ),
          );
      }
    } catch (e) {
      replies.send(
        _SpeechWorkerResponse(id: message.id, error: e.toString()),
      );
    }
  });
}
