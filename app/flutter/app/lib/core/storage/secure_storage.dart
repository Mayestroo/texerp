import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage wrapper for authentication tokens.
///
/// Only the refresh token is persisted to disk. The access token is kept in
/// memory (AuthBloc state / [TokenProvider]) as required by the security model.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'refresh_token';
  static const _usePinLockKey = 'use_pin_lock';
  static const _useBiometricKey = 'use_biometric';
  static const _savedPinKey = 'saved_pin';

  final FlutterSecureStorage _storage;

  /// Saves the refresh token to secure storage.
  ///
  /// The access token is accepted for API symmetry but is intentionally not
  /// persisted.
  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  /// Always returns null because the access token is held in memory only.
  Future<String?> loadAccessToken() async => null;

  /// Loads the persisted refresh token, if any.
  Future<String?> loadRefreshToken() async => _storage.read(key: _refreshTokenKey);

  /// Clears all persisted tokens.
  Future<void> clearTokens() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // Use PIN Lock preference
  Future<void> setUsePinLock(bool value) async {
    await _storage.write(key: _usePinLockKey, value: value.toString());
  }

  Future<bool> getUsePinLock() async {
    final value = await _storage.read(key: _usePinLockKey);
    return value == 'true';
  }

  // Use Biometrics preference
  Future<void> setUseBiometric(bool value) async {
    await _storage.write(key: _useBiometricKey, value: value.toString());
  }

  Future<bool> getUseBiometric() async {
    final value = await _storage.read(key: _useBiometricKey);
    return value == 'true';
  }

  // Local saved PIN for locking
  Future<void> saveSavedPin(String pin) async {
    await _storage.write(key: _savedPinKey, value: pin);
  }

  Future<String?> loadSavedPin() async {
    return _storage.read(key: _savedPinKey);
  }

  Future<void> deleteSavedPin() async {
    await _storage.delete(key: _savedPinKey);
  }
}
