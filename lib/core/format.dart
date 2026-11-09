import 'package:shamsi_date/shamsi_date.dart';

/// Every monetary value in the database is an integer in RIAL.
/// Manual amount entry is whole TOMAN; labels retain any residual RIAL.
String normalizeDigits(String input) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return input.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (m) {
    final c = m[0]!;
    final p = persian.indexOf(c);
    return (p >= 0 ? p : arabic.indexOf(c)).toString();
  });
}

int? tomanToRial(String text, {bool allowZero = true}) {
  final normalized = normalizeDigits(text).replaceAll(RegExp(r'[,٬،\s]'), '');
  if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
  final toman = int.tryParse(normalized);
  if (toman == null || toman < 0 || (!allowZero && toman == 0)) return null;
  // Guard signed SQLite 64-bit integer overflow.
  if (toman > 922337203685477580) return null;
  return toman * 10;
}

String grouped(int n) {
  final negative = n < 0;
  final s = n.abs().toString();
  final output =
      s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '٬');
  return '${negative ? '−' : ''}$output';
}

String tomanLabel(int rial) =>
    rial % 10 == 0 ? '${grouped(rial ~/ 10)} تومان' : '${grouped(rial)} ریال';

String isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String jalaliLabel(String? iso) {
  if (iso == null || iso.isEmpty) return 'ثبت نشده';
  try {
    final j = Jalali.fromDateTime(DateTime.parse(iso));
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return 'تاریخ نامعتبر';
  }
}
