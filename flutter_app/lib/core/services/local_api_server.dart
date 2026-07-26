import 'dart:convert';
import 'dart:io';

import '../ai/openai_compatible_provider.dart';
import '../interfaces/ai_provider.dart';
import '../interfaces/speech_engine.dart';
import '../models/audio_models.dart';
import '../platform/win32_credentials_store.dart';
import 'history_manager.dart';
import 'settings_manager.dart';

/// Loopback-only HTTP API (macOS LocalAPI parity subset).
///
/// Binds `127.0.0.1` only — never `0.0.0.0`.
class LocalApiServer {
  LocalApiServer({
    required this.settings,
    required this.history,
    this.speechEngine,
    this.port = defaultPort,
  });

  static const defaultPort = 47733;

  final SettingsManager settings;
  final HistoryManager history;
  final SpeechEngine? speechEngine;
  final int port;

  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final remote = request.connectionInfo?.remoteAddress;
    if (remote == null || !_isLoopback(remote)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/v1/health') {
        await _json(request, {'status': 'ok', 'version': '1.0.0'});
        return;
      }
      if (request.method == 'GET' && path == '/v1/history') {
        await history.load();
        await _json(request, {
          'entries': [
            for (final e in history.entries)
              {
                'id': e.id,
                'text': e.text,
                'rawText': e.rawText,
                'createdAt': e.createdAt.toIso8601String(),
              },
          ],
        });
        return;
      }
      if (request.method == 'POST' && path == '/v1/postprocess') {
        final body = await _readJson(request);
        final text = body['text']?.toString() ?? '';
        final mode = body['mode']?.toString() ?? 'enhance';
        if (text.isEmpty) {
          await _error(request, 'Missing text', status: 400);
          return;
        }
        final provider = await _aiProvider();
        if (provider == null) {
          await _error(request, 'AI provider not configured', status: 400);
          return;
        }
        final out = switch (mode) {
          'rewrite' => await provider.rewrite(transcript: text),
          'write' => await provider.write(transcript: text),
          _ => await provider.enhance(transcript: text),
        };
        await _json(request, {'text': out});
        return;
      }
      if (request.method == 'POST' && path == '/v1/transcribe') {
        final engine = speechEngine;
        if (engine == null) {
          await _error(request, 'Speech engine unavailable', status: 503);
          return;
        }
        final body = await _readJson(request);
        final samplesRaw = body['samples'];
        if (samplesRaw is! List || samplesRaw.isEmpty) {
          await _error(
            request,
            'Provide JSON { "samples": [float...], "sampleRate": 16000 }',
            status: 400,
          );
          return;
        }
        final samples = <double>[
          for (final s in samplesRaw) (s as num).toDouble(),
        ];
        final sampleRate = (body['sampleRate'] as num?)?.toInt() ?? 16000;
        final result = await engine.transcribe(
          AudioBuffer(samples: samples, sampleRate: sampleRate, channels: 1),
        );
        await _json(request, {'text': result.text, 'rawText': result.rawText});
        return;
      }

      await _error(request, 'Route not found.', status: 404);
    } catch (e) {
      await _error(request, e.toString(), status: 500);
    }
  }

  Future<AIProvider?> _aiProvider() async {
    final key = await Win32CredentialsStore()
        .readSecret(Win32CredentialsStore.aiApiKey);
    if (key == null || key.isEmpty) {
      return null;
    }
    final base = (settings.aiBaseUrl == null || settings.aiBaseUrl!.isEmpty)
        ? 'https://api.openai.com/v1'
        : settings.aiBaseUrl!;
    return OpenAiCompatibleProvider(baseUrl: base, apiKey: key);
  }

  bool _isLoopback(InternetAddress address) {
    return address.isLoopback ||
        address.address == '127.0.0.1' ||
        address.address == '::1';
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  Future<void> _json(HttpRequest request, Object body) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _error(
    HttpRequest request,
    String message, {
    required int status,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': message}));
    await request.response.close();
  }
}
