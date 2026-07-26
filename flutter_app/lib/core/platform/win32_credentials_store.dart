import 'package:flutter/services.dart';

import '../interfaces/credentials_store.dart';

/// [CredentialsStore] via Windows Credential Manager (`fluidvoice/credentials`).
class Win32CredentialsStore implements CredentialsStore {
  Win32CredentialsStore({
    MethodChannel channel = const MethodChannel('fluidvoice/credentials'),
  }) : _channel = channel;

  final MethodChannel _channel;

  static const aiApiKey = 'ai_api_key';

  @override
  Future<void> writeSecret(String key, String value) async {
    await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
  }

  @override
  Future<String?> readSecret(String key) async {
    final value = await _channel.invokeMethod<String>('read', {'key': key});
    return value;
  }

  @override
  Future<void> deleteSecret(String key) async {
    await _channel.invokeMethod<void>('delete', {'key': key});
  }
}
