import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> canAuthenticate() async {
    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return isAvailable || isDeviceSupported;
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Войдите с помощью отпечатка пальца или Face ID',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> saveCredentials(String login, String password) async {
    await _storage.write(key: 'login', value: login);
    await _storage.write(key: 'password', value: password);
  }

  Future<Map<String, String?>> getCredentials() async {
    final login = await _storage.read(key: 'login');
    final password = await _storage.read(key: 'password');
    return {'login': login, 'password': password};
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: 'login');
    await _storage.delete(key: 'password');
  }
}