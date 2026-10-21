import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricCredentials {
  const BiometricCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class BiometricSignInService {
  BiometricSignInService({
    LocalAuthentication? authentication,
    FlutterSecureStorage? secureStorage,
    BiometricCredentialStore? credentialStore,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _credentialStore =
           credentialStore ??
           _FlutterSecureCredentialStore(
             secureStorage ?? const FlutterSecureStorage(),
           );

  static const _enabledKey = 'biometric_sign_in_enabled';
  static const _emailKey = 'biometric_sign_in_email';
  static const _passwordKey = 'biometric_sign_in_password';

  final LocalAuthentication _authentication;
  final BiometricCredentialStore _credentialStore;

  Future<bool> get isEnabled async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_enabledKey) ?? false)) return false;
    final email = await _credentialStore.read(_emailKey);
    final password = await _credentialStore.read(_passwordKey);
    if (email != null && password != null) return true;
    await disable();
    return false;
  }

  Future<bool> isEnabledFor(String? email) async {
    if (email == null || email.trim().isEmpty || !await isEnabled) {
      return false;
    }
    final ownerEmail = await _credentialStore.read(_emailKey);
    return ownerEmail?.trim().toLowerCase() == email.trim().toLowerCase();
  }

  Future<void> disableIfAccountMismatch(String email) async {
    if (!await isEnabled) return;
    final ownerEmail = await _credentialStore.read(_emailKey);
    if (ownerEmail?.trim().toLowerCase() != email.trim().toLowerCase()) {
      await disable();
    }
  }

  Future<bool> get isAvailable async {
    if (!await _authentication.isDeviceSupported() ||
        !await _authentication.canCheckBiometrics) {
      return false;
    }
    return (await _authentication.getAvailableBiometrics()).isNotEmpty;
  }

  Future<bool> authenticate(String reason) => _authentication.authenticate(
    localizedReason: reason,
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );

  Future<void> enable({required String email, required String password}) async {
    try {
      await _credentialStore.write(_emailKey, email);
      await _credentialStore.write(_passwordKey, password);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_enabledKey, true);
    } catch (_) {
      await disable();
      rethrow;
    }
  }

  Future<BiometricCredentials?> readCredentials() async {
    if (!await isEnabled) return null;
    final email = await _credentialStore.read(_emailKey);
    final password = await _credentialStore.read(_passwordKey);
    if (email == null && password == null) {
      await disable();
      return null;
    }
    if (email == null || password == null) {
      await disable();
      throw StateError('Saved biometric sign-in details are incomplete.');
    }
    return BiometricCredentials(email: email, password: password);
  }

  Future<void> disable() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    await _credentialStore.delete(_emailKey);
    await _credentialStore.delete(_passwordKey);
  }
}

abstract interface class BiometricCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureCredentialStore implements BiometricCredentialStore {
  const _FlutterSecureCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final biometricSignIn = BiometricSignInService();
