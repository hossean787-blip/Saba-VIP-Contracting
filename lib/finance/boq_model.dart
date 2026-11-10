import '../core/format.dart';

/// Fixed-point: quantities 0.001 units, coefficients 1/10000 units, money rial.
const int _maxRial = 9223372036854775807;
const int _maxQuantityMilli = 1000000000000;

int? parseQuantityMilli(String input, {bool allowNegative = false}) {
  final text = normalizeDigits(input)
      .trim()
      .replaceAll(RegExp(r'[٬،,\s]'), '')
      .replaceAll('٫', '.');
  final pattern = allowNegative
      ? RegExp(r'^-?\d+(\.\d{1,3})?$')
      : RegExp(r'^\d+(\.\d{1,3})?$');
  if (!pattern.hasMatch(text)) return null;
  final negative = text.startsWith('-');
  final number = negative ? text.substring(1) : text;
  final parts = number.split('.');
  final major = int.tryParse(parts[0]);
  if (major == null || major > _maxQuantityMilli ~/ 1000) return null;
  final frac = parts.length == 1
      ? 0
      : int.parse(parts[1].padRight(3, '0'));
  final milli = major * 1000 + frac;
  if (milli <= 0 || milli > _maxQuantityMilli) return null;
  return negative ? -milli : milli;
}

int? parseCoefficientBp(String input) {
  final text = normalizeDigits(input).trim().replaceAll('٫', '.');
  if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final major = int.tryParse(parts[0]);
  if (major == null || major > 10) return null;
  final fraction = parts.length == 1
      ? 0
      : int.parse(parts[1].padRight(4, '0'));
  final bp = major * 10000 + fraction;
  return bp >= 1 && bp <= 100000 ? bp : null;
}

String formatScaled(int value, {int scale = 1000, int decimals = 3}) {
  final negative = value < 0;
  final digits = value.abs();
  final major = digits ~/ scale;
  final rest = digits % scale;
  final fraction = rest.toString().padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return (negative ? '-' : '') +
      major.toString() +
      (fraction.isEmpty ? '' : '.' + fraction);
}

int estimateRial({
  required int quantityMilli,
  required int unitPriceRial,
  required int coefficientBp,
}) {
  if (quantityMilli == 0 ||
      quantityMilli.abs() > _maxQuantityMilli ||
      unitPriceRial <= 0 ||
      unitPriceRial > _maxRial ||
      coefficientBp <= 0 ||
      coefficientBp > 100000) {
    throw ArgumentError('مقدار، قیمت یا ضریب نامعتبر است.');
  }
  final numerator = BigInt.from(quantityMilli).abs() *
      BigInt.from(unitPriceRial) *
      BigInt.from(coefficientBp);
  const divisor = 10000000;
  final result = (numerator + BigInt.from(divisor ~/ 2)) ~/
      BigInt.from(divisor);
  if (result > BigInt.from(_maxRial)) {
    throw ArgumentError('مبلغ از حد مجاز پایگاه داده بیشتر است.');
  }
  return quantityMilli < 0 ? -result.toInt() : result.toInt();
}

int checkedTotal(Iterable<int> values) {
  var total = BigInt.zero;
  for (final value in values) {
    total += BigInt.from(value);
  }
  if (total > BigInt.from(_maxRial) ||
      total < -BigInt.from(_maxRial)) {
    throw ArgumentError('جمع مبلغ از ظرفیت پایگاه داده بیشتر است.');
  }
  return total.toInt();
}

class BoqItem {
  const BoqItem({
    required this.id,
    required this.code,
    required this.title,
    required this.unit,
    required this.source,
    required this.plannedQuantityMilli,
    required this.unitPriceRial,
    required this.coefficientBp,
    required this.measuredQuantityMilli,
    required this.billedQuantityMilli,
    required this.pendingQuantityMilli,
  });
  final int id;
  final String code;
  final String title;
  final String unit;
  /// User-supplied price-list reference, not a verified official catalog.
  final String source;
  final int plannedQuantityMilli;
  final int unitPriceRial;
  final int coefficientBp;
  final int measuredQuantityMilli;
  final int billedQuantityMilli;
  final int pendingQuantityMilli;

  int get plannedValueRial => plannedQuantityMilli == 0 ? 0 : estimateRial(
      quantityMilli: plannedQuantityMilli,
      unitPriceRial: unitPriceRial,
      coefficientBp: coefficientBp);
  int get pendingValueRial => pendingQuantityMilli == 0 ? 0 : estimateRial(
      quantityMilli: pendingQuantityMilli,
      unitPriceRial: unitPriceRial,
      coefficientBp: coefficientBp);
  int get measuredValueRial => measuredQuantityMilli == 0 ? 0 : estimateRial(
      quantityMilli: measuredQuantityMilli,
      unitPriceRial: unitPriceRial,
      coefficientBp: coefficientBp);
}

class BoqMeasurement {
  const BoqMeasurement({
    required this.id,
    required this.itemId,
    required this.itemCode,
    required this.quantityMilli,
    required this.date,
    required this.documentRef,
    required this.memo,
    required this.statementId,
  });
  final int id;
  final int itemId;
  final String itemCode;
  final int quantityMilli;
  final String date;
  final String documentRef;
  final String memo;
  final int? statementId;
}

class BoqSnapshot {
  const BoqSnapshot({required this.items, required this.measurements});
  final List<BoqItem> items;
  final List<BoqMeasurement> measurements;
  int get plannedRial => checkedTotal(items.map((e) => e.plannedValueRial));
  int get measuredRial => checkedTotal(items.map((e) => e.measuredValueRial));
  int get pendingRial => checkedTotal(items.map((e) => e.pendingValueRial));
  int get unbilledCount =>
      measurements.where((e) => e.statementId == null).length;
}
