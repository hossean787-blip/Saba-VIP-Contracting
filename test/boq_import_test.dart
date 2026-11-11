import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/boq_import.dart';

List<int> workbook(List<List<xl.CellValue>> lines) {
  final book = xl.Excel.createExcel();
  final sheet = book['Sheet1'];
  sheet.appendRow(
    BoqExcelImport.headers.map((v) => xl.TextCellValue(v)).toList());
  for (final line in lines) {
    sheet.appendRow(line);
  }
  return book.encode()!;
}

List<xl.CellValue> item({
  String code = '001',
  String quantity = '1.500',
  String price = '100000',
  String coefficient = '1.1000',
}) => [
  xl.TextCellValue(code),
  xl.TextCellValue('بتن مگر'),
  xl.TextCellValue('مترمکعب'),
  xl.TextCellValue('فهرست‌بهای قرارداد ۱۴۰۴'),
  xl.TextCellValue(quantity),
  xl.TextCellValue(price),
  xl.TextCellValue(coefficient),
];

void main() {
  test('template roundtrip keeps exact header and is empty', () {
    final template = BoqExcelImport.blankTemplate();
    expect(template, isNotEmpty);
    expect(() => BoqExcelImport.parse(template), throwsFormatException);
  });

  test('one row and totals use exact fixed-point rial', () {
    final data = workbook([item()]);
    final batch = BoqExcelImport.parse(
      // List<int> to Uint8List
      Uint8List.fromList(data));
    expect(batch.rows.single.code, '001');
    expect(batch.rows.single.quantityMilli, 1500);
    expect(batch.rows.single.coefficientBp, 11000);
    expect(batch.plannedRial, 165000);
  });

  test('duplicate code inside a file fails before persistence', () {
    expect(() => BoqExcelImport.parse(Uint8List.fromList(workbook([
      item(code: '001'),
      item(code: '001'),
    ]))), throwsFormatException);
  });

  test('invalid negative amount, quantity, rate, coefficient fail', () {
    for (final bad in [
      item(quantity: '-1'),
      item(quantity: '0'),
      item(price: '0'),
      item(price: '-100'),
      item(coefficient: '12'),
      item(coefficient: '0'),
    ]) {
      expect(() => BoqExcelImport.parse(
        Uint8List.fromList(workbook([bad]))), throwsFormatException);
    }
  });

  test('mixed valid and invalid rows fail all-or-nothing', () {
    final data = Uint8List.fromList(workbook([
      item(code: '010'),
      item(code: '020', price: 'bad'),
    ]));
    expect(() => BoqExcelImport.parse(data), throwsFormatException);
  });

  test('bad header is rejected', () {
    final book = xl.Excel.createExcel();
    book['Sheet1'].appendRow([xl.TextCellValue('Wrong')]);
    expect(() => BoqExcelImport.parse(
      Uint8List.fromList(book.encode()!)), throwsFormatException);
  });
}
