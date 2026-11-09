import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../finance/expense_payment.dart';

/// Settlement only counts allocations for this specific expense.
class ExpensePaymentStatus extends StatelessWidget {
  const ExpensePaymentStatus({super.key, required this.expenseRial,
    required this.paidRial, this.onPay});
  final int expenseRial, paidRial;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final remaining = remainingExpenseRial(expenseRial, paidRial);
    final settled = remaining == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(settled ? 'تسویه کامل' : paidRial == 0 ? 'پرداخت‌نشده' : 'پرداخت جزئی',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: settled ? mint : champagne)),
      const SizedBox(height: 5),
      Text('پرداخت‌شده: ${tomanLabel(paidRial)} • مانده: ${tomanLabel(remaining)}',
        style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: paidRial / expenseRial, minHeight: 4,
        color: settled ? mint : champagne,
        backgroundColor: muted.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(5)),
      if (onPay != null && remaining > 0) ...[
        const SizedBox(height: 5),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: onPay, icon: const Icon(Icons.add_card_outlined, size: 17),
          label: const Text('ثبت پرداخت مانده'))),
      ],
    ]);
  }
}
