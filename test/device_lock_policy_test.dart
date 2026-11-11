import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/security/device_lock_policy.dart';

void main() {
  bool requiredLock({
    bool before = true,
    bool now = true,
    bool unlocked = true,
    Duration? background,
  }) => shouldRequireDeviceAuth(
    previouslyEnabled: before,
    enabled: now,
    wasUnlocked: unlocked,
    backgroundElapsed: background,
  );

  test('no lock when feature disabled', () {
    expect(requiredLock(before: false, now: false), false);
    expect(requiredLock(now: false,
      background: const Duration(hours: 1)), false);
  });

  test('newly enabled device lock challenges the user', () {
    expect(requiredLock(before: false, now: true), true);
  });

  test('already locked stays locked', () {
    expect(requiredLock(unlocked: false), true);
  });

  test('file selector returns within grace without losing state', () {
    expect(requiredLock(background: const Duration(seconds: 19)), false);
    expect(requiredLock(background: Duration.zero), false);
  });

  test('long background return locks immediately', () {
    expect(requiredLock(background: const Duration(seconds: 20)), true);
    expect(requiredLock(background: const Duration(minutes: 5)), true);
  });

  test('no lifecycle transition keeps unlocked session', () {
    expect(requiredLock(), false);
  });
}
