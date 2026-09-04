# UI 约定

## Token

| 要什么 | 去哪拿 |
|---|---|
| 颜色 | `AppTheme.*`（语义色）或 `Theme.of(context).colorScheme.*` |
| 字号 | `AppTextSize.xs / sm / md / lg / xl / number / timer` |
| 圆角 | `AppTheme.radius` |
| 最小触控 | `AppTheme.minTouch`（48dp） |
| 提示 | `AppTheme.showToast(context, msg)` |

`lib/features` 与 `lib/shared` 里不写 `Color(0xFF...)` 和 `fontSize: <数字>`。

## 训练页专项

- 一屏完成一组记录：改次数 + 点完成 ≤ 2 次点击。
- 数字输入用自定义键盘面板（`numeric_keypad.dart`），不用系统键盘。
- 每组是独立 widget，只 `select` 自己那一组。
- 完成态用 `AppTheme.setDone` / `setDoneSurface`，计时用 `timerActive` / `timerFinished`。
- 手出汗、边走边点：按钮 ≥ 48dp，相邻可点区域间距 ≥ 8dp。

## 主题

亮暗两套均由 `AppTheme.seed` 派生，跟随系统。语义色亮暗共用。
