# Backlog

> 决定要不要动手修某个已知问题时读这份。已了结的移到底部索引。

## 待验证（Phase 0 技术验证）

- **V-1 后台提醒**：模拟器（Android 17）上 `zonedSchedule` 15 秒预约按时送达
  （2026-09-04，`dumpsys notification` 可见 id=1001）。**vivo 真机未验证**：
  USB 安装需在手机上手动确认，且 OriginOS 可能要求关闭省电 / 允许后台弹出。
  精确闹钟（targetSdk 36 下 Android 14+ 默认不授予）已改为进训练页时权限没齐弹引导申请（只弹一次）
  （`RestReminderGuideSheet`，设置页「休息结束提醒」有开关，权限没齐时可再进引导），未授予仍退化为
  `inexactAllowWhileIdle`；另加了前台 Dart Timer 到点立即弹（`RestTimerViewModel`），
  进程活着时不再依赖系统闹钟。2026-09-07 前用户反馈"时而有时而没有"即此因。
- **V-2 进程被杀恢复**：模拟器上 `am force-stop` 后重启，首页横幅显示已完成组数，
  进入训练页后用时从原始开始时间累计、计时按 `rest_ends_at` 重算（2026-09-04 通过）。
  **vivo 真机未验证**，且真机上还要试"训练中接电话 / 切微信被系统回收"这种非主动杀。

## V0.5 候选（2026-09-08 定稿设计）

> 竞品盘点后按"新手个人用、离线"筛出的七项，按价值排序。UI 稿见
> https://claude.ai/code/artifact/117fba66-53c1-492f-9f48-016d2939c394 ，每张稿上方的便签写了要动的表。
> 稿子按现有 token 画：训练页深色、详情页与备份页浅色，组行 / 卡片 / 键盘尺寸照 `set_row.dart`、
> `workout_exercise_card.dart`。社交、手表、健康平台同步、AI 黑盒推荐四类明确不做，与"个人优先"冲突。

- **F-1 上次备注回显**（2026-09-08 已落地，真机未验证）：读回上次同动作（先按器械标签匹配，再回落任意标签）最近一条非空的
  `workout_exercises.note`，放在训练卡片"上次表现"下方独立灰底块，带日期。右侧"本次备注"进单字段对话框，
  当前没写时预填上次的文本（座椅档位这种备注每次都一样，一次确认即沿用）。有本次备注时块内显示本次而不是上次。
  卡片菜单加"添加 / 编辑备注"。不改表。
- **F-2 超级组**（2026-09-08 已落地，真机未验证）：加列 `workout_exercises.superset_group`（可空 int）。同组卡片共享左侧 4dp 橙条和组头，
  A1 / A2 是位置标记。休息条只在一轮（A1 + A2）都完成后出现，组内不计时。卡片菜单加"与下一动作组成超级组"。
- **F-3 1RM 趋势线**（2026-09-08 已落地，真机未验证）：动作详情页"个人记录"与"最近记录"之间插一段。单系列橙线 2px、8px 点、最后一点直接标值，
  区间 4 周 / 3 个月 / 全部，下方一行涨幅用 `setDone` 绿。数据用 `HistoryRepository.recentPerformances` 加
  `estimateOneRm` 就够，不改表。
- **F-4 体重与自重动作**（2026-09-08 已落地，真机未验证）：新表 `body_weights(id, weight_kg, measured_at)` + 同步三列。自重动作的器械芯片换成
  "自重 72 kg"，点开底部弹层更新体重；重量列变附加重量，带 + 号，辅助引体填负数；容量 = 体重 + 附加。
  `exercises` 需要一个"是否自重"的标记（种子 JSON 定）。
- **F-5 计时类动作**（2026-09-08 已落地，真机未验证）：`exercises` 加 `measure: reps | seconds | distance`，`workout_sets` 加
  `duration_seconds`。单字段组行；进行中的组显示 `0:37 / 50 秒`，右侧按钮变 ✕ 提前结束并记实际秒数；
  键盘秒模式步长 5，"下一项"换成"开始计时"。农夫行走一类是 kg × 米。
- **F-6 板片计算器**（2026-09-08 已落地，真机未验证）：只对 `equipmentType` 为杠铃的动作显示，重量输入框长按进入。杠重 20 / 15 / 10 三选一
  记入 `app_settings`。"上一组 / 下一档"两行是免输入的最常用查法，"填入"把重量写回当前组。纯函数，必写测试。
