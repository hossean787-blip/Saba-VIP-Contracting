import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../data/offline_store.dart';
import '../finance/finance_kind.dart';
import '../widgets/ui.dart';
import 'contract_detail.dart';
import 'entry_sheet.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.store, required this.company,
    required this.area, required this.onOpenContracts});
  final OfflineStore store;
  final Map<String, Object?> company;
  final FinanceArea area;
  final VoidCallback onOpenContracts;
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late FinanceKind selected;
  late Future<List<Map<String,Object?>>> future;
  int get companyId => widget.company['id'] as int;
  @override
  void initState() {
    super.initState();
    selected = widget.area.kinds.first;
    _load();
  }
  void _load() => future = widget.store.financialRecords(companyId, selected);
  void _refresh() => setState(_load);

  Future<void> _add() async {
    final contracts = await widget.store.contracts(companyId);
    if (!mounted) return;
    if (contracts.isEmpty) {
      showFeedback(context,'ابتدا یک قرارداد ثبت کنید.');
      widget.onOpenContracts();
      return;
    }
    final selectedId = await showModalBottomSheet<int>(
      context: context, useSafeArea:true, isScrollControlled:true,
      builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .65,
        child: Column(children:[
          const Padding(padding:EdgeInsets.all(20),child:Text('انتخاب قرارداد',
            style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
          Expanded(child:ListView.builder(itemCount:contracts.length,
            itemBuilder:(_,i) => ListTile(
              leading:const Icon(Icons.folder_open_outlined,color:champagne),
              title:Text(contracts[i]['title'].toString()),
              subtitle:Text('شماره '+contracts[i]['contract_no'].toString()),
              trailing:const Icon(Icons.chevron_left),
              onTap:()=>Navigator.pop(ctx,contracts[i]['id'] as int),
            ),
          )),
        ]),
      )),
    );
    if (selectedId==null || !mounted) return;
    final saved=await showModalBottomSheet<bool>(
      context:context,isScrollControlled:true,useSafeArea:true,
      builder:(_)=>EntrySheet(store:widget.store,contractId:selectedId,kind:selected.table),
    );
    if (saved == true && mounted) _refresh();
  }
  Color get tint=>widget.area==FinanceArea.outflows
    ? const Color(0xFFFFC0A4) : mint;
  String _entryTitle(Map<String,Object?> r)=>switch(selected) {
    FinanceKind.expenses => r['category'].toString(),
    FinanceKind.payments => 'پرداخت نقدی',
    FinanceKind.receipts => 'دریافت نقدی',
    FinanceKind.statements => 'صورت‌وضعیت '+r['statement_no'].toString(),
  };
  String _status(Object? status)=>switch(status) {
    'APPROVED'=>'تأییدشده', 'DRAFT'=>'پیش‌نویس',
    'SUBMITTED'=>'ارسال‌شده','REJECTED'=>'ردشده',_=>'',
  };
  @override
  Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(
    future:future,
    builder:(context,snapshot) {
      if (snapshot.hasError) return Center(child:Text('خطا در خواندن اطلاعات مالی'));
      if (!snapshot.hasData) return const Center(child:CircularProgressIndicator());
      final rows=snapshot.data!;
      final total=rows.fold<int>(0,(sum,row)=>sum+(row[selected.amountField] as int));
      return RefreshIndicator(
        onRefresh:() async { _refresh();await future; },
        child:ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:const EdgeInsets.fromLTRB(18,20,18,110),
          children:[
            Text(widget.area.title,style:const TextStyle(color:ivory,fontSize:26,fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            const Text('اطلاعات مالی همه قراردادهای شرکت',style:TextStyle(color:muted)),
            const SizedBox(height:15),
            VipCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Icon(widget.area==FinanceArea.outflows ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded,color:tint),
                const SizedBox(width:10),
                Expanded(child:Text('مجموع '+selected.label,
                  style:const TextStyle(color:muted))),
              ]),
              const SizedBox(height:14),
              FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerRight,
                child:Text(tomanLabel(total),style:TextStyle(color:tint,fontSize:27,fontWeight:FontWeight.w800))),
              const SizedBox(height:7),
              Text(rows.length.toString()+' مورد ثبت‌شده',style:const TextStyle(fontSize:12,color:muted)),
            ])),
            const SizedBox(height:15),
            Wrap(spacing:8,children:[
              for(final kind in widget.area.kinds)
                ChoiceChip(label:Text(kind.label),selected:selected==kind,
                  onSelected:(_)=>setState((){selected=kind;_load();})),
            ]),
            const SizedBox(height:10),
            Text(widget.area.note,style:const TextStyle(fontSize:12,color:muted,height:1.5)),
            const SizedBox(height:17),
            FilledButton.icon(onPressed:_add,icon:const Icon(Icons.add_circle_outline),
              label:Text('ثبت '+selected.singleLabel+' جدید')),
            const SizedBox(height:22),
            SectionHeading('فهرست '+selected.label),
            const SizedBox(height:13),
            if(rows.isEmpty)const EmptyView(
              title:'اطلاعاتی ثبت نشده',
              subtitle:'با انتخاب قرارداد، ثبت جدید را آغاز کنید.',
              icon:Icons.account_balance_wallet_outlined),
            for(final row in rows) Padding(padding:const EdgeInsets.only(bottom:10),
              child:InkWell(
                borderRadius:BorderRadius.circular(22),
                onTap:() async {
                  await Navigator.push(context,MaterialPageRoute(builder:(_)=>ContractDetailScreen(
                    store:widget.store,company:widget.company,contractId:row['contract_id'] as int)));
                  if(mounted)_refresh();
                },
                child:VipCard(padding:const EdgeInsets.all(14),child:Row(children:[
                  Icon(selected==FinanceKind.expenses ? Icons.receipt_long_outlined
                    :selected==FinanceKind.payments ? Icons.north_east_rounded
                    :selected==FinanceKind.receipts ? Icons.south_west_rounded
                    : Icons.description_outlined,color:tint,size:28),
                  const SizedBox(width:12),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(_entryTitle(row),style:const TextStyle(fontWeight:FontWeight.bold),
                      maxLines:1,overflow:TextOverflow.ellipsis),
                    const SizedBox(height:5),
                    Text(row['contract_title'].toString()+' • '+jalaliLabel(
                        row[selected.dateField]?.toString()),
                      style:const TextStyle(fontSize:11,color:muted),maxLines:2),
                    if(selected==FinanceKind.statements)Text(_status(row['status']),
                      style:const TextStyle(fontSize:11,color:champagne)),
                  ])),
                  const SizedBox(width:5),
                  FittedBox(fit:BoxFit.scaleDown,
                    child:Text(tomanLabel(row[selected.amountField] as int),
                      style:TextStyle(color:tint,fontSize:12,fontWeight:FontWeight.bold))),
                  const Icon(Icons.chevron_left,color:muted,size:17),
                ])),
              ),
            ),
          ],
        ),
      );
    },
  );
}
