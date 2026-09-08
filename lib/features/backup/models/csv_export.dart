// CSV 导出的选项与计数。纯 Dart，presentation / state 只看这些。

/// 导出格式。
///
/// - [traintrace]：全字段，含 RIR、器械标签、场馆、备注，给自己在 Excel / WPS 里看。
/// - [hevy]：照 Hevy 官方导出的表头，能直接喂给 Hevy / Strong 的导入。
///   本项目没有的列（superset / 距离 / 时长）留空。
enum CsvExportFormat { traintrace, hevy }

/// 导出范围，按训练开始时间过滤。边界由 `Clock` 的"现在"算。
enum CsvExportRange { all, thisYear, last3Months }

/// 某个范围内会导出多少：训练次数与组数。页面用它显示「128 次训练 · 3,412 组」。
///
/// 两个数都从同一条 JOIN 查询里数出来，与真正导出的行数一致：
/// 一次训练里若没有任何已完成的组，它不会出现在 CSV 里，也不计入 [sessions]。
class CsvExportCount {
  const CsvExportCount({required this.sessions, required this.sets});

  final int sessions;
  final int sets;

  bool get isEmpty => sets == 0;
}
