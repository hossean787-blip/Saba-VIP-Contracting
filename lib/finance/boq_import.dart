import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import '../core/format.dart';
import 'boq_model.dart';

/// A strict, contract-neutral preview. No database is modified while parsing.
class BoqImportRow {
  const BoqImportRow({
    required this.code,
    required this.title,
    required this.unit,
    required this.source,
    required this.quantityMilli,
    required this.unitPriceRial,
    required this.coefficientBp,
  });
  final String code;
  final String title;
  final String unit;
  final String source;
  final int quantityMilli;
  final int unitPriceRial;
  final int coefficientBp;

  int get plannedRial => estimateRial(
    quantityMilli: quantityMilli,
    unitPriceRial: unitPriceRial,
    coefficientBp: coefficientBp,
  );
}

class BoqImportBatch {
  const BoqImportBatch(this.rows, this.plannedRial);
  final List<BoqImportRow> rows;
  final int plannedRial;
}

class BoqExcelImport {
  BoqExcelImport._();

  static const maxRows = 500;
  static const maxBytes = 5 * 1024 * 1024;
  static const headers = <String>[
    'کد ردیف', 'شرح عملیات', 'واحد', 'منبع نرخ',
    'مقدار', 'قیمت واحد (ریال)', 'ضریب نهایی',
  ];

  static Uint8List blankTemplate() {
    final book = xl.Excel.createExcel();
    final sheet = book['فهرست‌بها'];
    sheet.appendRow(headers.map((label) => xl.TextCellValue(label)).toList());
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 1 || i == 3 ? 46 : 23);
    }
    book.delete('Sheet1');
    final bytes = book.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('فایل الگوی اکسل ساخته نشد.');
    }
    return Uint8List.fromList(bytes);
  }

  static String _span(xl.TextSpan value) {
    return (value.text ?? '') +
        (value.children ?? const <xl.TextSpan>[])
            .map(_span).join();
  }

  static String _cell(xl.Data? value) {
    final item = value?.value;
    if (item == null) return '';
    if (item is xl.TextCellValue) return _span(item.value).trim();
    if (item is xl.IntCellValue) return item.value.toString();
    if (item is xl.DoubleCellValue) return item.value.toString();
    throw const FormatException(
      'سلول دارای فرمول یا نوع غیرمجاز است؛ مقدار ثابت وارد کنید.');
  }

  static int? _price(String raw) {
    final clean = normalizeDigits(raw)
        .replaceAll(RegExp(r'[٬،,\s]'), '');
    final value = int.tryParse(clean);
    if (value == null || value <= 0 || value > 9223372036854775807) {
      return null;
    }
    return value;
  }

  static BoqImportBatch parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('حجم فایل باید کمتر از ۵ مگابایت باشد.');
    }
    late final xl.Excel book;
    try {
      book = xl.Excel.decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('فایل XLSX معتبر نیست یا آسیب دیده است.');
    }
    if (book.tables.isEmpty) {
      throw const FormatException('فایل اکسل هیچ برگه‌ای ندارد.');
    }
    final sheet = book.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw const FormatException('برگه اکسل خالی است.');
    }
    final actualHeaders = sheet.rows.first;
    if (actualHeaders.length < headers.length ||
        List.generate(headers.length,
            (i) => _cell(actualHeaders[i]) == headers[i])
            .contains(false)) {
      throw const FormatException(
        'سربرگ‌ها مطابقت ندارند؛ از فایل الگوی برنامه استفاده کنید.');
    }
    final rows = <BoqImportRow>[];
    final codes = <String>{};
    final amounts = <int>[];
    for (var index = 1; index < sheet.rows.length; index++) {
      final cells = sheet.rows[index];
      if (cells.every((cell) => cell?.value == null)) continue;
      final line = index + 1;
      if (rows.length >= maxRows) {
        throw const FormatException('حداکثر ۵۰۰ ردیف در هر فایل مجاز است.');
      }
      late final List<String> fields;
      try {
        fields = List.generate(headers.length,
            (i) => _cell(i < cells.length ? cells[i] : null));
      } on FormatException catch (error) {
        throw FormatException('سطر ' + line.toString() + ': ' + error.message);
      }
      final code = fields[0].trim();
      final title = fields[1].trim();
      final unit = fields[2].trim();
      final source = fields[3].trim();
      final qty = parseQuantityMilli(fields[4]);
      final price = _price(fields[5]);
      final coefficient = parseCoefficientBp(fields[6]);
      if (code.isEmpty || code.length > 40 ||
          title.isEmpty || title.length > 250 ||
          unit.isEmpty || unit.length > 30 ||
          source.isEmpty || source.length > 250 ||
          qty == null || price == null || coefficient == null) {
        throw FormatException(
            'سطر ' + line.toString() + ': اطلاعات ردیف، '
            'مقدار، نرخ ریالی یا ضریب معتبر نیست.');
      }
      if (!codes.add(code.toLowerCase())) {
        throw FormatException(
            'سطر ' + line.toString() + ': کد تکراری ' + code);
      }
      final row = BoqImportRow(
        code: code, title: title, unit: unit, source: source,
        quantityMilli: qty, unitPriceRial: price,
        coefficientBp: coefficient,
      );
      try {
        amounts.add(row.plannedRial);
      } on ArgumentError {
        throw FormatException(
            'سطر ' + line.toString() + ': مبلغ از حد مجاز فراتر است.');
      }
      rows.add(row);
    }
    if (rows.isEmpty) {
      throw const FormatException('هیچ ردیف داده‌ای در فایل وجود ندارد.');
    }
    try {
      return BoqImportBatch(
          List.unmodifiable(rows), checkedTotal(amounts));
    } on ArgumentError {
      throw const FormatException('جمع برآورد از حد مجاز بیشتر است.');
    }
  }
}
