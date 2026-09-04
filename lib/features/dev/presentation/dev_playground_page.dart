import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../services/local_notification_rest_notifier.dart';
import '../../../services/rest_notifier.dart';
import '../../workout/models/numeric_input.dart';
import '../../workout/presentation/widgets/numeric_keypad.dart';
import '../../workout/presentation/widgets/rest_timer_bar.dart';
import '../../workout/presentation/widgets/set_row.dart';
import '../../workout/state/rest_timer_view_model.dart';

/// Phase 0 技术验证页（仅 debug 注册）。
///
/// 验证三件事：
/// - V-3 记录速度：右上角计数器统计从进入页面起的点击次数，目标"完成 3 组 ≤ 6 次"
/// - V-1 后台提醒：完成一组自动开 10 秒计时并预约通知，锁屏看是否准时
/// - 键盘 / 组行 / 计时条三个组件的手感
///
/// 数据全在内存，不碰 DB。Phase 3 真实训练页落地后删除本页。
class DevPlaygroundPage extends ConsumerStatefulWidget {
  const DevPlaygroundPage({super.key});

  @override
  ConsumerState<DevPlaygroundPage> createState() => _DevPlaygroundPageState();
}

class _SetEntry {
  _SetEntry({required this.weight, required this.reps});

  String weight;
  String reps;
  bool done = false;
}

class _DevPlaygroundPageState extends ConsumerState<DevPlaygroundPage> {
  static const _minIncrement = 2.5;
  static const _restSeconds = 10; // 验证用短计时

  final List<_SetEntry> _sets = [
    _SetEntry(weight: '20', reps: '12'),
    _SetEntry(weight: '20', reps: '12'),
    _SetEntry(weight: '20', reps: '12'),
  ];

  int? _focusIndex;
  SetField? _focusField;
  bool _fresh = true;
  int _taps = 0;
  String _status = '';

  void _tap() => _taps++;

  void _focus(int index, SetField field) {
    _tap();
    setState(() {
      if (_sets[index].done) {
        _sets[index].done = false; // 点已完成组的字段 = 解锁修改
      }
      _focusIndex = index;
      _focusField = field;
      _fresh = true;
    });
  }

  String _current() {
    final e = _sets[_focusIndex!];
    return _focusField == SetField.weight ? e.weight : e.reps;
  }

  void _write(String v) {
    final e = _sets[_focusIndex!];
    if (_focusField == SetField.weight) {
      e.weight = v;
    } else {
      e.reps = v;
    }
  }

  void _onDigit(String d) {
    _tap();
    if (_focusIndex == null) return;
    setState(() {
      if (d == '.') {
        _write(NumericInput.dot(_current(), fresh: _fresh));
      } else {
        _write(NumericInput.digit(_current(), d, fresh: _fresh));
      }
      _fresh = false;
    });
  }

  void _onAction(KeypadAction a) {
    _tap();
    if (_focusIndex == null) return;
    final isWeight = _focusField == SetField.weight;
    setState(() {
      switch (a) {
        case KeypadAction.backspace:
          _write(NumericInput.backspace(_current()));
          _fresh = false;
        case KeypadAction.stepDown:
          _write(NumericInput.step(_current(), isWeight ? -_minIncrement : -1,
              allowDecimal: isWeight));
          _fresh = false;
        case KeypadAction.stepUp:
          _write(NumericInput.step(_current(), isWeight ? _minIncrement : 1,
              allowDecimal: isWeight));
          _fresh = false;
        case KeypadAction.next:
          if (isWeight) {
            _focusField = SetField.reps;
            _fresh = true;
          } else {
            _complete(_focusIndex!, countTap: false);
          }
        case KeypadAction.done:
          _complete(_focusIndex!, countTap: false);
      }
    });
  }

  void _complete(int index, {bool countTap = true}) {
    if (countTap) _tap();
    setState(() {
      final e = _sets[index];
      if (e.done) {
        e.done = false;
        return;
      }
      e.done = true;
      _focusIndex = null;
      _focusField = null;
      // 完成最后一组 → 自动生成下一组，继承重量与次数。
      if (index == _sets.length - 1) {
        _sets.add(_SetEntry(weight: e.weight, reps: e.reps));
      }
    });
    ref.read(restTimerProvider.notifier).start(_restSeconds);
  }

  Future<void> _scheduleOnly() async {
    final at = ref.read(clockProvider).now().add(const Duration(seconds: 15));
    await ref.read(restNotifierProvider).scheduleRestEnd(at);
    setState(() => _status = '已预约 15 秒后通知，请立刻锁屏');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = _focusIndex != null;
    final isWeight = _focusField == SetField.weight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 0 验证'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '点击 $_taps',
                style: TextStyle(
                  fontSize: AppTextSize.md,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  '高位下拉',
                  style: TextStyle(
                    fontSize: AppTextSize.lg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上次：20kg × 12 / 12 / 12（黑熊猫 机器A）',
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _sets.length; i++) ...[
                  SetRow(
                    index: i + 1,
                    weightText: _sets[i].weight,
                    repsText: _sets[i].reps,
                    isCompleted: _sets[i].done,
                    focusedField: _focusIndex == i ? _focusField : null,
                    onTapField: (f) => _focus(i, f),
                    onToggleComplete: () => _complete(i),
                  ),
                  const SizedBox(height: 6),
                ],
                TextButton.icon(
                  onPressed: () {
                    _tap();
                    final last = _sets.last;
                    setState(() => _sets.add(
                          _SetEntry(weight: last.weight, reps: last.reps),
                        ));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加一组'),
                ),
                const Divider(height: 32),
                Text(
                  '后台提醒验证',
                  style: TextStyle(
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final n = ref.read(restNotifierProvider);
                        if (n is LocalNotificationRestNotifier) {
                          final ok = await n.requestExactAlarms();
                          setState(() => _status = '精确闹钟：${ok ? '已授予' : '未授予'}');
                        } else {
                          setState(() => _status = '当前平台无通知实现');
                        }
                      },
                      child: const Text('申请精确闹钟'),
                    ),
                    OutlinedButton(
                      onPressed: _scheduleOnly,
                      child: const Text('预约 15 秒后通知'),
                    ),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(restTimerProvider.notifier)
                          .start(120),
                      child: const Text('开 120 秒计时'),
                    ),
                  ],
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: AppTheme.of(context).timerActive,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const RestTimerBar(),
          if (focused)
            NumericKeypad(
              step: isWeight ? _minIncrement : 1,
              allowDecimal: isWeight,
              onDigit: _onDigit,
              onAction: _onAction,
            ),
        ],
      ),
    );
  }
}