- **F-7 CSV 导出**（2026-09-08 已落地，真机未验证）：放备份页下方独立分组，两种格式：TrainTrace 全字段（含 RIR、器械标签、场馆、备注）/
  Hevy 兼容（title, start_time, end_time, exercise_title, set_index, set_type, weight_kg, reps, rpe）。
  UTF-8 带 BOM，表头固定英文。落盘走和备份同一套 `FilePicker.saveFile`，不引 `share_plus`。
  同时了结 D-2。

落地时与稿子的出入（多 agent 并行开发，2026-09-08 合并）：

- F-2：`RestTimerBar` 是单行，没有加"第 n 轮结束"副标题。组头显示的休息秒数与实际计时一致，都取组尾动作的。
  入口照 Hevy 重做（2026-09-08 二次修订）：卡片菜单常驻「超级组…」打开配对弹层（勾选即生效，不相邻的自动挪到一起），
  相邻两张卡片之间有「组成超级组」连接件，组头右侧「⋯」可加成员或拆组。
- F-4：辅助引体不走负号键，而是照 Strong / Hevy 做成**辅助自重动作类型**（`Exercise.isAssisted`，种子里
  `ex_assisted_pullup`，schema v4 / 种子 v8，2026-09-08）：重量列填辅助重量，库里存负数，容量按体重 − 辅助算。
  自重动作的菜单里仍留着"器械标签"一项。
  `measurements/state` 反向调用 `workout/state` 的 `refreshBodyWeightSnapshots`，是唯一一处 workout ↔ measurements 双向依赖，
  想收干净可改成 `ActiveWorkoutViewModel` 监听 `latestBodyWeightProvider`。
- F-5：组计时 `RunningSet` 已按铁律 2 落库（`workout_sessions.running_set_*`，schema v4），被杀重开按时间戳重算，
  到点即振动并自动完成；振动与 250ms tick 需真机看一次。`SetField` 枚举实际定义在 `set_row.dart`。
- F-6：默认片规格含 20 kg 片，60 kg / 20 kg 杠配出的是每边一片 20；照 Strong 的 Available Plates 在弹层里加了
  "手头的片"勾选（`availablePlatesKg`，至少留一种），没有 20 片的房子勾掉它就得到 15 + 5。快捷行按铁律 4 撑到 48dp。
  设置页没加杠重行，杠重与片都只在弹层里改。二次修订（2026-09-08）：弹层按稿重排 —— 杠重一行 `SegmentedButton`，
  "手头的片"收进右上角齿轮默认折叠；入口除长按外，杠铃动作的重量框右侧常驻计算器图标。
- F-7：TrainTrace 格式在合并时补了 `duration_seconds` / `body_weight_kg` / `superset_group` 三列，Hevy 格式的
  `superset_id` / `duration_seconds` 接上真实数据；`set_index` TrainTrace 从 1 起、Hevy 从 0 起。

## 推迟项

- **D-14 Phase 6 设置项**：重量单位（lb 显示换算）、默认休息时间（现为常量 90s，
  `AppConstants.defaultRestSeconds`）、当前场馆（预填 `sessions.gym_name` 与标签前缀）、
  CSV 导出（`share_plus` 已在依赖里）。`SettingsRepository` 目前只有主题 / 语言 / 提醒几组键；备份时间戳（`lastBackupAt`）由 `BackupRepository` 自己读写。
- **D-15 建议引擎的取舍**：只看第 1 组的 RIR 与次数决定降重，后段掉次数判为疲劳（保持 +
  提示）。这是刻意的：新手后几组掉次数很常见，按"任一组 RIR 0 就降重"会一直劝退。
  V0.5 加多次训练趋势规则时再评估。
- **D-12 动作示意换真人素材**：现在是 `exercise_figure_data.dart` 里手写关键帧的火柴人
  （48 个内置动作有关键帧，起止两帧插值；种子 v9 新增的农夫行走、雪橇推两条距离类动作暂无示意图，显示占位，在 `noFigureYet` 登记）。姿态是手调的，不保证解剖学精确；V0.5 若接真人
  动图 / 视频，这份数据留作离线回退。遗留的自定义动作（入口已下线）没有示意图，显示占位。
- **D-13 器械照片不随导出走**：`exercise_equipment_notes.photo_path` 只是相对路径，JSON 备份（`features/backup/`）只带数据库行不带照片文件，重装后恢复的备注会显示 broken image 占位；
  CSV 导出（D-2）与未来同步（D-4）都要单独处理文件；相机权限 iOS 字符串已在 Info.plist。
