import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../data/boq_bulk_store.dart';
import '../data/offline_store.dart';
import '../finance/boq_import.dart';
import '../widgets/ui.dart';

/// Offline XLSX import with a preview and explicit confirmation.
class BoqImportScreen extends StatefulWidget {
  const BoqImportScreen({
    super.key, required this.store,
    required this.companyId, required this.contractId,
  });
  final OfflineStore store;
  final int companyId;
  final int contractId;

  @override
  State<BoqImportScreen> createState() => _BoqImportScreenState();
}

class _BoqImportScreenState extends State<BoqImportScreen> {
  BoqImportBatch? preview;
  String? fileName;
  bool busy = false;

  Future<void> _template() async {
    setState(() => busy = true);
    try {
      final folder = await getTemporaryDirectory();
      final output = File(p.join(folder.path,
        'SabaVIP_BOQ_template.xlsx'));
      await output.writeAsBytes(BoqExcelImport.blankTemplate(), flush: true);
      await Share.shareXFiles([
        XFile(output.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ], text: 'الگوی فهرست‌بهای قراردادی؛ نرخ‌ها برحسب ریال هستند.');
    } catch (error) {
      if (mounted) {
        showFeedback(context, 'صدور الگو ناموفق بود: ' + error.toString(),
          error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _selectFile() async {
    setState(() => busy = true);
    try {
      const type = XTypeGroup(label: 'فایل اکسل XLSX',
        extensions: ['xlsx'],
        mimeTypes: [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ]);
      final file = await openFile(acceptedTypeGroups: [type]);
      if (file == null) return;
      if (await file.length() > BoqExcelImport.maxBytes) {
        throw const FormatException('حجم فایل بیش از ۵ مگابایت است.');
      }
      final result = BoqExcelImport.parse(await file.readAsBytes());
      if (mounted) {
        setState(() {
          preview = result;
          fileName = file.name;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() { preview = null; fileName = null; });
        showFeedback(context, 'اعتبارسنجی اکسل: ' + error.toString(),
          error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    final batch = preview;
    if (batch == null || busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ثبت قطعی ردیف‌های فهرست‌بها'),
        content: Text('تعداد ' + batch.rows.length.toString() +
          ' ردیف در قرارداد جاری ثبت می‌شود.\n'
          'ردیف‌های تکراری یا ناسازگار باعث لغو کل ورود خواهند شد. '
          'اطلاعات قبلی حذف یا جایگزین نمی‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ثبت همه ردیف‌ها')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final count = await widget.store.importBoqRows(
        companyId: widget.companyId,
        contractId: widget.contractId, batch: batch);
      if (!mounted) return;
      showFeedback(context, count.toString() + ' ردیف وارد شد.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showFeedback(context,
          'هیچ ردیفی ثبت نشد؛ علت: ' + error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = preview;
    return Scaffold(
      appBar: AppBar(title: const Text('ورود فهرست‌بها از اکسل')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const VipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ورود امن و آفلاین ردیف‌ها',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text('ابتدا الگوی خالی XLSX را دریافت کنید. '
                  'هفت ستون شامل کد، شرح، واحد، منبع نرخ، مقدار، '
                  'قیمت واحد به ریال و ضریب نهایی است. '
                  'کد ردیف را به‌صورت «متن» ثبت کنید تا صفرهای ابتدای آن حفظ شود. '
                  'حداکثر ۵۰۰ ردیف و ۵ مگابایت.',
                  style: TextStyle(color: muted, height: 1.7)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : _template,
            icon: const Icon(Icons.download_outlined),
            label: const Text('دریافت الگوی اکسل'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy ? null : _selectFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('انتخاب و بررسی فایل XLSX'),
          ),
          if (busy) const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator())),
          if (batch != null) ...[
            const SizedBox(height: 22),
            const Text('پیش‌نمایش قبل از ثبت',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(fileName ?? '', style: const TextStyle(color: muted)),
            const SizedBox(height: 12),
            VipCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تعداد ردیف‌ها: ' + batch.rows.length.toString()),
                const SizedBox(height: 6),
                Text('جمع برآورد: ' + tomanLabel(batch.plannedRial),
                  style: const TextStyle(color: champagne,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('قیمت و ضرایب از فایل کاربر دریافت شده‌اند؛ '
                  'اعتبار قانونی فهرست‌بها و انطباق با اسناد پیمان '
                  'باید توسط مسئول قرارداد تأیید شود.',
                  style: TextStyle(color: muted, fontSize: 12)),
              ],
            )),
            const SizedBox(height: 10),
            for (final row in batch.rows.take(12))
              ListTile(
                title: Text(row.code + ' · ' + row.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('مقدار: ' +
                  formatScaled(row.quantityMilli) + ' ' + row.unit +
                  ' · ' + tomanLabel(row.plannedRial)),
              ),
            if (batch.rows.length > 12)
              Text('و ' + (batch.rows.length - 12).toString() +
                ' ردیف دیگر...', style: const TextStyle(color: muted)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _import,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('تأیید و ثبت همه ردیف‌ها'),
            ),
          ],
        ]),
      ),
    );
  }
}
