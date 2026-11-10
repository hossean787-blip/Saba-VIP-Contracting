import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/boq_store.dart';
import '../data/offline_store.dart';
import '../finance/boq_model.dart';
import '../widgets/date_field.dart';
import '../widgets/ui.dart';

/// A real offline BOQ / takeoff / statement-draft workflow scoped to one contract.
class BoqScreen extends StatefulWidget {
  const BoqScreen({
    super.key,
    required this.store,
    required this.companyId,
    required this.contractId,
  });
  final OfflineStore store;
  final int companyId;
  final int contractId;

  @override
  State<BoqScreen> createState() => _BoqScreenState();
}

class _BoqScreenState extends State<BoqScreen> {
  late Future<BoqSnapshot> future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    future = widget.store.boqSnapshot(
        companyId: widget.companyId, contractId: widget.contractId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await future;
  }

  Widget _amount(String label, int value, {Color tint = champagne}) =>
      VipCard(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 9),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(tomanLabel(value),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tint))),
              ]));

  Future<void> _editItem([BoqItem? item]) async {
    final code = TextEditingController(text: item?.code ?? '');
    final title = TextEditingController(text: item?.title ?? '');
    final unit = TextEditingController(text: item?.unit ?? '');
    final source = TextEditingController(text: item?.source ?? '');
    final quantity = TextEditingController(
        text: item == null
            ? ''
            : formatScaled(item.plannedQuantityMilli));
    final price = TextEditingController(
        text: item == null ? '' : (item.unitPriceRial ~/ 10).toString());
    final coefficient = TextEditingController(
        text: item == null
            ? '1'
            : formatScaled(item.coefficientBp,
                scale: 10000, decimals: 4));
    final form = GlobalKey<FormState>();
    bool saving = false;
    final done = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (sheetContext, setSheet) {
              return Padding(
                  padding: EdgeInsets.fromLTRB(
                      18, 18, 18,
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
                  child: SingleChildScrollView(
                      child: Form(
                    key: form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(item == null ? 'ردیف جدید فهرست‌بها' : 'اصلاح ردیف برآورد',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 19)),
                      const SizedBox(height: 11),
                      const Text(
                          'قیمت و ضرایب باید از اسناد پیمان انتخاب شوند؛ '
                          'برنامه نرخ رسمی سال جاری را به‌طور خودکار تعیین نمی‌کند.',
                          style: TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(height: 13),
                      TextFormField(
                          controller: code,
                          maxLength: 40,
                          decoration: const InputDecoration(
                              labelText: 'کد ردیف *'),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'کد ردیف لازم است' : null),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: title,
                          maxLength: 250,
                          decoration: const InputDecoration(
                              labelText: 'شرح عملیات *'),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'شرح ردیف لازم است' : null),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: unit,
                          maxLength: 30,
                          decoration: const InputDecoration(
                              labelText: 'واحد (متر، مترمربع، کیلوگرم...) *'),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'واحد لازم است' : null),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: source,
                          maxLength: 250,
                          decoration: const InputDecoration(
                            labelText: 'منبع قیمت، رشته و سال (اختیاری)',
                            hintText: 'مثلاً فهرست‌بهای ابنیه ۱۴۰۴',
                          )),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'مقدار برآوردی * (تا ۳ رقم اعشار)'),
                          validator: (v) =>
                              parseQuantityMilli(v ?? '') == null
                                  ? 'مقدار مثبت و معتبر وارد کنید' : null),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'بهای واحد (تومان) *'),
                          validator: (v) =>
                              tomanToRial(v ?? '', allowZero: false) == null
                                  ? 'بهای واحد معتبر نیست' : null),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: coefficient,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'ضریب نهایی توافق‌شده *',
                              helperText: 'مثلاً ۱.۱۵؛ همه ضرایب این ردیف در یک عدد'),
                          validator: (v) =>
                              parseCoefficientBp(v ?? '') == null
                                  ? 'ضریب مجاز ۰.۰۰۰۱ تا ۱۰ است' : null),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!(form.currentState?.validate() ??
                                          false)) return;
                                      setSheet(() => saving = true);
                                      try {
                                        await widget.store.saveBoqItem(
                                            companyId: widget.companyId,
                                            contractId: widget.contractId,
                                            itemId: item?.id,
                                            code: code.text,
                                            title: title.text,
                                            unit: unit.text,
                                            source: source.text,
                                            plannedQuantityMilli:
                                                parseQuantityMilli(quantity.text)!,
                                            unitPriceRial:
                                                tomanToRial(price.text,
                                                    allowZero: false)!,
                                            coefficientBp:
                                                parseCoefficientBp(
                                                    coefficient.text)!);
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      } catch (e) {
                                        if (sheetContext.mounted) {
                                          setSheet(() => saving = false);
                                          showFeedback(sheetContext,
                                              'ثبت ردیف انجام نشد: ' + e.toString(),
                                              error: true);
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.save_outlined),
                              label: Text(saving ? 'در حال ثبت...' : 'ذخیره ردیف'))),
                    ]),
                  )));
            }));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [code, title, unit, source, quantity, price, coefficient]) {
        c.dispose();
      }
    });
    if (done == true && mounted) await _refresh();
  }

  Future<void> _measure(BoqItem item) async {
    final quantity = TextEditingController();
    final reference = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    var correction = false;
    var date = isoDay(DateTime.now());
    var saving = false;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('ثبت متره · ' + item.code,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(item.title,
                    style: const TextStyle(color: muted)),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: correction,
                    title: const Text('ثبت اصلاح کاهشی'),
                    subtitle: const Text('مقدار قبلی پاک نمی‌شود؛ سند اصلاحی اضافه می‌شود.'),
                    onChanged: saving
                        ? null
                        : (value) => setSheet(() => correction = value)),
                TextFormField(
                    controller: quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                        labelText: 'مقدار ' + item.unit + ' *'),
                    validator: (v) => parseQuantityMilli(v ?? '') == null
                        ? 'مقدار مثبت با حداکثر ۳ رقم اعشار' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: reference,
                    maxLength: 100,
                    decoration: const InputDecoration(
                        labelText: 'شماره صورت‌جلسه / برگ متره *'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'مستند متره الزامی است' : null),
                const SizedBox(height: 12),
                JalaliDateField(
                    label: 'تاریخ متره',
                    value: date,
                    onChanged: (value) {
                      if (value != null) setSheet(() => date = value);
                    }),
                const SizedBox(height: 12),
                TextFormField(
                    controller: note,
                    maxLines: 2,
                    maxLength: 600,
                    decoration: InputDecoration(
                        labelText: correction
                            ? 'دلیل اصلاح کاهشی *'
                            : 'توضیحات عملیات (اختیاری)'),
                    validator: (value) =>
                        correction && (value ?? '').trim().length < 5
                        ? 'برای اصلاح، دلیل حداقل ۵ نویسه لازم است' : null),
                const SizedBox(height: 13),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!(form.currentState?.validate() ?? false)) {
                                  return;
                                }
                                setSheet(() => saving = true);
                                try {
                                  final q = parseQuantityMilli(quantity.text)!;
                                  await widget.store.recordBoqMeasurement(
                                    companyId: widget.companyId,
                                    contractId: widget.contractId,
                                    itemId: item.id,
                                    quantityMilli: correction ? -q : q,
                                    measuredAt: date,
                                    documentRef: reference.text,
                                    note: note.text,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setSheet(() => saving = false);
                                    showFeedback(ctx,
                                      'ثبت متره انجام نشد: ' + e.toString(),
                                      error: true);
                                  }
                                }
                              },
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(saving ? 'در حال ثبت...' : 'ثبت برگ متره'))),
              ]),
            ),
          ),
        );
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [quantity, reference, note]) {
        c.dispose();
      }
    });
    if (done == true && mounted) await _refresh();
  }

  Future<void> _draftStatement(BoqSnapshot snapshot) async {
    if (snapshot.unbilledCount == 0 || snapshot.pendingRial <= 0) return;
    final number = TextEditingController();
    final form = GlobalKey<FormState>();
    var date = isoDay(DateTime.now());
    var saving = false;
    final done = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.viewInsetsOf(ctx).bottom + 22),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('پیش‌نویس صورت‌وضعیت از متره',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text('متره‌های آزاد: ' + snapshot.unbilledCount.toString(),
                    style: const TextStyle(color: muted)),
                const SizedBox(height: 7),
                Text(tomanLabel(snapshot.pendingRial),
                    style: const TextStyle(
                        color: mint,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextFormField(
                    controller: number,
                    maxLength: 80,
                    decoration: const InputDecoration(
                        labelText: 'شماره صورت‌وضعیت *'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'شماره صورت‌وضعیت لازم است' : null),
                const SizedBox(height: 10),
                JalaliDateField(
                    label: 'تاریخ صورت‌وضعیت',
                    value: date,
                    onChanged: (value) {
                      if (value != null) setSheet(() => date = value);
                    }),
                const SizedBox(height: 12),
                const Text(
                    'این عملیات همه متره‌های تخصیص‌نیافته قرارداد را '
                    'به یک صورت‌وضعیت در وضعیت پیش‌نویس متصل می‌کند. '
                    'بعد از ثبت، مقادیر و ناخالص این سند قفل خواهند بود. '
                    'ارزش افزوده، کسورات، اسناد رسیدگی و تأیید کارفرما '
                    'باید جداگانه بررسی و تکمیل شوند.',
                    style: TextStyle(
                        color: muted, fontSize: 12, height: 1.6)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!(form.currentState?.validate() ?? false)) {
                              return;
                            }
                            setSheet(() => saving = true);
                            try {
                              await widget.store.draftStatementFromBoq(
                                companyId: widget.companyId,
                                contractId: widget.contractId,
                                number: number.text,
                                statementDate: date,
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheet(() => saving = false);
                                showFeedback(ctx,
                                    'پیش‌نویس ساخته نشد: ' + e.toString(),
                                    error: true);
                              }
                            }
                          },
                    icon: const Icon(Icons.article_outlined),
                    label: Text(saving ? 'در حال صدور...' : 'ایجاد پیش‌نویس امن'),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => number.dispose());
    if (done == true && mounted) {
      await _refresh();
      if (mounted) showFeedback(context,
          'پیش‌نویس در بخش صورت‌وضعیت‌ها ثبت شد؛ هنوز تأیید نشده است.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('متره، برآورد و صورت‌وضعیت'),
      actions: [
        IconButton(
            tooltip: 'بارگذاری مجدد',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh),
      ],
    ),
    body: FutureBuilder<BoqSnapshot>(
      future: future,
      builder: (context, state) {
        if (state.hasError) {
          return Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('اطلاعات برآورد بارگذاری نشد: ' +
                  state.error.toString())));
        }
        if (!state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = state.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
            children: [
              const Text('دفتر متره قرارداد فعال',
                  style: TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'قیمت‌گذاری ردیفی و مقدار اجرایی با مستندات؛ '
                  'مبالغ به ریال ذخیره و به تومان نمایش داده می‌شوند.',
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 15),
              Row(children: [
                Expanded(child: _amount('ارزش برآورد اولیه', data.plannedRial)),
                const SizedBox(width: 10),
                Expanded(child: _amount(
                    'ارزش متره انجام‌شده', data.measuredRial, tint: mint)),
              ]),
              const SizedBox(height: 10),
              _amount('متره صورت‌وضعیت‌نشده',
                  data.pendingRial, tint: const Color(0xFFFFC0A4)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: _editItem,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('افزودن ردیف برآورد')),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: data.unbilledCount > 0 && data.pendingRial > 0
                      ? () => _draftStatement(data) : null,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('صدور پیش‌نویس صورت‌وضعیت از متره')),
              const SizedBox(height: 20),
              const SectionHeading('ردیف‌های فهرست‌بها'),
              const SizedBox(height: 11),
              if (data.items.isEmpty)
                const EmptyView(
                    title: 'فهرست ردیف‌ها خالی است',
                    subtitle: 'ردیف‌های پیمان را همراه قیمت و واحد ثبت کنید.'),
              for (final item in data.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: VipCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(
                              item.code + ' · ' + item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800))),
                          if (item.measuredQuantityMilli == 0)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'ویرایش ردیف بدون متره',
                              onPressed: () => _editItem(item),
                            ),
                        ]),
                        const SizedBox(height: 5),
                        Text(
                          (item.source.isEmpty ? 'منبع قیمت ثبت نشده' : item.source) +
                          ' · واحد: ' + item.unit,
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(height: 11),
                        Text('مقدار مبنا: ' +
                            formatScaled(item.plannedQuantityMilli) +
                            ' · نرخ واحد: ' + tomanLabel(item.unitPriceRial)),
                        Text('ضریب: ' + formatScaled(item.coefficientBp,
                              scale: 10000, decimals: 4),
                            style: const TextStyle(color: muted)),
                        const SizedBox(height: 9),
                        Text('متره تجمعی: ' +
                            formatScaled(item.measuredQuantityMilli) +
                            ' ' + item.unit,
                            style: const TextStyle(color: mint)),
                        Text('مقدار آزاد برای صورت‌وضعیت: ' +
                            formatScaled(item.pendingQuantityMilli) +
                            ' ' + item.unit,
                            style: const TextStyle(color: champagne)),
                        const SizedBox(height: 9),
                        OutlinedButton.icon(
                          onPressed: () => _measure(item),
                          icon: const Icon(Icons.straighten_outlined),
                          label: const Text('ثبت برگ متره یا اصلاح مقدار'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const SectionHeading('تاریخچه برگ‌های متره'),
              const SizedBox(height: 9),
              if (data.measurements.isEmpty)
                const Text('هنوز برگ متره ثبت نشده است.',
                    style: TextStyle(color: muted)),
              for (final measure in data.measurements.take(40))
                ListTile(
                  dense: true,
                  leading: Icon(
                      measure.quantityMilli < 0
                          ? Icons.history_toggle_off
                          : Icons.fact_check_outlined,
                      color: measure.quantityMilli < 0
                          ? const Color(0xFFFFC0A4) : mint),
                  title: Text(measure.itemCode + ' · ' +
                      formatScaled(measure.quantityMilli),
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      jalaliLabel(measure.date) + ' · ' + measure.documentRef +
                      (measure.note.isEmpty ? '' : '\n' + measure.note),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 11, color: muted)),
                  trailing: Text(
                      measure.statementId == null
                          ? 'آزاد'
                          : 'سند ' + measure.statementId.toString(),
                      style: const TextStyle(fontSize: 11, color: champagne)),
                ),
              const SizedBox(height: 15),
              const Text(
                'این بخش دفتر متره داخلی است، نه تأیید مهندس مشاور یا '
                'صورت‌وضعیت قطعی. ضریب و قیمت از مدارک خود پیمان '
                'و فهرست‌بهای سال مربوط گرفته شود.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.6),
              ),
            ],
          ),
        );
      },
    ),
  );
}