- **D-1 iOS 构建**：无 Mac，未验证。避免 Android-only 插件。
- **D-3 lb 单位**：V0.1 只显示换算，不接受 lb 输入。
- **D-4 同步**：outbox 表、SyncService、登录。列已预留（`sync_columns.dart`）。
- **D-5 通知图标**：目前用 `@mipmap/ic_launcher`，Android 官方建议 drawable 单色图标。
  启动图标已带单色前景 `drawable/ic_launcher_monochrome`（透明底白色图形），可直接改用，
  或从 `assets/icon/adaptive_fg.svg` 另出一份 `drawable/ic_notification`；R8 `keep.xml` 里保留。
- **D-6 删除验证页**：`features/dev/` 与 `AppRoutes.dev`。训练页已落地，但验证页上的
  "预约 15 秒后通知 / 申请精确闹钟"两个按钮在 vivo 真机验证 V-1 前还有用，之后删。
- **D-10 训练页体验**：完成一组后不自动滚到下一组、不自动聚焦；默认休息时间用常量 90s
  而非设置项；键盘弹出时列表底部可能被遮住（Phase 6 打磨）。
- **D-9 字体许可署名**：两套字体都是 SIL OFL 1.1，许可文本已随 `assets/fonts/*-OFL.txt`
  打包。Phase 6 关于页加一行"字体：Noto Sans SC、IBM Plex Sans（SIL OFL 1.1）"。
- **D-16 动作要领只有中文**：`assets/seed/exercises.json` 的 `cues` /
  `commonMistakes` / `equipmentVariants` 三段是中文教练话术，没有英文版，英文界面上
  这三块仍显示中文（`name` / `nameEn` 已双语，标题不受影响）。要补就是给 50 个内置
  动作各写三段英文，属内容工作不是代码工作：加 `cuesEn` 等字段，`Exercise` 上按语言
  选字段（同 `exerciseDisplayName` 的做法）。自定义动作这三段本来就空。
- **D-17 动作库改后端配置**：自定义动作入口已在种子 v4 下线（建了删不掉的半吊子逻辑，
  且新手不该自己维护动作库）。动作库现在只由 `assets/seed/exercises.json` 决定，接服务器后
  改为后台配置下发；`ExerciseRepository.create` 留作那时的写入口。

## 已了结

- **D-2 CSV 导出**（2026-09-08）：随 F-7 落地，见上。

- **D-11 文案迁移到 ARB**（2026-09-04）：`lib/` 里的界面文案全部走 ARB，约 150 个 key。
  枚举展示名移到 presentation 层扩展（`exercise_labels.dart` / `set_type_labels.dart`），
  `Formatters` 的日期 / 时长方法与 `SuggestionEngine.evaluate` 收 `AppLocalizations` 参数，
  服务层文案由调用方经新增的 `appLocalizationsProvider` 取好传入
  （`RestNotifier.scheduleRestEnd(at, text:)`）。join 出来的动作名改成可空的
  `exerciseName` / `exerciseNameEn`，展示走 `exerciseDisplayName`。细则见 `docs/i18n.md`。
  剩下的中文只有 `dev_playground_page`（随 D-6 删）和语言自称 `'中文'`。
  内容侧的英文缺口另记 D-16。

- **D-7 中文字体**（2026-09-04）：先选 MiSans，三档 24 MB 且许可禁止改编无法子集，
  改为 Noto Sans SC 子集化（GB2312 + UI 符号，9259 字符）+ IBM Plex Sans，
  各 400 / 500 / 700 三档，`assets/fonts/` 合计约 6.6 MB。脚本 `tool/fonts/subset_fonts.mjs`。
- **D-8 主题设置**（2026-09-04）：设置页"跟随系统 / 浅色 / 深色"分段按钮与"训练中始终
  使用深色"开关（默认开），存 `app_settings`，经 `themeSettingsProvider` 读写；
  全屏训练路由包 `WorkoutDarkScope`。

- **V-3 记录速度**（2026-09-04）：验证页实测。三组中改一组次数（12→10）并全部完成
  = 6 次点击（2 次 ✓ + 1 次聚焦 + 2 位数字 + 1 次完成），不改数字则 3 次。达标。
- **Gradle 国内下载**（2026-09-04）：发行包走 `mirrors.cloud.tencent.com`，
  依赖走阿里云镜像（同 weluck）。首次 assembleDebug 7 分钟，之后增量约 1 分钟。
