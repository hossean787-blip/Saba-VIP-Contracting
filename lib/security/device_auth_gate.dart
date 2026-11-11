import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'device_auth_settings.dart';

/// Locks the visible accounting workspace on a *real* background return.
/// A short grace period avoids discarding an in-progress Android file picker.
class DeviceAuthGate extends StatefulWidget {
  const DeviceAuthGate({super.key, required this.child});
  final Widget child;

  @override
  State<DeviceAuthGate> createState() => _DeviceAuthGateState();
}

class _DeviceAuthGateState extends State<DeviceAuthGate>
    with WidgetsBindingObserver {
  static const backgroundGrace = Duration(seconds: 20);
  bool _checking = true;
  bool _enabled = false;
  bool _unlocked = false;
  bool _authenticating = false;
  DateTime? _backgroundedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final enabled = await DeviceAuthSettings.isEnabled();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _unlocked = !enabled;
        _checking = false;
      });
      if (enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _unlock();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _enabled = true;
        _unlocked = false;
        _error = 'بررسی تنظیمات امنیتی موفق نبود؛ دوباره تلاش کنید.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    final previous = _backgroundedAt;
    _backgroundedAt = null;
    if (!mounted || _checking || _authenticating) return;
    try {
      final enabled = await DeviceAuthSettings.isEnabled();
      if (!mounted) return;
      final expired = previous != null &&
          DateTime.now().difference(previous) >= backgroundGrace;
      if (enabled != _enabled || (enabled && expired)) {
        setState(() {
          _enabled = enabled;
          _unlocked = !enabled || (_unlocked && !expired && !_enabled);
        });
      }
      if (_enabled && !_unlocked) {
        _unlock();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _unlocked = false;
        _error = 'خواندن وضعیت قفل با مشکل مواجه شد.';
      });
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !_enabled || _unlocked) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final allowed = await DeviceAuthSettings.authenticate();
      if (!mounted) return;
      setState(() {
        _unlocked = allowed;
        if (!allowed) {
          _error = 'احراز هویت انجام نشد؛ از رمز یا قفل دستگاه استفاده کنید.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unlocked = false;
        _error = 'قفل دستگاه در دسترس نیست؛ تنظیمات امنیتی گوشی را بررسی کنید.';
      });
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (!_enabled || _unlocked) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined,
                  color: champagne, size: 64),
              const SizedBox(height: 22),
              const Text('پیمانکاری صبا VIP',
                style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w800, color: ivory)),
              const SizedBox(height: 12),
              const Text('اطلاعات مالی قفل است. برای ادامه از اثرانگشت، '
                'تشخیص چهره یا رمز قفل دستگاه استفاده کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.7)),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFB1A4))),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _authenticating ? null : _unlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(_authenticating
                    ? 'در حال تأیید هویت...' : 'باز کردن برنامه'),
              ),
            ],
          ),
        )),
      ),
    );
  }
}
