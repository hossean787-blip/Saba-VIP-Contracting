import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../security/backup_codec.dart';
import '../security/device_auth_settings.dart';
import '../widgets/ui.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.store});
  final OfflineStore store;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final exportPassword = TextEditingController();
  final exportConfirm = TextEditingController();
  final restorePassword = TextEditingController();
  bool busy = false;
  bool showPasswords = false;
  bool deviceLock = false;
  bool rollbackAvailable = false;
  bool securityBusy = false;
  static const _codec = BackupCodec();

  @override
  void initState() {
    super.initState();
    _loadSecurity();
  }

  Future<void> _loadSecurity() async {
    try {
      final lock = await DeviceAuthSettings.isEnabled();
      final backup = await widget.store.hasEmergencyRollback();
      if (mounted) setState(() { deviceLock = lock; rollbackAvailable = backup; });
    } catch (_) {
      if (mounted) showFeedback(context,
          'بررسی تنظیمات امنیتی ممکن نشد.', error: true);
    }
  }

  Future<void> _changeDeviceLock(bool enabled) async {
    if (securityBusy || busy) return;
    setState(() => securityBusy = true);
    try {
      final verified = await DeviceAuthSettings.authenticate();
      if (!verified) {
        throw StateError('احراز هویت دستگاه لغو شد یا در دسترس نیست.');
      }
      await DeviceAuthSettings.setEnabled(enabled);
      if (mounted) {
        setState(() => deviceLock = enabled);
        showFeedback(context, enabled
          ? 'قفل ورود فعال شد.' : 'قفل ورود غیرفعال شد.');
      }
    } catch (error) {
      if (mounted) showFeedback(context,
          'تغییر قفل انجام نشد: ' + error.toString(), error: true);
    } finally {
      if (mounted) setState(() => securityBusy = false);
    }
  }

  Future<void> _clearRollback() async {
    if (!rollbackAvailable || busy || securityBusy) return;
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف نسخه بازگشت اضطراری؟'),
        content: const Text('این عملیات تنها نسخه قبلی حفظ‌شده پیش از آخرین '
          'بازیابی را حذف می‌کند؛ داده‌های فعلی تغییر نمی‌کنند. '
          'این نسخه دیگر قابل بازگرداندن نخواهد بود. '
          'پیش از ادامه، از داده‌های فعلی پشتیبان رمزگذاری‌شده '
          'در محل امن نگهداری کنید.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نسخه قدیمی')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.clearEmergencyRollback();
      if (mounted) {
        setState(() => rollbackAvailable = false);
        showFeedback(context, 'نسخه قدیمی حذف شد؛ اطلاعات فعلی محفوظ است.');
      }
    } catch (error) {
      if (mounted) showFeedback(context,
        'حذف نسخه قدیمی انجام نشد: ' + error.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    exportPassword.dispose();
    exportConfirm.dispose();
    restorePassword.dispose();
    super.dispose();
  }

  Future<void> _backup() async {
    if (exportPassword.text.length < 12) {
      showFeedback(context, 'رمز باید حداقل ۱۲ نویسه داشته باشد.', error: true);
      return;
    }
    if (exportPassword.text != exportConfirm.text) {
      showFeedback(context, 'تکرار رمز با رمز اصلی یکسان نیست.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final sqlite = await widget.store.snapshotDatabase();
      final encrypted = await _codec.encrypt(sqlite, exportPassword.text);
      final temp = await getTemporaryDirectory();
      final name =
          'SabaVIP_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.svb';
      final output = File(p.join(temp.path, name));
      await output.writeAsBytes(encrypted, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
          [XFile(output.path, mimeType: 'application/octet-stream')],
          text:
              'نسخه پشتیبان رمزگذاری‌شده پیمانکاری صبا VIP؛ رمز را به‌صورت جداگانه نگهداری کنید.');
      if (mounted) {
        showFeedback(context,
            'فایل رمزگذاری‌شده آماده اشتراک است؛ مطمئن شوید آن را خارج از برنامه ذخیره کرده‌اید.');
      }
    } catch (error) {
      if (mounted)
        showFeedback(context, 'ساخت نسخه پشتیبان انجام نشد: $error',
            error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyBackup() async {
    if (restorePassword.text.length < 12 || busy) {
      showFeedback(context, 'رمز فایل پشتیبان را وارد کنید.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      const group = XTypeGroup(label: 'پشتیبان رمزگذاری‌شده صبا',
          extensions: ['svb'], mimeTypes: ['application/octet-stream']);
      final selected = await openFile(acceptedTypeGroups: [group]);
      if (selected == null) return;
      if (await selected.length() > BackupCodec.maxArchiveBytes) {
        throw const FormatException('حجم پشتیبان بیش از حد مجاز است.');
      }
      final encrypted = await selected.readAsBytes();
      final clear = await _codec.decrypt(encrypted, restorePassword.text);
      await widget.store.verifyBackupDatabase(clear);
      if (mounted) {
        showFeedback(context,
            'فایل رمزگشایی شد؛ سلامت SQLite، ساختار و روابط پایگاه داده تأیید شد. '
            'هیچ داده فعلی تغییر نکرد.');
      }
    } catch (error) {
      if (mounted) showFeedback(context,
          'تأیید سلامت پشتیبان ناموفق بود: ' + error.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    if (restorePassword.text.length < 12) {
      showFeedback(context, 'رمز فایل پشتیبان را وارد کنید.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      const typeGroup = XTypeGroup(
          label: 'پشتیبان رمزگذاری‌شده صبا',
          extensions: ['svb'],
          mimeTypes: ['application/octet-stream']);
      final selected = await openFile(acceptedTypeGroups: [typeGroup]);
      if (selected == null) return;
      // Bound file IO before allocating an arbitrary-sized backup in memory.
      // The same limit is enforced by the non-destructive verification path.
      if (await selected.length() > BackupCodec.maxArchiveBytes) {
        throw const FormatException('حجم پشتیبان بیش از حد مجاز است.');
      }
      final bytes = await selected.readAsBytes();
      final clearSqlite = await _codec.decrypt(bytes, restorePassword.text);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('تأیید بازیابی اطلاعات'),
                content: const Text(
                    'بازیابی، اطلاعات فعلی روی گوشی را با اطلاعات فایل پشتیبان جایگزین می‌کند.\n\nفقط اگر از داده‌های فعلی نسخه پشتیبان دیگری داری ادامه بده. نسخه فعلی برای بازگشت اضطراری در حافظه برنامه نگه داشته می‌شود.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('بازیابی اطلاعات')),
                ],
              ));
      if (confirmed != true) return;
      await widget.store.restoreDatabase(clearSqlite);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        showFeedback(context, 'بازیابی انجام نشد و اطلاعات فعلی حفظ شد: $error',
            error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('امنیت و پشتیبان‌گیری')),
        body: Stack(children: [
          ListView(padding: const EdgeInsets.all(20), children: [
            const VipCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.shield_rounded, color: champagne, size: 35),
                  SizedBox(height: 12),
                  Text('اطلاعات شرکت را ایمن نگه دار',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                      'فایل پشتیبان با AES-256-GCM رمزگذاری می‌شود. رمز روی دستگاه یا سرور ذخیره نمی‌شود و برای بازیابی ضروری است.',
                      style: TextStyle(color: muted)),
                ])),
            const SizedBox(height: 18),
            const SectionHeading('قفل ورود دستگاه'),
            const SizedBox(height: 8),
            VipCard(child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: deviceLock,
              onChanged: busy || securityBusy
                ? null : (value) => _changeDeviceLock(value),
              title: const Text('درخواست اثرانگشت یا رمز قفل گوشی'),
              subtitle: const Text(
                'اختیاری؛ برای فعال یا غیرفعال کردن احراز هویت لازم است. '
                'این قفل، پایگاه داده داخلی را رمزگذاری نمی‌کند. '
                'اگر قفل گوشی را حذف کنید ممکن است دسترسی به برنامه '
                'تا تنظیم دوباره قفل دستگاه ممکن نباشد.',
                style: TextStyle(color: muted, fontSize: 12)),
            )),
            const SizedBox(height: 20),
            const SectionHeading('ساخت نسخه پشتیبان'),
            const SizedBox(height: 10),
            TextField(
                controller: exportPassword,
                obscureText: !showPasswords,
                decoration: const InputDecoration(
                    labelText: 'رمز پشتیبان (حداقل ۱۲ نویسه)')),
            const SizedBox(height: 12),
            TextField(
                controller: exportConfirm,
                obscureText: !showPasswords,
                decoration:
                    const InputDecoration(labelText: 'تکرار رمز پشتیبان')),
            CheckboxListTile(
                value: showPasswords,
                onChanged: busy
                    ? null
                    : (v) => setState(() => showPasswords = v ?? false),
                title: const Text('نمایش رمزها'),
                controlAffinity: ListTileControlAffinity.leading),
            FilledButton.icon(
                onPressed: busy ? null : _backup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('ایجاد و ذخیره فایل پشتیبان')),
            const SizedBox(height: 24),
            const SectionHeading('بازیابی روی گوشی'),
            const SizedBox(height: 10),
            TextField(
                controller: restorePassword,
                obscureText: !showPasswords,
                decoration:
                    const InputDecoration(labelText: 'رمز فایل پشتیبان')),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: busy ? null : _restore,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('انتخاب فایل و بازیابی اطلاعات')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: busy ? null : _verifyBackup,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('بررسی سلامت پشتیبان بدون بازیابی')),
            const SizedBox(height: 15),
            if (rollbackAvailable) ...[
              const SectionHeading('نسخه بازگشت اضطراری موجود است'),
              const SizedBox(height: 8),
              const Text('پیش از آخرین بازیابی، یک نسخه محلی از داده‌ها '
                'نگهداری شده است. تا زمانی که حذف نشود، بازیابی جدید '
                'برای محافظت از این نسخه متوقف می‌شود.',
                style: TextStyle(color: muted, height: 1.6)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : _clearRollback,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('حذف با تأیید نسخه بازگشت اضطراری')),
              const SizedBox(height: 20),
            ],
            const Text(
                'مهم: فایل پشتیبان را به حافظه‌ای خارج از برنامه منتقل کن. حذف برنامه معمولاً داده‌های داخلی را نیز حذف می‌کند. فراموش‌کردن رمز، بازیابی فایل رمزگذاری‌شده را غیرممکن می‌کند.',
                style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 36),
          ]),
          if (busy)
            const ColoredBox(
                color: Color(0xBB101A24),
                child: Center(child: CircularProgressIndicator())),
        ]),
      );
}
