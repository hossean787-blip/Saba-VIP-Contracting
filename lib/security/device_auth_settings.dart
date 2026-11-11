import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An optional *presentation lock* based on the device's own credentials.
/// It does not encrypt the application's SQLite database at rest.
class DeviceAuthSettings {
  DeviceAuthSettings._();
  static const key = 'saba_vip.require_device_auth';

  static Future<bool> isEnabled() async =>
      await SharedPreferencesAsync().getBool(key) ?? false;

  static Future<void> setEnabled(bool enabled) async {
    await SharedPreferencesAsync().setBool(key, enabled);
  }

  static Future<bool> authenticate() async {
    final authentication = LocalAuthentication();
    if (!await authentication.isDeviceSupported()) return false;
    return authentication.authenticate(
      localizedReason: 'برای دسترسی به اطلاعات مالی پیمانکاری، هویت خود را تأیید کنید.',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
  }
}
