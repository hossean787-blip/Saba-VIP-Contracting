import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/format.dart';
import 'report_model.dart';

/// Exports are created in memory; no network, backend or extra user permissions.
class ReportExports {
  ReportExports._();

  static String filename(ContractReport report, String kind, String extension) {
    final safeNo = report.contractNo.replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeKind = kind.replaceAll(RegExp(r'[^a-z]'), '');
    return 'saba_${safeNo}_${safeKind}_${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  static final metricNames = <String>[
    'ارزش قرارداد',
    'هزینه ثبت‌شده',
    'پرداخت نقدی',
    'دریافت نقدی',
    'کار تأییدشده (ناخالص)',
    'خالص صورت‌وضعیت تأییدشده',
    'مازاد اولیه غیرقطعی',
    'جریان نقدی',
  ];

  static List<int> metrics(ContractReport r) => [
        r.contractAmountRial,
        r.costRial,
        r.paymentRial,
        r.receiptRial,
        r.approvedGrossRial,
        r.approvedNetRial,
        r.provisionalMarginRial,
        r.cashFlowRial
      ];

  static Uint8List xlsx(ContractReport r, {String kind = 'all'}) {
    final excel = xl.Excel.createExcel();
    final summary = excel['خلاصه'];
    summary.appendRow(
        [xl.TextCellValue('گزارش قرارداد'), xl.TextCellValue(r.contractNo)]);
    summary
        .appendRow([xl.TextCellValue('شرکت'), xl.TextCellValue(r.companyName)]);
    summary.appendRow(
        [xl.TextCellValue('عنوان قرارداد'), xl.TextCellValue(r.contractTitle)]);
    summary
        .appendRow([xl.TextCellValue('کارفرما'), xl.TextCellValue(r.employer)]);
    summary.appendRow(
        [xl.TextCellValue('پیمانکار'), xl.TextCellValue(r.contractor)]);
    summary.appendRow([
      xl.TextCellValue('شاخص مالی'),
      xl.TextCellValue('مبلغ (تومان، بخش صحیح)'),
      xl.TextCellValue('مبلغ دقیق (ریال، متنی)'),
      xl.TextCellValue('مبلغ قابل جمع (ریال، عددی)')
    ]);
    for (var i = 0; i < metricNames.length; i++) {
      summary.appendRow([
        xl.TextCellValue(metricNames[i]),
        xl.IntCellValue(metrics(r)[i] ~/ 10),
        xl.TextCellValue(metrics(r)[i].toString()),
        xl.IntCellValue(metrics(r)[i])
      ]);
    }
    summary.appendRow([
      xl.TextCellValue('توضیح'),
      xl.TextCellValue(
          'مازاد اولیه، سود قطعی حسابداری نیست؛ دریافت و درآمد جدا هستند.')
    ]);
    summary.setColumnWidth(0, 42);
    summary.setColumnWidth(1, 42);
    summary.setColumnWidth(2, 28);
    summary.setColumnWidth(3, 28);
    for (final row in [0, 5]) {
      for (var col = 0; col < (row == 5 ? 4 : 2); col++) {
        summary
                .cell(xl.CellIndex.indexByColumnRow(
                    columnIndex: col, rowIndex: row))
                .cellStyle =
            xl.CellStyle(
                backgroundColorHex: xl.ExcelColor.fromHexString('#17212D'),
                fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
                bold: true,
                horizontalAlign: xl.HorizontalAlign.Right);
      }
    }
    final sheet = excel['ریز عملیات'];
    sheet.appendRow([
      xl.TextCellValue('نوع'),
      xl.TextCellValue('تاریخ شمسی'),
      xl.TextCellValue('عنوان / دسته'),
      xl.TextCellValue('مبلغ (تومان، بخش صحیح)'),
      xl.TextCellValue('وضعیت'),
      xl.TextCellValue('توضیحات'),
      xl.TextCellValue('مبلغ دقیق (ریال، متنی)'),
      xl.TextCellValue('مبلغ قابل جمع (ریال، عددی)'),
    ]);
    final rows = r.filtered(kind);
    for (final item in rows) {
      sheet.appendRow([
        xl.TextCellValue(item.kindLabel),
        xl.TextCellValue(jalaliLabel(item.dateIso)),
        xl.TextCellValue(item.title),
        xl.IntCellValue(item.amountRial ~/ 10),
        xl.TextCellValue(item.status),
        xl.TextCellValue(item.note),
        xl.TextCellValue(item.amountRial.toString()),
        xl.IntCellValue(item.amountRial),
      ]);
    }
    for (var col = 0; col < 8; col++) {
      sheet.setColumnWidth(col, col == 5 ? 48 : (col == 2 ? 38 : 21));
      sheet
              .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
              .cellStyle =
          xl.CellStyle(
              backgroundColorHex: xl.ExcelColor.fromHexString('#17212D'),
              fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
              bold: true,
              horizontalAlign: xl.HorizontalAlign.Right);
    }
    excel.delete('Sheet1');
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty)
      throw StateError('تولید فایل اکسل موفق نبود');
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> pdf(ContractReport r, {String kind = 'all'}) async {
    // Font is provisioned at build time by tool/prepare_fonts.sh and embedded
    // inside the APK for fully offline Persian text rendering.
    final data = await rootBundle.load('assets/fonts/NotoNaskhArabic.ttf');
    final font = pw.Font.ttf(data);
    final document = pw.Document(
        title: 'گزارش قرارداد ${r.contractNo}', author: r.companyName);
    final gold = PdfColor.fromInt(0xFFD5B77D);
    final dark = PdfColor.fromInt(0xFF17212D);
    final body = pw.TextStyle(font: font, fontSize: 10);
    final headings = pw.TextStyle(font: font, fontSize: 11, color: dark);
    final items = r.filtered(kind);
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      margin: const pw.EdgeInsets.all(32),
      maxPages: 200,
      header: (context) => pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: gold, width: 2))),
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(r.companyName, style: body),
              pw.Text('پیمانکاری صبا VIP', style: headings),
            ]),
      ),
      footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text('صفحه ${context.pageNumber} از ${context.pagesCount}',
              style: body)),
      build: (context) => [
        pw.SizedBox(height: 14),
        pw.Text('گزارش مالی قرارداد ${r.contractNo}',
            style: pw.TextStyle(font: font, fontSize: 17, color: dark)),
        pw.SizedBox(height: 6),
        pw.Text(r.contractTitle, style: headings),
        pw.SizedBox(height: 8),
        pw.Text('کارفرما: ${r.employer}     |     پیمانکار: ${r.contractor}',
            style: body),
        pw.SizedBox(height: 14),
        pw.Table.fromTextArray(
          headers: ['شاخص', 'مبلغ'],
          data: [
            for (var i = 0; i < metricNames.length; i++)
              [metricNames[i], tomanLabel(metrics(r)[i])]
          ],
          headerStyle:
              pw.TextStyle(font: font, color: PdfColors.white, fontSize: 10),
          headerDecoration: pw.BoxDecoration(color: dark),
          cellStyle: body,
          cellAlignment: pw.Alignment.centerRight,
          cellPadding: const pw.EdgeInsets.all(6),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
            'یادداشت: مازاد اولیه، سود قطعی نیست. مبالغ دریافتی و پرداختی با درآمد و هزینه تفاوت دارند.',
            style: body),
        pw.SizedBox(height: 20),
        pw.Text('ریز اطلاعات ثبت‌شده (${items.length} مورد)', style: headings),
        pw.SizedBox(height: 10),
        if (items.isEmpty)
          pw.Text('رکوردی برای این فیلتر وجود ندارد.', style: body)
        else
          pw.Table.fromTextArray(
            headers: ['نوع', 'تاریخ', 'شرح', 'مبلغ'],
            data: [
              for (final item in items)
                [
                  item.kindLabel,
                  jalaliLabel(item.dateIso),
                  item.note.trim().isEmpty
                      ? item.title
                      : '${item.title} — ${item.note}',
                  tomanLabel(item.amountRial)
                ]
            ],
            headerStyle:
                pw.TextStyle(font: font, color: PdfColors.white, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: dark),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(5),
            cellAlignment: pw.Alignment.centerRight,
          ),
      ],
    ));
    return document.save();
  }
}
