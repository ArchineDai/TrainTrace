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

## V0.6 候选（2026-09-08 需求整理 + UI 稿）

> **开发依据已沉淀为 `docs/PLAN-v0.6.md`**（信息架构、各页规格、查询与聚合、schema v5、任务分解、验收清单）。
> 本节保留决策过程与取舍记录，规格以那份文件为准。
>
> **定位变更**：从"新手个人用"放宽为"兼顾所有健身人群、个人优先、图表与趋势为核心"（TrainTrace 的 Trace）。
> 起因是动作库只能从模板 / 训练进、体重只能加不能看、图表只有一条 1RM 线。
> 已定：五 Tab；图表引 `fl_chart`；自建动作推迟（D-17）。建议引擎的新手线性进阶规则保留，另记 D-18 加关闭开关。
> 落地顺序 F-8 → F-9 → F-10 → F-11：先搭骨架不改表，再进图表，测量最后。
> UI 稿见 https://claude.ai/code/artifact/7944c686-0470-42f2-862b-d431f0dc8f30 ，七块画板（首页、数据三段、体重指标页、
> 动作 Tab、动作详情记录段），每块上方便签写了要动的表与查询。全部按亮色 token 画；样例数据是编的。
> 图表二稿（2026-09-09，用户嫌一稿全是橙柱太单一）：单橙不变，变化靠形态，照 Hevy / Strong / Apple 健康的做法 ——
> 概览顶部 KPI 行带 sparkline；肌群图换正 / 背人体热力图（简化几何分区，按项目六个肌群上色，横条保留在下方）；
> 柱图其余灰、只亮选中周，点选联动上方大数字；日历按当天容量分四档深浅；折线下加渐变面积。
> 橙色梯度 5 档进 `AppTheme` 作图表 token：container → FFE0C7 → FFB27A → 品牌橙 → C9560C（暗色另配）。
> 人体图定稿（2026-09-09 第四版，前三版几何剪影 / 平面几何解剖 / 暗底 3D 都被否，理由分别是像火柴人、不像真人、黑底与主题不搭）：
> **真人比例的平面解剖插画**，7.5 头身、肩腰髋收放、四肢有粗细变化，肌肉按解剖分块（胸大肌、三角肌、二头 / 三头、腹直肌四节 +
> 腹外斜肌、股四头三个头 + 股内侧肌泪滴、斜方肌菱形、冈下肌、背阔肌、竖脊肌、臀大肌、腘绳肌、腓肠肌两头），块间一道卡片色细缝。
> 着色规则：皮肤 = 墨色 10% 半透明；没练的肌肉 = 墨色 16%；练到的肌群 = 品牌橙，**alpha 按每周组数连续映射 sets / 20**（下限 0.12，
> 20 组 / 周及以上纯橙），不再分档。卡片是普通浅色卡，正背两面并排，横条列表在同一卡片下方。
> 素材来源（2026-09-09 定稿）：手画版试了四轮（几何剪影 → 平面解剖 → 暗底 3D → 多人评审精修 → 加壮），用户都觉得
> 不像 Fitbod 那种"整个人都是肌肉、每块有体积"的样子，最终改用开源肌肉解剖人体 **react-native-body-highlighter v3.2.0（MIT）**
> 的男性正 / 背面路径：全身按肌肉分块（胸、三角、二头、三头、前臂、腹直、腹斜、斜方、上背、下背、臀、股四头、内收肌、腘绳、
> 小腿、胫前），本身就是健身 App 常用的强壮体型。转换脚本 `docs/design/body_map_convert.mjs` 把它的 slug 映射到项目六个肌群
> （前臂 / 胫前 / 颈归中性肌肉，头 / 手 / 足 / 膝 / 踝归皮肤），缩到 200×420；原素材腿偏短，转换时把会阴线（原始 y≈748）
> 以下拉长 10%（`svgpath` 转绝对坐标后分段线性映射 y，正背同一基准线），并给每块肌肉叠一层 objectBoundingBox 渐变
> （左上白 45% → 右下黑 28%）做体积感，不依赖黑底。定稿 `docs/design/body_map.svg`，许可文本 `body_map_LICENSE.txt`
> 需随发布保留。契约：`<g id="front">` / `<g id="back">` 两组，形状只带 class（`skin` / `muscle <肌群>` / `muscle`（中性）/
> `shade`），fill 由渲染方按肌群注入，描边用 `vector-effect: non-scaling-stroke`；落地时放 `assets/`，Flutter 里按 class 上色，
> 渐变层用 `Shader`。

- **F-8 五 Tab 与「数据」Tab**：首页 / 模板 / 动作 / 数据 / 设置。「数据」Tab 顶部三段 概览 | 训练 | 身体，
  段选中走 query（`/history?tab=body`），设置页"体重"行和训练页自重弹层都能深链到身体段。概览段就是统计页（F-10），
  训练段是现历史列表，身体段见 F-11。路径保留 `/history`、`/history/:id` 不动，只改 Tab 文案与图标，省得动 sessionDetail 深链。
  首页"最近训练"上方加一条本周迷你条：训练次数、总容量、与上周比，点进概览段。
