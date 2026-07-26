/// Secure secret storage (Windows Credential Manager / DPAPI behind this).
abstract class CredentialsStore {
  Future<void> writeSecret(String key, String value);

  Future<String?> readSecret(String key);

  Future<void> deleteSecret(String key);
}
