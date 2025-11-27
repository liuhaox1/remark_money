import 'package:flutter/material.dart';

class BankBrand {
  const BankBrand({
    required this.key,
    required this.displayName,
    required this.shortName,
    required this.color,
  });

  final String key;
  final String displayName;
  final String shortName;
  final Color color;
}

const List<BankBrand> kSupportedBankBrands = [
  BankBrand(
    key: 'icbc',
    displayName: '工商银行',
    shortName: '工行',
    color: Color(0xFFD7000F),
  ),
  BankBrand(
    key: 'abc',
    displayName: '农业银行',
    shortName: '农行',
    color: Color(0xFF00836A),
  ),
  BankBrand(
    key: 'boc',
    displayName: '中国银行',
    shortName: '中行',
    color: Color(0xFFB0002D),
  ),
  BankBrand(
    key: 'ccb',
    displayName: '建设银行',
    shortName: '建行',
    color: Color(0xFF004A9F),
  ),
  BankBrand(
    key: 'cmb',
    displayName: '招商银行',
    shortName: '招行',
    color: Color(0xFFB62D25),
  ),
  BankBrand(
    key: 'bocom',
    displayName: '交通银行',
    shortName: '交行',
    color: Color(0xFF0F3A90),
  ),
  BankBrand(
    key: 'spdb',
    displayName: '浦发银行',
    shortName: '浦发',
    color: Color(0xFF003B73),
  ),
  BankBrand(
    key: 'cib',
    displayName: '兴业银行',
    shortName: '兴业',
    color: Color(0xFF1A4F9C),
  ),
  BankBrand(
    key: 'psbc',
    displayName: '邮储银行',
    shortName: '邮储',
    color: Color(0xFF3AAD4F),
  ),
  BankBrand(
    key: 'ceb',
    displayName: '光大银行',
    shortName: '光大',
    color: Color(0xFFF39C12),
  ),
  BankBrand(
    key: 'citic',
    displayName: '中信银行',
    shortName: '中信',
    color: Color(0xFFB71C1C),
  ),
  BankBrand(
    key: 'cmbc',
    displayName: '民生银行',
    shortName: '民生',
    color: Color(0xFF00A5E3),
  ),
  BankBrand(
    key: 'gdb',
    displayName: '广发银行',
    shortName: '广发',
    color: Color(0xFFE53935),
  ),
  BankBrand(
    key: 'pab',
    displayName: '平安银行',
    shortName: '平安',
    color: Color(0xFFFF7043),
  ),
  BankBrand(
    key: 'hxb',
    displayName: '华夏银行',
    shortName: '华夏',
    color: Color(0xFFB71C1C),
  ),
  BankBrand(
    key: 'other_bank',
    displayName: '其他银行',
    shortName: '其他',
    color: Color(0xFF8E8E93),
  ),
];

BankBrand? findBankBrand(String? key) {
  if (key == null) return null;
  return kSupportedBankBrands.firstWhere(
    (brand) => brand.key == key,
    orElse: () => const BankBrand(
      key: 'custom',
      displayName: '其他银行',
      shortName: '银行',
      color: Color(0xFF6B7280),
    ),
  );
}

