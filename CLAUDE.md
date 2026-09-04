# CLAUDE.md

TrainTrace：个人优先、面向国内健身新手的力量训练记录 App（"中国版 Hevy + 新手工作重量助手"）。
Flutter 3.47 / Riverpod 3 / Drift 2.34 / go_router 18。Android 优先，保留 iOS。
离线优先，V0.1 无登录、无网络；数据模型已为未来服务端同步预留。

完整规划见 `docs/PLAN.md`。分层与工程约定对齐同机项目 weluck（D:\dev\app）。

---

## 铁律

只放外部约束与"违反会静默出错"的约定。能靠 analyze / 测试变红灯的不进这里。

### 1. Drift 只出现在 `data/`

`AppDatabase`、任何 Drift 生成的行类 / Companion 只允许在 `features/<domain>/data/` 与
`core/db/` 出现。presentation / state 里 import 了 `core/db/` 即越层。
Repository 对上返回 `features/<domain>/models/` 的纯 Dart 类。

原因：项目未来接服务器，UI 与 ViewModel 永远只读本地库，同步收在 data 层内部。
model 绑定 Drift 的话接 API 时要造第二套类。

### 2. 训练进行中的状态以 DB 为准，内存只是缓存

`activeWorkoutProvider` 的每次修改立即写库（输入框 debounce 300ms，"完成"即时）。
休息计时**只存 `rest_ends_at` 时间戳**，不存剩余秒数；恢复时用 `clockProvider` 重算。
违反的后果是训练中接个电话回来数据没了 —— 这是产品最不能接受的失败。

### 3. 删除一律软删除

业务表带 `updated_at` / `deleted_at` / `sync_status`。删除写 `deleted_at`，
Repository 查询默认过滤 `deleted_at IS NULL`。物理删除只有一处例外：结束训练时清理
从未填过的空组。改表结构：`schemaVersion` +1 并写步进迁移，不改已发布版本的列。

### 4. 视觉一律走 token

颜色 → `AppTheme`（`core/theme/app_theme.dart`），字号 → `AppTextSize`，
提示 → `AppTheme.showToast`。`lib/features` 与 `lib/shared` 里不写裸 `Color(0xFF...)`
和 `fontSize: <数字>`。训练页按钮不小于 `AppTheme.minTouch`（48dp）。

---

## 变更纪律

1. **目录**：feature-first。`features/<domain>/{data,models,state,presentation}/`，
   跨 feature 依赖单向（workout → exercises 可以，反之不行）。命名
   `xxx_repository.dart` / `xxx_view_model.dart` / `xxx_page.dart`。
2. **状态归属判据**：这份状态有没有第二个页面要读。有 → 手写 `Notifier` /
   `AsyncNotifier`（含 `.family`）；没有（键盘展开、RIR 折叠、Tab 选中）→ `setState`。
   不引入 `riverpod_generator` / `freezed`，项目只吸收 `drift_dev` 一套 codegen。
3. **路由参数走 URL，不用 `GoRouter.extra`**。地址经 `AppRoutes` 构造，数据由页面
   watch provider 自己取。四 Tab 是 `StatefulShellRoute.indexedStack`，全屏页进根栈带
   `parentNavigatorKey`。`/exercises/pick` 必须注册在 `/exercises/:id` 之前。
4. **时间经 `clockProvider` 取**，不直接 `DateTime.now()`。测试用 `FixedClock`。
5. **静默降级用 `swallow(e, label)`**（`core/log.dart`），不写空 `catch`。日志走 `AppLog`。
6. **有旧数据就不要显示 loading**：判 `asyncValue.value != null`（Riverpod 3 已无 `valueOrNull`）。
7. **界面文案走 ARB**（`lib/l10n/app_zh.arb` 模板 + `app_en.arb`），页面里
   `AppLocalizations.of(context).xxx`。**新增 key 必须同步两个 ARB**，走 `/add-text`；
   `flutter gen-l10n` 对缺 key 只发 warning，靠 `scripts/check_l10n.ps1` 判红绿。
   语言选择的 `selected` / `effective` 分离与"跟随系统"语义见 `docs/i18n.md`。

---

## 测试纪律

判据：这个回归是静默的还是刺眼的。纯视觉不写测试；契约与纯函数必写。
全部纯 Dart，**不写 `pumpWidget` / golden**。

| 目录 | 覆盖 |
|---|---|
| `test/data/` | 数据库契约（外键级联、唯一约束）、Repository 行为（软删除过滤、映射） |
| `test/state/` | ViewModel 状态流转（完成组 → 生成下一组、恢复、结束清理） |
| `test/suggestion/` | 建议引擎用例（用 PLAN.md 1.4 的种子数据） |
| `test/router/` | `AppRoutes` URL 契约 |
| `test/theme/` | 亮暗两套 token 的对比度契约（语义色对底色 ≥ 4.5:1） |

口令：说「别写测试」只跑门禁交付，说「带测试」就补上。默认按表走。

---

## 常用命令

```bash
flutter analyze
```
基线：No issues found。

```bash
flutter test
```
基线：全绿。

```bash
dart run build_runner build
```
改了 `core/db/` 下任何表必跑。`*.g.dart` 在 git 追踪中，需提交。

```bash
pwsh scripts/check_l10n.ps1
```
改完 ARB 必跑（内含 `flutter gen-l10n`）。基线为零：**任何 locale 漏一个 key 就 exit 1**。
生成码 `lib/l10n/app_localizations*.dart` 在 git 追踪中，需提交。

```bash
flutter run -d 10ACBQ18A8000QD
```
真机（vivo V2241A，Android 16）。休息提醒、进程被杀恢复必须在真机验证，模拟器不算。

```bash
powershell -File scripts/build_dev.ps1 -Install
```
打 dev 包装真机（debug + 只打 arm64，约 170 MB —— 大头是 JIT 的 kernel_blob，debug 去不掉）。
对外分发用 `scripts/build_release.ps1`（AOT + 按 ABI 拆包，arm64 约 26 MB）：正式签名读
`android/key.properties`，缺该文件时回退 debug 签名并在构建前警告。

## 提交约定

`type(scope): 中文描述`，正文中文。`feat` / `fix` / `docs` / `build` / `chore` / `test` / `refactor`。

收尾提交走用户级 `/commit` skill（`~/.claude/skills/commit`）：盘点、跑上面的门禁、按动机归组、
不 push。本仓库门禁与提交格式它都从这份文件读。

## docs 索引

| 文件 | 什么时候读 |
|---|---|
| `docs/PLAN.md` | 总规划：架构、schema、页面、任务表、风险 |
| `docs/architecture.md` | 目录职责与依赖用途（现状） |
| `docs/data-layer.md` | 写 Repository / model / ViewModel 时的契约细则 |
| `docs/routing.md` | 加页面、改导航 |
| `docs/ui-conventions.md` | 写 UI、找 token |
| `docs/i18n.md` | 加文案、加语言、补翻译缺口 |
| `docs/backlog.md` | 已知问题与推迟项 |
