/// 自定义数字键盘的编辑规则。纯函数，被 [NumericKeypad] 与训练页共用。
///
/// 输入框里的值以字符串形态编辑（"22." 是合法中间态），提交时再 [parse]。
abstract final class NumericInput {
  NumericInput._();

  static const maxLength = 6;

  /// 追加一位数字。
  ///
  /// [fresh]：刚聚焦、还没敲过键 —— 第一位数字**替换**继承来的默认值而不是追加，
  /// 这是"继承上一组重量"能一键改掉的关键。
  static String digit(String current, String d, {required bool fresh}) {
    assert(d.length == 1 && '0123456789'.contains(d));
    final base = fresh ? '' : current;
    if (base.length >= maxLength) return base;
    if (base == '0') return d; // "0" 后面敲 5 → "5"，不是 "05"
    return '$base$d';
  }

  /// 小数点。空值上敲 "." 得 "0."；已有小数点则忽略。
  static String dot(String current, {required bool fresh}) {
    final base = fresh ? '' : current;
    if (base.contains('.')) return base;
    if (base.isEmpty) return '0.';
    if (base.length >= maxLength) return base;
    return '$base.';
  }

  static String backspace(String current) =>
      current.isEmpty ? current : current.substring(0, current.length - 1);

  /// ±步长。空值按 0 起算；不低于 0；结果去掉多余的 0。
  static String step(String current, double delta, {required bool allowDecimal}) {
    final v = (parse(current) ?? 0) + delta;
    final clamped = v < 0 ? 0.0 : v;
    return format(clamped, allowDecimal: allowDecimal);
  }

  static double? parse(String s) {
    if (s.isEmpty || s == '.') return null;
    return double.tryParse(s.endsWith('.') ? '${s}0' : s);
  }

  /// 数字 → 编辑用字符串。整数不带小数点；小数最多两位、去尾 0。
  static String format(double v, {required bool allowDecimal}) {
    if (!allowDecimal || v == v.roundToDouble()) return v.round().toString();
    var s = v.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
