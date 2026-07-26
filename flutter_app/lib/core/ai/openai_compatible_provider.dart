import 'dart:convert';

import 'package:http/http.dart' as http;

import '../interfaces/ai_provider.dart';

/// Chat Completions client for OpenAI-compatible endpoints.
class OpenAiCompatibleProvider implements AIProvider {
  OpenAiCompatibleProvider({
    required this.baseUrl,
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _client;

  Uri _chatUri() {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (root.endsWith('/v1')) {
      return Uri.parse('$root/chat/completions');
    }
    return Uri.parse('$root/v1/chat/completions');
  }

  @override
  Future<String> rewrite({required String transcript}) {
    return enhance(
      transcript: transcript,
      systemPrompt:
          'Rewrite the following dictated text for clarity and grammar. '
          'Preserve meaning. Return only the rewritten text.',
    );
  }

  @override
  Future<String> write({required String transcript}) {
    return enhance(
      transcript: transcript,
      systemPrompt:
          'Turn the following rough dictation into clear written prose. '
          'Fix grammar, add punctuation, and improve flow. '
          'Return only the written text.',
    );
  }

  @override
  Future<String> enhance({
    required String transcript,
    String? systemPrompt,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return transcript;
    }
    if (apiKey.isEmpty) {
      throw StateError('AI API key is not configured');
    }

    final body = {
      'model': model,
      'temperature': 0.2,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt ??
              'Clean up this dictation: fix punctuation and obvious ASR errors. '
                  'Do not add new content. Return only the cleaned text.',
        },
        {'role': 'user', 'content': trimmed},
      ],
    };

    final response = await _client.post(
      _chatUri(),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'AI request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Unexpected AI response shape');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('AI response missing choices');
    }
    final message = choices.first['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw StateError('AI response missing content');
    }
    return content.trim();
  }
}
