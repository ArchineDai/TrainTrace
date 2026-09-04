import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/workout/models/numeric_input.dart';

void main() {
  group('digit', () {
    test('fresh 时第一位替换继承值', () {
      expect(NumericInput.digit('20', '2', fresh: true), '2');
      expect(NumericInput.digit('2', '5', fresh: false), '25');
    });
    test('"0" 后敲数字不产生前导 0', () {
      expect(NumericInput.digit('0', '5', fresh: false), '5');
    });
    test('超长忽略', () {
      expect(NumericInput.digit('123456', '7', fresh: false), '123456');
    });
  });

  group('dot', () {
    test('空值敲点得 "0."', () {
      expect(NumericInput.dot('', fresh: false), '0.');
      expect(NumericInput.dot('20', fresh: true), '0.');
    });
    test('重复小数点忽略', () {
      expect(NumericInput.dot('2.5', fresh: false), '2.5');
    });
  });

  test('backspace', () {
    expect(NumericInput.backspace('22.5'), '22.');
    expect(NumericInput.backspace(''), '');
  });

  group('step', () {
    test('±2.5 去掉多余的 0', () {
      expect(NumericInput.step('20', 2.5, allowDecimal: true), '22.5');
      expect(NumericInput.step('22.5', 2.5, allowDecimal: true), '25');
    });
    test('不低于 0', () {
      expect(NumericInput.step('1', -2.5, allowDecimal: true), '0');
    });
    test('次数不带小数', () {
      expect(NumericInput.step('12', 1, allowDecimal: false), '13');
      expect(NumericInput.step('', 1, allowDecimal: false), '1');
    });
    test('中间态 "22." 可参与步进', () {
      expect(NumericInput.step('22.', 2.5, allowDecimal: true), '24.5');
    });
  });

  test('parse', () {
    expect(NumericInput.parse(''), isNull);
    expect(NumericInput.parse('.'), isNull);
    expect(NumericInput.parse('22.'), 22.0);
    expect(NumericInput.parse('0.5'), 0.5);
  });
}
