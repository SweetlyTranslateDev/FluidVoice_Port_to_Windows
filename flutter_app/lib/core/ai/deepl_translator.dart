import 'dart:convert';

import 'package:http/http.dart' as http;

/// DeepL API v2 client (bring-your-own-key; free or pro).
class DeepLTranslator {
  DeepLTranslator({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const freeBaseUrl = 'https://api-free.deepl.com';
  static const proBaseUrl = 'https://api.deepl.com';

  /// Common [target_lang] values for the DeepL translate endpoint.
  static const targetLanguages = <String, String>{
    'BG': 'Bulgarian',
    'CS': 'Czech',
    'DA': 'Danish',
    'DE': 'German',
    'EL': 'Greek',
    'EN-GB': 'English (UK)',
    'EN-US': 'English (US)',
    'ES': 'Spanish',
    'ET': 'Estonian',
    'FI': 'Finnish',
    'FR': 'French',
    'HU': 'Hungarian',
    'ID': 'Indonesian',
    'IT': 'Italian',
    'JA': 'Japanese',
    'KO': 'Korean',
    'LT': 'Lithuanian',
    'LV': 'Latvian',
    'NB': 'Norwegian',
    'NL': 'Dutch',
    'PL': 'Polish',
    'PT-BR': 'Portuguese (Brazil)',
    'PT-PT': 'Portuguese (Portugal)',
    'RO': 'Romanian',
    'RU': 'Russian',
    'SK': 'Slovak',
    'SL': 'Slovenian',
    'SV': 'Swedish',
    'TR': 'Turkish',
    'UK': 'Ukrainian',
    'ZH': 'Chinese (simplified)',
  };

  Uri _translateUri() {
    final base = apiKey.endsWith(':fx') ? freeBaseUrl : proBaseUrl;
    return Uri.parse('$base/v2/translate');
  }

  /// Translates [text] to [targetLang] (DeepL language code).
  ///
  /// [sourceLang] is optional; omit for auto-detection.
  Future<String> translate({
    required String text,
    required String targetLang,
    String? sourceLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return text;
    }
    if (apiKey.isEmpty) {
      throw StateError('DeepL API key is not configured');
    }

    final body = <String, dynamic>{
      'text': [trimmed],
      'target_lang': targetLang,
    };
    if (sourceLang != null && sourceLang.trim().isNotEmpty) {
      body['source_lang'] = sourceLang.trim();
    }

    final response = await _client.post(
      _translateUri(),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'DeepL-Auth-Key $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'DeepL request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Unexpected DeepL response shape');
    }
    final translations = decoded['translations'];
    if (translations is! List || translations.isEmpty) {
      throw StateError('DeepL response missing translations');
    }
    final first = translations.first;
    if (first is! Map) {
      throw StateError('DeepL translation entry invalid');
    }
    final translated = first['text'];
    if (translated is! String || translated.trim().isEmpty) {
      throw StateError('DeepL response missing translated text');
    }
    return translated.trim();
  }
}
