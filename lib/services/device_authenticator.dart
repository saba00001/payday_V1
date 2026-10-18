import 'package:local_auth/local_auth.dart';

class DeviceAuthenticator {
  DeviceAuthenticator._();

  static final LocalAuthentication _authentication = LocalAuthentication();

  static Future<bool> authenticate({
    required String localizedReason,
  }) {
    return _authentication.authenticate(
      localizedReason: localizedReason,
      persistAcrossBackgrounding: true,
    );
  }
}