- **F-9 动作 Tab 与详情页分段**：非模态的动作库列表，路径 `/exercises`（`/exercises/pick` 仍须注册在 `/exercises/:id` 之前）。
  搜索 + 肌群 + 器械类型两维筛选；排序最近练过优先，其余按肌群；每行右侧显示上次日期与工作重量×次数，
  没练过显示"未练过"；一个"只看练过的"开关。与选择器共用一个列表 widget，选择器保持模态、保留 ⓘ。
  数据加一条 `HistoryRepository` 批量查询：每个动作最近一次表现，一次 SQL 出 map，不要 N 次查。
  详情页分三段 记录 | 要领 | 器械，默认段由入口决定走 `?tab=`：动作列表 / 历史详情进"记录"，选择器 ⓘ 与训练卡片「查看动作要领」进"要领"。
  记录段 = 建议卡 + PR + 趋势图（F-10）+ 纪录表（F-10）+ 最近记录；要领段 = 示意图、要领、常见错误、器械变体；
  器械段 = 场馆备注与照片。可选：`exercises.is_hidden` 列让用户收起没有的器械，需 schema +1，单独评估。
- **F-10 图表（`fl_chart`）**：区间四档 4 周 / 3 月 / 1 年 / 全部，周从周一起，只算 `set_type = working` 且
  `is_completed = 1`，与 PR 口径一致。
  概览段：顶部 KPI 行（次数 / 容量 / 时长，各带 sparkline 与上一区间比），然后四张图：① 各肌群训练量 —— 正 / 背人体热力图
  + 下方横条（一肌群一行，背后一条 10 ～ 20 组 / 周的灰色参考带，再一行点名低于参考的肌群），回答"腿有没有偷懒"；
  ② 每周训练次数、③ 每周总容量 —— 柱图其余灰只亮选中周，点选联动上方大数字；④ 本月训练日历，按当天容量分四档深浅；
  ⑤ 每周时长（后续）。
  动作详情记录段：趋势图指标切换 估算 1RM / 最大重量 / 单次容量 / 总次数 / 组数，同一张图；纪录表 1 / 3 / 5 / 8 / 10RM
  各是多少、哪天做的（Strong 的 Records）。F-3 的 `OneRmTrendSection` 迁到 fl_chart 并泛化为按指标的趋势段。
  数据：② ③ ④ 从 `getSummaries` 的单次聚合用纯 Dart 按周归并；① 需新查询 sets ⋈ workout_exercises ⋈ exercises.muscle_group
  按周分组；纪录表需按 reps 取 MAX(weight) 的新查询。周归并与纪录计算是纯函数，进 `test/history/`。
  视觉：fl_chart 的颜色 / 字号全部从 `AppTheme` / `AppTextSize` 取，不在图表配置里写裸值（铁律 4）；亮暗两套都要看。
- **F-11 身体测量**：身体段是固定 16 项指标列表：体重、体脂率、颈、肩、胸、腹、腰、臀、左右大臂、左右前臂、左右大腿、
  左右小腿。不让自定义指标。每行 名称 / 最新值 / 日期 / 迷你趋势，未记录的右侧是 44dp「+」直接进录入弹层。点进指标页：趋势图（区间同 F-10，
  体重加 7 日均线，日体重波动大，均线才看得出趋势）+ 按日列表，可补录过去日期、滑动删除、点开修改；同日多条取最后一条画图。
  表：新建 `body_measurements(id, metric, value, measured_at)` + 同步三列，schema +1；体重继续用 `body_weights`
  （训练页自重快照依赖它），UI 层合并展示。取舍是两张表模型有点重复，不迁移，避免搬手机上的真实数据。
  现有入口：设置页"体重"行改为跳身体段；训练页自重弹层保留。不做：进步照片（推迟，先解 D-13）、体脂秤同步、Health 平台。

## 推迟项

- **D-18 建议卡关闭开关**：定位放宽后，中高阶用户会觉得线性进阶建议不对。最小改法是设置页加"显示训练建议"开关，
  关掉后训练卡片与详情页都不显示建议卡。建议规则本身按 D-15 的节奏再评估。
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
- **D-16 动作要领只有中文**：`assets/seed/exercises.json` 的 `cues` /
  `commonMistakes` / `equipmentVariants` 三段是中文教练话术，没有英文版，英文界面上
  这三块仍显示中文（`name` / `nameEn` 已双语，标题不受影响）。要补就是给 50 个内置
  动作各写三段英文，属内容工作不是代码工作：加 `cuesEn` 等字段，`Exercise` 上按语言
  选字段（同 `exerciseDisplayName` 的做法）。自定义动作这三段本来就空。
- **D-17 自建动作（推迟，先看竞品）**：自定义动作入口在种子 v4 下线，当时两个理由：实现是半成品（建了删不掉），
  以及"新手不该自己维护动作库"。2026-09-08 定位放宽后第二条作废，50 个内置动作对中高阶用户不够，自建终归要回来。
  但先盘 Hevy / Strong / JEFIT / Keep 的做法（字段、与内置重名、删除规则、备份 / CSV 如何带自建行）再定，不急着做。
  已有想法：练过的只能隐藏不能删，没练过的软删；备份 / CSV 导出要带自建行。`isCustom` 列与 `ExerciseRepository.create`
  保留。动作库仍以 `assets/seed/exercises.json` 为主体，接服务器后改后台下发。

## 已了结

- **D-2 CSV 导出**（2026-09-08）：随 F-7 落地，见上。

- **D-9 字体与素材许可署名**（2026-09-09）：随 V0.6 落地。原来的说法有误 —— `assets/fonts/*-OFL.txt`
  **没有被打进包**（`fonts:` 段只带字体文件）。现在三份许可原文放 `assets/licenses/` 并声明为 asset，
  由 `core/licenses.dart` 的 `LicenseRegistry.addLicense` 注册，关于页（`/settings/about`）列出署名两行 +
  「开源许可」进 Flutter 自带的 `showLicensePage` 读全文。人体图的 MIT 一并了结。

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
