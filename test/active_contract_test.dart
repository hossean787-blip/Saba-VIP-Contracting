import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/data/active_contract.dart';

void main() {
  final contracts = <Map<String, Object?>>[
    {'id': 7, 'title': 'شهرداری'},
    {'id': 4, 'title': 'پروژه صنعتی'},
  ];

  test('no contracts means no active context', () {
    expect(ActiveContract.resolve(const [], 7), isNull);
    expect(ActiveContract.find(const [], 7), isNull);
  });
  test('valid saved selection remains active', () {
    expect(ActiveContract.resolve(contracts, 4), 4);
    expect(ActiveContract.find(contracts, 4)?['title'], 'پروژه صنعتی');
  });
  test('first contract selected on first launch', () {
    expect(ActiveContract.resolve(contracts, null), 7);
  });
  test('invalid selection falls back safely', () {
    expect(ActiveContract.resolve(contracts, 999), 7);
    expect(ActiveContract.find(contracts, 999), isNull);
  });
}
