import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// Only import flutter_secure_storage on supported platforms
import 'secure_storage_stub.dart'
    if (dart.library.io) 'secure_storage_mobile.dart';

/// Service that manages PIN authentication, biometric settings, and backup codes.
/// On Android/iOS: uses flutter_secure_storage for secure key storage.
/// On Windows/Web/Desktop: falls back to shared_preferences (no ATL dependency).
class PinAuthService {
  static const _baseKeyPinHash = 'pin_hash';
  static const _baseKeyPinSet = 'pin_is_set';
  static const _baseKeyBackupCode = 'backup_code';
  static const _baseKeyFailedAttempts = 'failed_attempts';
  static const _baseKeyLockoutUntil = 'lockout_until';

  static bool get _useSecureStorage {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<String> _key(String base) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '0';
    return 'user_${userId}_$base';
  }

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationSeconds = 30;

  // ─── Cross-platform storage helpers ───

  Future<void> _write(String key, String value) async {
    if (_useSecureStorage) {
      await SecureStorageHelper.write(key, value);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<String?> _read(String key) async {
    if (_useSecureStorage) {
      return await SecureStorageHelper.read(key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> _delete(String key) async {
    if (_useSecureStorage) {
      await SecureStorageHelper.delete(key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  // ─── PIN Management ───

  /// Hash a PIN using SHA-256 with a fixed salt for consistency.
  String _hashPin(String pin) {
    final bytes = utf8.encode('expense_tracker_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  /// Check if PIN has been set up.
  Future<bool> isPinSet() async {
    final val = await _read(await _key(_baseKeyPinSet));
    return val == 'true';
  }

  /// Set a new PIN. Returns the generated backup code.
  Future<String> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _write(await _key(_baseKeyPinHash), hash);
    await _write(await _key(_baseKeyPinSet), 'true');
    await _resetFailedAttempts();

    // Generate and store backup code
    final backupCode = _generateBackupCode();
    await _write(await _key(_baseKeyBackupCode), backupCode);

    return backupCode;
  }

  /// Verify a PIN against the stored hash.
  Future<bool> verifyPin(String pin) async {
    // Check lockout
    if (await _isLockedOut()) return false;

    final storedHash = await _read(await _key(_baseKeyPinHash));
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    final isValid = storedHash == inputHash;

    if (isValid) {
      await _resetFailedAttempts();
    } else {
      await _incrementFailedAttempts();
    }

    return isValid;
  }

  /// Change PIN (requires old PIN verification first).
  Future<bool> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) return false;

    final hash = _hashPin(newPin);
    await _write(await _key(_baseKeyPinHash), hash);
    return true;
  }

  /// Remove PIN and all auth data.
  Future<void> clearPin() async {
    await _delete(await _key(_baseKeyPinHash));
    await _delete(await _key(_baseKeyPinSet));
    await _delete(await _key(_baseKeyBackupCode));
    await _resetFailedAttempts();
  }

  // ─── Backup Code ───

  String _generateBackupCode() {
    final random = Random.secure();
    final segments = List.generate(3, (_) {
      return (random.nextInt(9000) + 1000).toString();
    });
    return segments.join('-');
  }

  Future<String?> getBackupCode() async {
    return await _read(await _key(_baseKeyBackupCode));
  }

  Future<bool> verifyBackupCode(String code) async {
    final stored = await _read(await _key(_baseKeyBackupCode));
    if (stored == null) return false;
    return stored == code.trim();
  }

  /// Reset PIN using backup code. Returns new backup code on success.
  Future<String?> resetPinWithBackup(String backupCode, String newPin) async {
    final isValid = await verifyBackupCode(backupCode);
    if (!isValid) return null;

    final hash = _hashPin(newPin);
    await _write(await _key(_baseKeyPinHash), hash);
    await _resetFailedAttempts();

    // Generate new backup code
    final newBackupCode = _generateBackupCode();
    await _write(await _key(_baseKeyBackupCode), newBackupCode);

    return newBackupCode;
  }

  Future<int> getFailedAttempts() async {
    final val = await _read(await _key(_baseKeyFailedAttempts));
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<void> _incrementFailedAttempts() async {
    final current = await getFailedAttempts();
    final next = current + 1;
    await _write(await _key(_baseKeyFailedAttempts), next.toString());

    if (next >= maxFailedAttempts) {
      final lockUntil = DateTime.now()
          .add(const Duration(seconds: lockoutDurationSeconds));
      await _write(
        await _key(_baseKeyLockoutUntil),
        lockUntil.toIso8601String(),
      );
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _write(await _key(_baseKeyFailedAttempts), '0');
    await _delete(await _key(_baseKeyLockoutUntil));
  }

  Future<bool> _isLockedOut() async {
    final lockStr = await _read(await _key(_baseKeyLockoutUntil));
    if (lockStr == null) return false;

    final lockUntil = DateTime.tryParse(lockStr);
    if (lockUntil == null) return false;

    if (DateTime.now().isBefore(lockUntil)) {
      return true;
    } else {
      // Lockout expired, reset
      await _resetFailedAttempts();
      return false;
    }
  }

  Future<Duration?> getRemainingLockout() async {
    final lockStr = await _read(await _key(_baseKeyLockoutUntil));
    if (lockStr == null) return null;

    final lockUntil = DateTime.tryParse(lockStr);
    if (lockUntil == null) return null;

    final remaining = lockUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      await _resetFailedAttempts();
      return null;
    }
    return remaining;
  }

  /// Wipe all secure storage (for "Forgot PIN - Clear Data" flow).
  Future<void> clearAllData() async {
    await _delete(await _key(_baseKeyPinHash));
    await _delete(await _key(_baseKeyPinSet));
    await _delete(await _key(_baseKeyBackupCode));
    await _delete(await _key(_baseKeyFailedAttempts));
    await _delete(await _key(_baseKeyLockoutUntil));
  }
}
