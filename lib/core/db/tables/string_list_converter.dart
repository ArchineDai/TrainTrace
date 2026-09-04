import 'dart:convert';

import 'package:drift/drift.dart';

/// `List<String>` ↔ JSON 文本列。
///
/// 用于动作要领 / 常见错误 / 常见机器这类"只读、整体读写、不需要单独查询"的
/// 短列表。需要按元素查询的数据请建子表，不要用这个转换器。
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) return decoded.whereType<String>().toList();
    } on FormatException {
      // 坏数据不炸整张表，按空列表处理。
    }
    return const [];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
