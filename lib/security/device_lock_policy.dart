/// Lock-screen policy separated from platform APIs for deterministic QA.
bool shouldRequireDeviceAuth({
  required bool previouslyEnabled,
  required bool enabled,
  required bool wasUnlocked,
  required Duration? backgroundElapsed,
  Duration grace = const Duration(seconds: 20),
}) {
  if (!enabled) return false;
  if (!previouslyEnabled || !wasUnlocked) return true;
  return backgroundElapsed != null && backgroundElapsed >= grace;
}
