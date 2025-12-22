import 'package:flutter_test/flutter_test.dart';

import 'package:remark_money/services/voice_record_parser.dart';

void main() {
  test('parseMany removes currency words from remark', () {
    final items = VoiceRecordParser.parseMany('我今天吃饭花了200块钱');
    expect(items.length, 1);
    expect(items.first.amount, 200);
    // Should not end up with a meaningless remark like "钱"
    expect(items.first.remark, isNot('钱'));
  });

  test('parseMany removes trailing verb after amount removal', () {
    final items = VoiceRecordParser.parseMany('我今天打车花100');
    expect(items.length, 1);
    expect(items.first.amount, 100);
    expect(items.first.remark.endsWith('花'), isFalse);
    expect(items.first.categoryHint.endsWith('花'), isFalse);
  });
}
