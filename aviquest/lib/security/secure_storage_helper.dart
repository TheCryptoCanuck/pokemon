import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Secure storage helper that provides encrypted Hive boxes
/// using keys stored in the platform's secure storage (Android Keystore).
class SecureStorageHelper {
  SecureStorageHelper._();
  static final SecureStorageHelper instance = SecureStorageHelper._();

  static const _hiveKeyName = 'aviquest_hive_encryption_key';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Retrieve or generate the Hive encryption key from secure storage.
  /// The key is stored in Android Keystore-backed encrypted preferences.
  Future<Uint8List> getHiveEncryptionKey() async {
    final existingKey = await _secureStorage.read(key: _hiveKeyName);

    if (existingKey != null) {
      return base64Url.decode(existingKey);
    }

    // Generate a new 256-bit encryption key
    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _hiveKeyName,
      value: base64Url.encode(newKey),
    );
    return Uint8List.fromList(newKey);
  }

  /// Open an encrypted Hive box. Falls back to unencrypted if migration is needed.
  Future<Box<String>> openEncryptedBox(String boxName) async {
    final encryptionKey = await getHiveEncryptionKey();

    try {
      return await Hive.openBox<String>(
        boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (_) {
      // If opening encrypted box fails (e.g., data was previously unencrypted),
      // migrate: read old data, delete old box, re-create encrypted.
      return await _migrateToEncrypted(boxName, encryptionKey);
    }
  }

  /// Migrate an unencrypted Hive box to an encrypted one.
  Future<Box<String>> _migrateToEncrypted(
    String boxName,
    Uint8List encryptionKey,
  ) async {
    // Open old unencrypted box to read existing data
    final List<String> existingData = [];
    try {
      final oldBox = await Hive.openBox<String>(boxName);
      for (int i = 0; i < oldBox.length; i++) {
        final value = oldBox.getAt(i);
        if (value != null) existingData.add(value);
      }
      await oldBox.deleteFromDisk();
    } catch (_) {
      // If old box can't be opened either, start fresh
      await Hive.deleteBoxFromDisk(boxName);
    }

    // Create new encrypted box with migrated data
    final encryptedBox = await Hive.openBox<String>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    for (final item in existingData) {
      await encryptedBox.add(item);
    }

    return encryptedBox;
  }

  /// Securely store a key-value pair in platform secure storage.
  Future<void> secureWrite(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Read a value from platform secure storage.
  Future<String?> secureRead(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Delete a value from platform secure storage.
  Future<void> secureDelete(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// Clear all data from secure storage (use with caution).
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
