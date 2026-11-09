import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../core/format.dart';

class JalaliDateField extends StatelessWidget {
  const JalaliDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.optional = false});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () async {
          final initial = value == null
              ? Jalali.now()
              : Jalali.fromDateTime(DateTime.parse(value!));
          final j = await showPersianDatePicker(
            context: context,
            initialDate: initial,
            firstDate: Jalali(1380, 1, 1),
            lastDate: Jalali(1490, 12, 29),
          );
          if (j != null) onChanged(isoDay(j.toDateTime()));
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text('$label: ${jalaliLabel(value)}'),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12)),
      );
}
