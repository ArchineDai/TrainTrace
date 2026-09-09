import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import 'segments/body_segment.dart';
import 'segments/overview_segment.dart';
import 'segments/training_segment.dart';

/// 数据 Tab 容器：AppBar + 概览 / 训练 / 身体三段（PLAN-v0.6 §2.1）。
///
/// 容器只挑一个段渲染，不向段传参 —— 每个段自己 watch 自己的 provider、自己管
/// 自己的区间。切段不保段内滚动位置，§2.1 明确接受。
///
/// 段选中是页面局部态（没有第二个页面要读它），所以 `setState` 而不是 provider
/// （变更纪律 2）。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// 当前段。默认与 `HistoryTab.parse(null)` 一致（概览）。
  HistoryTab _tab = HistoryTab.overview;

  /// 上一帧从 URL 读到的 `tab` 原值。
  ///
  /// 页内切段**不回写 URL**（回写会污染返回栈，§1.3），所以 URL 上的值只在
  /// "外面又来了一条带 tab 的深链"时变化 —— 比较原值就能把这种情况和页内切段
  /// 区分开。不比较的话，页面一旦建好（Tab 分支是保活的），设置页跳身体段就再
  /// 也没反应。
  String? _urlTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final urlTab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (urlTab != _urlTab) {
      _urlTab = urlTab;
      // 非法值由 parse 兜到概览；null 是"没指定"，保留用户当前选中的段。
      if (urlTab != null) _tab = HistoryTab.parse(urlTab);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHistory)),
      body: Column(
        children: [
          Padding(
            // 下 8 + 三个段自己 ListView 的上 8 = 设计稿 Main 画板的 16。
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<HistoryTab>(
              segments: [
                ButtonSegment(
                  value: HistoryTab.overview,
                  label: Text(l10n.segmentOverview),
                ),
                ButtonSegment(
                  value: HistoryTab.training,
                  label: Text(l10n.segmentTraining),
                ),
                ButtonSegment(
                  value: HistoryTab.body,
                  label: Text(l10n.segmentBody),
                ),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              HistoryTab.overview => const OverviewSegment(),
              HistoryTab.training => const TrainingSegment(),
              HistoryTab.body => const BodySegment(),
            },
          ),
        ],
      ),
    );
  }
}
