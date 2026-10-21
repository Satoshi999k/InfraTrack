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
  }) : _authentication = authentication ?? LocalAuthentication(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _enabledKey = 'biometric_sign_in_enabled';
  static const _emailKey = 'biometric_sign_in_email';
  static const _passwordKey = 'biometric_sign_in_password';

  final LocalAuthentication _authentication;
  final FlutterSecureStorage _secureStorage;

  Future<bool> get isEnabled async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
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
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_enabledKey, true);
    } catch (_) {
      await disable();
      rethrow;
    }
  }

  Future<BiometricCredentials?> readCredentials() async {
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);
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
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
  }
}

final biometricSignIn = BiometricSignInService();
