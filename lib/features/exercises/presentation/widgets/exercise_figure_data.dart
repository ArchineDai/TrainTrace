/// 动作示意动画的姿态数据。纯 Dart，不认识 Flutter，方便测试契约。
///
/// 每个动作两帧：起始姿态 [ExerciseAnimation.start] 与终止姿态 [ExerciseAnimation.end]，
/// 播放时在两帧之间往返插值。坐标系 0–100，y 向下；侧视默认面向 +x。
///
/// 手绘火柴人而不是真人视频：无版权、无包体、亮暗主题自适应；
/// 换真人素材是 V0.5 的事，这份数据届时作回退。
library;

/// 二维点。
class P {
  const P(this.x, this.y);

  final double x;
  final double y;

  P lerp(P other, double t) => P(x + (other.x - x) * t, y + (other.y - y) * t);

  @override
  String toString() => 'P($x, $y)';
}

/// 一条肢体：根关节 [a] → 中间关节 [b] → 末端关节 [c]，腿可带脚尖 [d]。
class Limb {
  const Limb(this.a, this.b, this.c, [this.d]);

  final P a;
  final P b;
  final P c;
  final P? d;

  Limb lerp(Limb o, double t) => Limb(
        a.lerp(o.a, t),
        b.lerp(o.b, t),
        c.lerp(o.c, t),
        d == null || o.d == null ? null : d!.lerp(o.d!, t),
      );
}

/// 一帧姿态。
class Pose {
  const Pose({
    required this.head,
    required this.neck,
    required this.hip,
    this.arms = const [],
    this.legs = const [],
    this.shoulderWidth = 0,
  });

  final P head;
  final P neck;
  final P hip;
  final List<Limb> arms;
  final List<Limb> legs;

  /// 正 / 背视图时肩线的半宽；侧视为 0 不画。
  final double shoulderWidth;

  Pose lerp(Pose o, double t) => Pose(
        head: head.lerp(o.head, t),
        neck: neck.lerp(o.neck, t),
        hip: hip.lerp(o.hip, t),
        arms: [for (var i = 0; i < arms.length; i++) arms[i].lerp(o.arms[i], t)],
        legs: [for (var i = 0; i < legs.length; i++) legs[i].lerp(o.legs[i], t)],
        shoulderWidth: shoulderWidth + (o.shoulderWidth - shoulderWidth) * t,
      );
}

/// 跟着关节走的器械件。
enum HeldKind {
  /// 横杆（高位下拉），水平。
  bar,

  /// 竖把手（推 / 划船类）。
  handle,

  /// 哑铃，短粗横线。
  dumbbell,

  /// 滚轴（腿屈伸 / 腿弯举），圆。
  roller,

  /// 腿举踏板，45° 斜线。
  plate,

  /// 肩垫（提踵机），在颈部上方。
  pad,
}

/// 器械件挂在哪个关节。
enum HeldAt { wrist, ankle, neck }

class Held {
  const Held(this.kind, {this.at = HeldAt.wrist, this.limb = 0});

  final HeldKind kind;
  final HeldAt at;

  /// [at] 为 wrist 时是 arms 的下标，为 ankle 时是 legs 的下标。
  final int limb;
}

/// 静止的场景件。
enum PropKind {
  /// 实心矩形：座椅、靠背、长凳。
  rect,

  /// 粗线：斜靠背、牧师凳斜垫、踏板。
  line,

  /// 地面。只用 [Prop.y]。
  floor,

  /// 从锚点 [Prop.a] 拉到某条手臂手腕的绳索。
  cable,

  /// 配重片堆：[Prop.a] 是左上角、[Prop.b] 是右下角，指示块随动作上下。
  stack,
}

class Prop {
  const Prop.rect(this.a, this.b)
      : kind = PropKind.rect,
        y = 0,
        limb = 0;

  const Prop.line(this.a, this.b)
      : kind = PropKind.line,
        y = 0,
        limb = 0;

  const Prop.floor(this.y)
      : kind = PropKind.floor,
        a = const P(0, 0),
        b = null,
        limb = 0;

  const Prop.cable(this.a, {this.limb = 0})
      : kind = PropKind.cable,
        y = 0,
        b = null;

  const Prop.stack(this.a, this.b)
      : kind = PropKind.stack,
        y = 0,
        limb = 0;

  final PropKind kind;

  /// rect / line / stack 的两端；cable 的锚点。
  final P a;
  final P? b;

  /// floor 专用：地面的 y。
  final double y;
  final int limb;
}

class ExerciseAnimation {
  const ExerciseAnimation({
    required this.start,
    required this.end,
    this.props = const [],
    this.held = const [],
    this.periodMs = 1600,
  });

  final Pose start;
  final Pose end;
  final List<Prop> props;
  final List<Held> held;

  /// 起 → 止单程时长。
  final int periodMs;

  Pose at(double t) => start.lerp(end, t);
}

// ── 首批 16 个内置动作 ───────────────────────────────────────────

const _seatedLegsRight = [Limb(P(42, 64), P(56, 64), P(56, 82), P(62, 82))];
const _floor84 = Prop.floor(84);
const _seatRight = Prop.rect(P(34, 64), P(58, 68));
const _backPadRight = Prop.rect(P(32, 36), P(36, 64));

const _frontLegsStanding = [
  Limb(P(47, 52), P(46, 71), P(45, 88), P(41, 88)),
  Limb(P(53, 52), P(54, 71), P(55, 88), P(59, 88)),
];
const _frontLegsSeated = [
  Limb(P(46, 60), P(44, 74), P(44, 88), P(40, 88)),
  Limb(P(54, 60), P(56, 74), P(56, 88), P(60, 88)),
];

/// 内置动作 id → 动画。没有条目的 id（遗留的自定义动作）页面显示占位。
/// 契约见 `test/exercises/exercise_animations_test.dart`：种子里每个动作都要有。
const Map<String, ExerciseAnimation> exerciseAnimations = {
  // 高位下拉：坐姿面右，横杆从头顶拉到锁骨。
  'ex_lat_pulldown': ExerciseAnimation(
    start: Pose(
      head: P(39, 36),
      neck: P(40, 42),
      hip: P(42, 64),
      arms: [Limb(P(40, 42), P(47, 32), P(52, 20))],
      legs: _seatedLegsRight,
    ),
    end: Pose(
      head: P(39, 36),
      neck: P(40, 42),
      hip: P(42, 64),
      arms: [Limb(P(40, 42), P(34, 50), P(46, 42))],
      legs: _seatedLegsRight,
    ),
    props: [
      _floor84,
      _seatRight,
      Prop.rect(P(48, 55), P(60, 58)),
      Prop.cable(P(52, 4)),
      Prop.stack(P(78, 18), P(88, 78)),
    ],
    held: [Held(HeldKind.bar)],
  ),

  // 坐姿划船：面左，把手从前方拉到腹部。
  'ex_seated_row': ExerciseAnimation(
    start: Pose(
      head: P(58, 34),
      neck: P(58, 40),
      hip: P(56, 64),
      arms: [Limb(P(58, 40), P(47, 44), P(36, 46))],
      legs: [Limb(P(56, 64), P(40, 58), P(30, 70), P(27, 76))],
    ),
    end: Pose(
      head: P(58, 34),
      neck: P(58, 40),
      hip: P(56, 64),
      arms: [Limb(P(58, 40), P(60, 52), P(50, 48))],
      legs: [Limb(P(56, 64), P(40, 58), P(30, 70), P(27, 76))],
    ),
    props: [
      _floor84,
      Prop.rect(P(48, 64), P(66, 68)),
      Prop.line(P(31, 60), P(26, 78)),
      Prop.cable(P(12, 46)),
      Prop.stack(P(4, 30), P(12, 78)),
    ],
    held: [Held(HeldKind.handle)],
  ),

  // 器械肩推：把手从耳侧推到头顶。
  'ex_shoulder_press': ExerciseAnimation(
    start: Pose(
      head: P(42, 34),
      neck: P(42, 40),
      hip: P(42, 64),
      arms: [Limb(P(42, 40), P(50, 46), P(52, 36))],
      legs: _seatedLegsRight,
    ),
    end: Pose(
      head: P(42, 34),
      neck: P(42, 40),
      hip: P(42, 64),
      arms: [Limb(P(42, 40), P(48, 26), P(49, 14))],
      legs: _seatedLegsRight,
    ),
    props: [_floor84, _seatRight, _backPadRight],
    held: [Held(HeldKind.handle)],
  ),

  // 哑铃侧平举：正视，双臂从身侧抬到水平。
  'ex_lateral_raise': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(40, 40), P(40, 52)),
        Limb(P(58, 26), P(60, 40), P(60, 52)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(31, 28), P(20, 26)),
        Limb(P(58, 26), P(69, 28), P(80, 26)),
      ],
      legs: _frontLegsStanding,
    ),
    props: [Prop.floor(90)],
    held: [
      Held(HeldKind.dumbbell, limb: 0),
      Held(HeldKind.dumbbell, limb: 1),
    ],
  ),

  // 反向蝴蝶机：背视，双臂从前方打开到两侧。
  'ex_reverse_pec_deck': ExerciseAnimation(
    start: Pose(
      head: P(50, 22),
      neck: P(50, 30),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 30), P(39, 35), P(44, 33)),
        Limb(P(58, 30), P(61, 35), P(56, 33)),
      ],
      legs: _frontLegsSeated,
    ),
    end: Pose(
      head: P(50, 22),
      neck: P(50, 30),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 30), P(30, 32), P(18, 32)),
        Limb(P(58, 30), P(70, 32), P(82, 32)),
      ],
      legs: _frontLegsSeated,
    ),
    props: [
      Prop.floor(90),
      Prop.rect(P(44, 28), P(56, 60)),
      Prop.rect(P(40, 60), P(60, 64)),
    ],
    held: [
      Held(HeldKind.handle, limb: 0),
      Held(HeldKind.handle, limb: 1),
    ],
  ),

  // 蝴蝶机夹胸：正视，双臂从两侧夹到胸前。
  'ex_pec_deck': ExerciseAnimation(
    start: Pose(
      head: P(50, 22),
      neck: P(50, 30),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 30), P(30, 32), P(24, 24)),
        Limb(P(58, 30), P(70, 32), P(76, 24)),
      ],
      legs: _frontLegsSeated,
    ),
    end: Pose(
      head: P(50, 22),
      neck: P(50, 30),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 30), P(40, 40), P(47, 32)),
        Limb(P(58, 30), P(60, 40), P(53, 32)),
      ],
      legs: _frontLegsSeated,
    ),
    props: [
      Prop.floor(90),
      Prop.rect(P(44, 28), P(56, 60)),
      Prop.rect(P(40, 60), P(60, 64)),
    ],
    held: [
      Held(HeldKind.handle, limb: 0),
      Held(HeldKind.handle, limb: 1),
    ],
  ),

  // 水平胸推：把手从胸前推到前方。
  'ex_chest_press': ExerciseAnimation(
    start: Pose(
      head: P(42, 34),
      neck: P(42, 40),
      hip: P(42, 64),
      arms: [Limb(P(42, 40), P(36, 50), P(50, 44))],
      legs: _seatedLegsRight,
    ),
    end: Pose(
      head: P(42, 34),
      neck: P(42, 40),
      hip: P(42, 64),
      arms: [Limb(P(42, 40), P(56, 44), P(68, 44))],
      legs: _seatedLegsRight,
    ),
    props: [_floor84, _seatRight, _backPadRight],
    held: [Held(HeldKind.handle)],
  ),

  // 上斜胸推：躯干后仰，向上前方推。
  'ex_incline_chest_press': ExerciseAnimation(
    start: Pose(
      head: P(34, 38),
      neck: P(36, 44),
      hip: P(44, 64),
      arms: [Limb(P(36, 44), P(32, 54), P(46, 46))],
      legs: [Limb(P(44, 64), P(58, 64), P(58, 82), P(64, 82))],
    ),
    end: Pose(
      head: P(34, 38),
      neck: P(36, 44),
      hip: P(44, 64),
      arms: [Limb(P(36, 44), P(50, 38), P(62, 30))],
      legs: [Limb(P(44, 64), P(58, 64), P(58, 82), P(64, 82))],
    ),
    props: [
      _floor84,
      Prop.rect(P(36, 64), P(60, 68)),
      Prop.line(P(30, 40), P(40, 66)),
    ],
    held: [Held(HeldKind.handle)],
  ),

  // 哑铃弯举：站姿，肘固定，前臂从垂直弯到肩前。
  'ex_dumbbell_curl': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(52, 40), P(53, 52))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(52, 40), P(60, 30))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.dumbbell)],
  ),

  // 二头弯举机：上臂贴牧师斜垫，前臂沿垫弯起。
  'ex_machine_curl': ExerciseAnimation(
    start: Pose(
      head: P(40, 34),
      neck: P(40, 40),
      hip: P(38, 64),
      arms: [Limb(P(40, 40), P(56, 50), P(66, 58))],
      legs: [Limb(P(38, 64), P(52, 64), P(52, 82), P(58, 82))],
    ),
    end: Pose(
      head: P(40, 34),
      neck: P(40, 40),
      hip: P(38, 64),
      arms: [Limb(P(40, 40), P(56, 50), P(50, 41))],
      legs: [Limb(P(38, 64), P(52, 64), P(52, 82), P(58, 82))],
    ),
    props: [
      _floor84,
      Prop.rect(P(30, 64), P(50, 68)),
      Prop.line(P(46, 43), P(62, 53)),
      Prop.stack(P(80, 30), P(90, 78)),
    ],
    held: [Held(HeldKind.handle)],
  ),

  // 腿举：45° 后仰，双腿把踏板向上前方推开。
  'ex_leg_press': ExerciseAnimation(
    start: Pose(
      head: P(21, 38),
      neck: P(24, 44),
      hip: P(38, 64),
      arms: [Limb(P(24, 44), P(30, 54), P(36, 60))],
      legs: [Limb(P(38, 64), P(42, 47), P(52, 50))],
    ),
    end: Pose(
      head: P(21, 38),
      neck: P(24, 44),
      hip: P(38, 64),
      arms: [Limb(P(24, 44), P(30, 54), P(36, 60))],
      legs: [Limb(P(38, 64), P(50, 50), P(62, 40))],
    ),
    props: [
      Prop.floor(88),
      Prop.line(P(18, 36), P(34, 68)),
      Prop.rect(P(34, 66), P(48, 70)),
      Prop.rect(P(38, 70), P(43, 88)),
    ],
    held: [Held(HeldKind.plate, at: HeldAt.ankle)],
  ),

  // 腿屈伸：坐姿，小腿从垂直抬到水平。
  'ex_leg_extension': ExerciseAnimation(
    start: Pose(
      head: P(42, 30),
      neck: P(42, 36),
      hip: P(42, 60),
      arms: [Limb(P(42, 36), P(48, 46), P(50, 56))],
      legs: [Limb(P(42, 60), P(58, 60), P(58, 76), P(64, 77))],
    ),
    end: Pose(
      head: P(42, 30),
      neck: P(42, 36),
      hip: P(42, 60),
      arms: [Limb(P(42, 36), P(48, 46), P(50, 56))],
      legs: [Limb(P(42, 60), P(58, 60), P(74, 58), P(79, 54))],
    ),
    props: [
      _floor84,
      Prop.rect(P(34, 60), P(58, 64)),
      Prop.rect(P(32, 34), P(36, 60)),
      Prop.stack(P(84, 30), P(94, 78)),
    ],
    held: [Held(HeldKind.roller, at: HeldAt.ankle)],
  ),

  // 腿弯举：俯卧，小腿从伸直向臀部弯起。
  'ex_leg_curl': ExerciseAnimation(
    start: Pose(
      head: P(15, 46),
      neck: P(21, 48),
      hip: P(46, 48),
      arms: [Limb(P(22, 48), P(20, 58), P(14, 62))],
      legs: [Limb(P(46, 48), P(62, 48), P(78, 50))],
    ),
    end: Pose(
      head: P(15, 46),
      neck: P(21, 48),
      hip: P(46, 48),
      arms: [Limb(P(22, 48), P(20, 58), P(14, 62))],
      legs: [Limb(P(46, 48), P(62, 48), P(58, 33))],
    ),
    props: [
      Prop.floor(88),
      Prop.rect(P(6, 50), P(66, 56)),
      Prop.rect(P(20, 56), P(24, 88)),
      Prop.rect(P(56, 56), P(60, 88)),
    ],
    held: [Held(HeldKind.roller, at: HeldAt.ankle)],
  ),

  // 提踵：前脚掌踩块，整个人随脚跟抬起。
  'ex_calf_raise': ExerciseAnimation(
    start: Pose(
      head: P(50, 20),
      neck: P(50, 28),
      hip: P(50, 54),
      arms: [Limb(P(50, 28), P(55, 36), P(58, 28))],
      legs: [Limb(P(50, 54), P(50, 72), P(51, 86), P(60, 84))],
    ),
    end: Pose(
      head: P(50, 15),
      neck: P(50, 23),
      hip: P(50, 49),
      arms: [Limb(P(50, 23), P(55, 31), P(58, 23))],
      legs: [Limb(P(50, 49), P(50, 67), P(51, 80), P(60, 84))],
    ),
    props: [
      Prop.floor(90),
      Prop.rect(P(54, 84), P(68, 90)),
      Prop.rect(P(60, 6), P(63, 40)),
    ],
    held: [Held(HeldKind.pad, at: HeldAt.neck)],
  ),

  // 卷腹：仰卧，肩胛卷离地面。
  'ex_crunch': ExerciseAnimation(
    start: Pose(
      head: P(24, 71),
      neck: P(30, 74),
      hip: P(52, 76),
      arms: [Limb(P(30, 74), P(38, 68), P(34, 64))],
      legs: [Limb(P(52, 76), P(60, 60), P(70, 76), P(76, 76))],
    ),
    end: Pose(
      head: P(32, 54),
      neck: P(36, 60),
      hip: P(52, 76),
      arms: [Limb(P(36, 60), P(44, 58), P(40, 52))],
      legs: [Limb(P(52, 76), P(60, 60), P(70, 76), P(76, 76))],
    ),
    props: [Prop.floor(80)],
    periodMs: 1400,
  ),

  // 平板支撑：静态，只有轻微呼吸起伏。
  'ex_plank': ExerciseAnimation(
    start: Pose(
      head: P(12, 58),
      neck: P(20, 60),
      hip: P(48, 66),
      arms: [Limb(P(20, 60), P(20, 74), P(8, 76))],
      legs: [Limb(P(48, 66), P(64, 70), P(78, 74), P(80, 78))],
    ),
    end: Pose(
      head: P(12, 57),
      neck: P(20, 59),
      hip: P(48, 65),
      arms: [Limb(P(20, 59), P(20, 74), P(8, 76))],
      legs: [Limb(P(48, 65), P(64, 69), P(78, 74), P(80, 78))],
    ),
    props: [Prop.floor(78)],
    periodMs: 2200,
  ),

  // ── 种子 v4 增补的 32 个 ─────────────────────────────────────
  //
  // 侧视里杠铃只看得到端面的片，用 dumbbell（短粗线）画；正视的杠铃用 bar，
  // 两只手腕各挂一段刚好接成一整根。

  // 引体向上：正视，悬垂拉到下巴过杠。
  'ex_pullup': ExerciseAnimation(
    start: Pose(
      head: P(50, 24),
      neck: P(50, 32),
      hip: P(50, 58),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 32), P(41, 21), P(40, 10)),
        Limb(P(58, 32), P(59, 21), P(60, 10)),
      ],
      legs: [
        Limb(P(47, 58), P(46, 74), P(45, 90), P(41, 90)),
        Limb(P(53, 58), P(54, 74), P(55, 90), P(59, 90)),
      ],
    ),
    end: Pose(
      head: P(50, 6),
      neck: P(50, 14),
      hip: P(50, 40),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 14), P(36, 24), P(40, 10)),
        Limb(P(58, 14), P(64, 24), P(60, 10)),
      ],
      legs: [
        Limb(P(47, 40), P(46, 56), P(45, 72), P(41, 72)),
        Limb(P(53, 40), P(54, 56), P(55, 72), P(59, 72)),
      ],
    ),
    props: [
      Prop.line(P(24, 10), P(24, 94)),
      Prop.line(P(76, 10), P(76, 94)),
      Prop.line(P(24, 10), P(76, 10)),
    ],
    periodMs: 1800,
  ),

  // 辅助引体向上：正视，跪姿抓把手，配重堆在右侧。
  'ex_assisted_pullup': ExerciseAnimation(
    start: Pose(
      head: P(50, 26),
      neck: P(50, 34),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 34), P(41, 23), P(40, 12)),
        Limb(P(58, 34), P(59, 23), P(60, 12)),
      ],
      legs: [
        Limb(P(47, 60), P(46, 76), P(44, 80)),
        Limb(P(53, 60), P(54, 76), P(56, 80)),
      ],
    ),
    end: Pose(
      head: P(50, 12),
      neck: P(50, 20),
      hip: P(50, 46),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 20), P(36, 28), P(40, 12)),
        Limb(P(58, 20), P(64, 28), P(60, 12)),
      ],
      legs: [
        Limb(P(47, 46), P(46, 62), P(44, 66)),
        Limb(P(53, 46), P(54, 62), P(56, 66)),
      ],
    ),
    props: [
      Prop.floor(90),
      Prop.line(P(30, 8), P(70, 8)),
      Prop.line(P(30, 8), P(30, 90)),
      Prop.line(P(70, 8), P(70, 90)),
      Prop.stack(P(80, 20), P(90, 78)),
    ],
    held: [
      Held(HeldKind.handle, limb: 0),
      Held(HeldKind.handle, limb: 1),
    ],
    periodMs: 1800,
  ),

  // 杠铃划船：面右俯身 45°，杠从垂下拉到腹部。
  'ex_barbell_row': ExerciseAnimation(
    start: Pose(
      head: P(64, 40),
      neck: P(60, 44),
      hip: P(40, 58),
      arms: [Limb(P(60, 44), P(60, 56), P(58, 68))],
      legs: [Limb(P(40, 58), P(44, 74), P(46, 90), P(52, 90))],
    ),
    end: Pose(
      head: P(64, 40),
      neck: P(60, 44),
      hip: P(40, 58),
      arms: [Limb(P(60, 44), P(54, 56), P(48, 53))],
      legs: [Limb(P(40, 58), P(44, 74), P(46, 90), P(52, 90))],
    ),
    props: [Prop.floor(92)],
    held: [Held(HeldKind.dumbbell)],
  ),

  // 单臂哑铃划船：面右，一手扶凳，另一手把哑铃拉到髋侧。
  'ex_dumbbell_row': ExerciseAnimation(
    start: Pose(
      head: P(66, 40),
      neck: P(62, 42),
      hip: P(40, 46),
      arms: [
        Limb(P(62, 42), P(70, 52), P(74, 60)),
        Limb(P(62, 42), P(60, 56), P(58, 70)),
      ],
      legs: [Limb(P(40, 46), P(44, 66), P(46, 90), P(52, 90))],
    ),
    end: Pose(
      head: P(66, 40),
      neck: P(62, 42),
      hip: P(40, 46),
      arms: [
        Limb(P(62, 42), P(70, 52), P(74, 60)),
        Limb(P(62, 42), P(56, 52), P(55, 47)),
      ],
      legs: [Limb(P(40, 46), P(44, 66), P(46, 90), P(52, 90))],
    ),
    props: [
      Prop.floor(92),
      Prop.rect(P(64, 60), P(90, 64)),
      Prop.rect(P(84, 64), P(87, 92)),
    ],
    held: [Held(HeldKind.dumbbell, limb: 1)],
  ),

  // 硬拉：面右，从屈髋屈膝握杠到站直。
  'ex_deadlift': ExerciseAnimation(
    start: Pose(
      head: P(60, 38),
      neck: P(56, 42),
      hip: P(34, 56),
      arms: [Limb(P(56, 42), P(55, 60), P(54, 78))],
      legs: [Limb(P(34, 56), P(48, 62), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 54),
      arms: [Limb(P(50, 26), P(51, 42), P(52, 58))],
      legs: [Limb(P(50, 54), P(51, 71), P(50, 88), P(56, 88))],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.dumbbell)],
    periodMs: 1800,
  ),

  // 山羊挺身：面右趴在 45° 架上，上身从下垂抬到与腿成直线。
  'ex_back_extension': ExerciseAnimation(
    start: Pose(
      head: P(62, 72),
      neck: P(60, 66),
      hip: P(50, 50),
      arms: [Limb(P(60, 66), P(54, 70), P(58, 74))],
      legs: [Limb(P(50, 50), P(40, 62), P(32, 74), P(30, 78))],
    ),
    end: Pose(
      head: P(66, 29),
      neck: P(63, 33),
      hip: P(50, 50),
      arms: [Limb(P(63, 33), P(60, 40), P(66, 40))],
      legs: [Limb(P(50, 50), P(40, 62), P(32, 74), P(30, 78))],
    ),
    props: [
      Prop.floor(90),
      Prop.line(P(28, 80), P(52, 52)),
      Prop.rect(P(26, 78), P(34, 82)),
      Prop.rect(P(40, 66), P(43, 90)),
    ],
  ),

  // 哑铃耸肩：正视，肩线带着哑铃直上直下。
  'ex_shrug': ExerciseAnimation(
    start: Pose(
      head: P(50, 17),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(41, 40), P(40, 54)),
        Limb(P(58, 26), P(59, 40), P(60, 54)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 17),
      neck: P(50, 22),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 22), P(41, 36), P(40, 50)),
        Limb(P(58, 22), P(59, 36), P(60, 50)),
      ],
      legs: _frontLegsStanding,
    ),
    props: [Prop.floor(90)],
    held: [
      Held(HeldKind.dumbbell, limb: 0),
      Held(HeldKind.dumbbell, limb: 1),
    ],
    periodMs: 1200,
  ),

  // 哑铃肩推：正视坐姿，哑铃从耳侧推到头顶。
  'ex_dumbbell_shoulder_press': ExerciseAnimation(
    start: Pose(
      head: P(50, 20),
      neck: P(50, 28),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 28), P(33, 29), P(33, 17)),
        Limb(P(58, 28), P(67, 29), P(67, 17)),
      ],
      legs: _frontLegsSeated,
    ),
    end: Pose(
      head: P(50, 20),
      neck: P(50, 28),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 28), P(43, 16), P(46, 5)),
        Limb(P(58, 28), P(57, 16), P(54, 5)),
      ],
      legs: _frontLegsSeated,
    ),
    props: [
      Prop.floor(90),
      Prop.rect(P(44, 28), P(56, 60)),
      Prop.rect(P(40, 60), P(60, 64)),
    ],
    held: [
      Held(HeldKind.dumbbell, limb: 0),
      Held(HeldKind.dumbbell, limb: 1),
    ],
  ),

  // 杠铃站姿推举：正视，杠从锁骨推到头顶。
  'ex_overhead_press': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(38, 36), P(40, 27)),
        Limb(P(58, 26), P(62, 36), P(60, 27)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(44, 14), P(46, 3)),
        Limb(P(58, 26), P(56, 14), P(54, 3)),
      ],
      legs: _frontLegsStanding,
    ),
    props: [Prop.floor(90)],
    held: [
      Held(HeldKind.bar, limb: 0),
      Held(HeldKind.bar, limb: 1),
    ],
  ),

  // 哑铃前平举：面右站姿，手臂从大腿前抬到水平。
  'ex_front_raise': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(52, 40), P(54, 52))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(63, 26), P(76, 26))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.dumbbell)],
  ),

  // 绳索面拉：面左站姿，绳索从前方拉到耳侧、肘向后。
  'ex_face_pull': ExerciseAnimation(
    start: Pose(
      head: P(56, 20),
      neck: P(56, 30),
      hip: P(54, 56),
      arms: [Limb(P(56, 30), P(44, 30), P(32, 30))],
      legs: [Limb(P(54, 56), P(52, 72), P(50, 90), P(46, 90))],
    ),
    end: Pose(
      head: P(56, 20),
      neck: P(56, 30),
      hip: P(54, 56),
      arms: [Limb(P(56, 30), P(66, 32), P(60, 26))],
      legs: [Limb(P(54, 56), P(52, 72), P(50, 90), P(46, 90))],
    ),
    props: [
      Prop.floor(92),
      Prop.cable(P(10, 28)),
      Prop.stack(P(2, 18), P(10, 78)),
    ],
    held: [Held(HeldKind.handle)],
  ),

  // 杠铃卧推：侧视仰卧，杠从胸上推到手臂伸直；头侧有架子立柱。
  'ex_barbell_bench_press': ExerciseAnimation(
    start: Pose(
      head: P(18, 62),
      neck: P(25, 63),
      hip: P(52, 64),
      arms: [Limb(P(30, 63), P(37, 60), P(33, 55))],
      legs: [Limb(P(52, 64), P(64, 70), P(68, 90), P(74, 90))],
    ),
    end: Pose(
      head: P(18, 62),
      neck: P(25, 63),
      hip: P(52, 64),
      arms: [Limb(P(30, 63), P(31, 48), P(32, 34))],
      legs: [Limb(P(52, 64), P(64, 70), P(68, 90), P(74, 90))],
    ),
    props: [
      Prop.floor(92),
      Prop.rect(P(12, 26), P(15, 66)),
      Prop.rect(P(14, 66), P(66, 70)),
      Prop.rect(P(20, 70), P(24, 92)),
      Prop.rect(P(56, 70), P(60, 92)),
    ],
    held: [Held(HeldKind.dumbbell)],
  ),

  // 哑铃卧推：同卧推姿态，两只哑铃各自推起。
  'ex_dumbbell_bench_press': ExerciseAnimation(
    start: Pose(
      head: P(18, 62),
      neck: P(25, 63),
      hip: P(52, 64),
      arms: [
        Limb(P(30, 63), P(38, 61), P(30, 55)),
        Limb(P(30, 63), P(36, 58), P(36, 54)),
      ],
      legs: [Limb(P(52, 64), P(64, 70), P(68, 90), P(74, 90))],
    ),
    end: Pose(
      head: P(18, 62),
      neck: P(25, 63),
      hip: P(52, 64),
      arms: [
        Limb(P(30, 63), P(30, 48), P(31, 34)),
        Limb(P(30, 63), P(34, 48), P(35, 34)),
      ],
      legs: [Limb(P(52, 64), P(64, 70), P(68, 90), P(74, 90))],
    ),
    props: [
      Prop.floor(92),
      Prop.rect(P(14, 66), P(66, 70)),
      Prop.rect(P(20, 70), P(24, 92)),
      Prop.rect(P(56, 70), P(60, 92)),
    ],
    held: [
      Held(HeldKind.dumbbell, limb: 0),
      Held(HeldKind.dumbbell, limb: 1),
    ],
  ),

  // 上斜哑铃卧推：躯干后仰靠斜凳，哑铃向上前方推。
  'ex_incline_dumbbell_press': ExerciseAnimation(
    start: Pose(
      head: P(34, 38),
      neck: P(36, 44),
      hip: P(44, 64),
      arms: [
        Limb(P(36, 44), P(32, 54), P(44, 47)),
        Limb(P(36, 44), P(36, 56), P(48, 50)),
      ],
      legs: [Limb(P(44, 64), P(58, 64), P(58, 82), P(64, 82))],
    ),
    end: Pose(
      head: P(34, 38),
      neck: P(36, 44),
      hip: P(44, 64),
      arms: [
        Limb(P(36, 44), P(49, 37), P(60, 29)),
        Limb(P(36, 44), P(51, 40), P(63, 33)),
      ],
      legs: [Limb(P(44, 64), P(58, 64), P(58, 82), P(64, 82))],
    ),
    props: [
      _floor84,
      Prop.rect(P(36, 64), P(60, 68)),
      Prop.line(P(30, 40), P(40, 66)),
    ],
    held: [
      Held(HeldKind.dumbbell, limb: 0),
      Held(HeldKind.dumbbell, limb: 1),
    ],
  ),

  // 绳索夹胸：正视站在两侧高位滑轮中间，双手从两侧合到胸前。
  'ex_cable_fly': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(30, 26), P(20, 22)),
        Limb(P(58, 26), P(70, 26), P(80, 22)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(36, 38), P(48, 36)),
        Limb(P(58, 26), P(64, 38), P(52, 36)),
      ],
      legs: _frontLegsStanding,
    ),
    props: [
      Prop.floor(90),
      Prop.stack(P(1, 26), P(8, 78)),
      Prop.stack(P(92, 26), P(99, 78)),
      Prop.cable(P(4, 18)),
      Prop.cable(P(96, 18), limb: 1),
    ],
    held: [
      Held(HeldKind.handle, limb: 0),
      Held(HeldKind.handle, limb: 1),
    ],
  ),

  // 俯卧撑：侧视面左，身体一条直线上下。
  'ex_pushup': ExerciseAnimation(
    start: Pose(
      head: P(20, 52),
      neck: P(28, 56),
      hip: P(54, 64),
      arms: [Limb(P(28, 56), P(29, 70), P(30, 84))],
      legs: [Limb(P(54, 64), P(70, 72), P(84, 80), P(88, 84))],
    ),
    end: Pose(
      head: P(18, 70),
      neck: P(28, 72),
      hip: P(54, 76),
      arms: [Limb(P(28, 72), P(40, 78), P(30, 84))],
      legs: [Limb(P(54, 76), P(70, 79), P(84, 81), P(88, 84))],
    ),
    props: [_floor84],
  ),

  // 双杠臂屈伸：正视撑在双杠上，屈肘下放再撑起。
  'ex_dip': ExerciseAnimation(
    start: Pose(
      head: P(50, 14),
      neck: P(50, 22),
      hip: P(50, 50),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 22), P(39, 31), P(35, 40)),
        Limb(P(58, 22), P(61, 31), P(65, 40)),
      ],
      legs: [
        Limb(P(47, 50), P(46, 66), P(44, 78)),
        Limb(P(53, 50), P(54, 66), P(56, 78)),
      ],
    ),
    end: Pose(
      head: P(50, 28),
      neck: P(50, 36),
      hip: P(50, 64),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 36), P(31, 43), P(35, 40)),
        Limb(P(58, 36), P(69, 43), P(65, 40)),
      ],
      legs: [
        Limb(P(47, 64), P(45, 78), P(41, 88)),
        Limb(P(53, 64), P(55, 78), P(59, 88)),
      ],
    ),
    props: [
      Prop.rect(P(33, 40), P(36, 96)),
      Prop.rect(P(64, 40), P(67, 96)),
      Prop.line(P(30, 40), P(40, 40)),
      Prop.line(P(60, 40), P(70, 40)),
    ],
    periodMs: 1800,
  ),

  // 杠铃弯举：正视，肘固定，杠从大腿前举到肩前。
  'ex_barbell_curl': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(42, 40), P(43, 54)),
        Limb(P(58, 26), P(58, 40), P(57, 54)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(42, 40), P(44, 28)),
        Limb(P(58, 26), P(58, 40), P(56, 28)),
      ],
      legs: _frontLegsStanding,
    ),
    props: [Prop.floor(90)],
    held: [
      Held(HeldKind.bar, limb: 0),
      Held(HeldKind.bar, limb: 1),
    ],
  ),

  // 锤式弯举：正视，掌心朝内，哑铃竖着（用 handle 画）弯到肩前。
  'ex_hammer_curl': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(41, 40), P(40, 54)),
        Limb(P(58, 26), P(59, 40), P(60, 54)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(41, 40), P(43, 28)),
        Limb(P(58, 26), P(59, 40), P(57, 28)),
      ],
      legs: _frontLegsStanding,
    ),
    props: [Prop.floor(90)],
    held: [
      Held(HeldKind.handle, limb: 0),
      Held(HeldKind.handle, limb: 1),
    ],
  ),

  // 绳索下压：面左站在高位滑轮前，肘固定，前臂从水平压到伸直。
  'ex_triceps_pushdown': ExerciseAnimation(
    start: Pose(
      head: P(52, 22),
      neck: P(50, 30),
      hip: P(54, 56),
      arms: [Limb(P(50, 30), P(48, 44), P(36, 42))],
      legs: [Limb(P(54, 56), P(52, 72), P(50, 90), P(46, 90))],
    ),
    end: Pose(
      head: P(52, 22),
      neck: P(50, 30),
      hip: P(54, 56),
      arms: [Limb(P(50, 30), P(48, 44), P(38, 58))],
      legs: [Limb(P(54, 56), P(52, 72), P(50, 90), P(46, 90))],
    ),
    props: [
      Prop.floor(92),
      Prop.cable(P(12, 6)),
      Prop.stack(P(4, 14), P(12, 78)),
    ],
    held: [Held(HeldKind.handle)],
  ),

  // 哑铃过顶臂屈伸：面右站姿，上臂贴耳，哑铃从脑后举到头顶。
  'ex_overhead_triceps_extension': ExerciseAnimation(
    start: Pose(
      head: P(50, 21),
      neck: P(50, 29),
      hip: P(50, 55),
      arms: [Limb(P(50, 29), P(57, 17), P(45, 13))],
      legs: [Limb(P(50, 55), P(51, 72), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(50, 21),
      neck: P(50, 29),
      hip: P(50, 55),
      arms: [Limb(P(50, 29), P(55, 16), P(57, 4))],
      legs: [Limb(P(50, 55), P(51, 72), P(50, 88), P(56, 88))],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.dumbbell)],
  ),

  // 杠铃深蹲：正视，杠在颈后。第三条"手臂"是退化的哑肢，只为在颈后
  // 多挂一段 bar 把两端接起来，本身长 2 画在躯干线上看不见。
  'ex_barbell_squat': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 26), P(34, 32), P(30, 24)),
        Limb(P(58, 26), P(66, 32), P(70, 24)),
        Limb(P(50, 26), P(50, 25), P(50, 24)),
      ],
      legs: _frontLegsStanding,
    ),
    end: Pose(
      head: P(50, 36),
      neck: P(50, 44),
      hip: P(50, 70),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 44), P(34, 50), P(30, 42)),
        Limb(P(58, 44), P(66, 50), P(70, 42)),
        Limb(P(50, 44), P(50, 43), P(50, 42)),
      ],
      legs: [
        Limb(P(47, 70), P(36, 76), P(45, 88), P(41, 88)),
        Limb(P(53, 70), P(64, 76), P(55, 88), P(59, 88)),
      ],
    ),
    props: [Prop.floor(90)],
    held: [
      Held(HeldKind.bar, limb: 0),
      Held(HeldKind.bar, limb: 1),
      Held(HeldKind.bar, limb: 2),
    ],
    periodMs: 1800,
  ),

  // 高脚杯深蹲：面右，哑铃竖抱胸前，屈髋屈膝蹲下。
  'ex_goblet_squat': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(56, 36), P(55, 28))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(54, 37),
      neck: P(52, 44),
      hip: P(40, 68),
      arms: [Limb(P(52, 44), P(58, 52), P(57, 44))],
      legs: [Limb(P(40, 68), P(58, 66), P(52, 88), P(58, 88))],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.handle)],
    periodMs: 1800,
  ),

  // 史密斯深蹲：面右，杠挂在颈后沿右侧立轨直上直下。
  'ex_smith_squat': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(56, 32), P(54, 24))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(51, 36),
      neck: P(50, 44),
      hip: P(44, 68),
      arms: [Limb(P(50, 44), P(56, 50), P(54, 42))],
      legs: [Limb(P(44, 68), P(60, 66), P(54, 88), P(60, 88))],
    ),
    props: [
      Prop.floor(90),
      Prop.rect(P(60, 4), P(63, 90)),
    ],
    held: [Held(HeldKind.bar, at: HeldAt.neck)],
    periodMs: 1800,
  ),

  // 罗马尼亚硬拉：面右，屁股后推、上身前倾，杠沿腿滑到膝下。
  'ex_romanian_deadlift': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(52, 42), P(53, 58))],
      legs: [Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(68, 38),
      neck: P(64, 42),
      hip: P(42, 56),
      arms: [Limb(P(64, 42), P(60, 58), P(56, 74))],
      legs: [Limb(P(42, 56), P(48, 72), P(50, 88), P(56, 88))],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.dumbbell)],
    periodMs: 1800,
  ),

  // 哑铃箭步蹲：面右，前脚迈出、后膝下沉。
  'ex_lunge': ExerciseAnimation(
    start: Pose(
      head: P(50, 18),
      neck: P(50, 26),
      hip: P(50, 52),
      arms: [Limb(P(50, 26), P(51, 40), P(52, 54))],
      legs: [
        Limb(P(50, 52), P(51, 71), P(50, 88), P(56, 88)),
        Limb(P(50, 52), P(49, 71), P(48, 88), P(54, 88)),
      ],
    ),
    end: Pose(
      head: P(50, 28),
      neck: P(50, 36),
      hip: P(50, 62),
      arms: [Limb(P(50, 36), P(51, 50), P(52, 64))],
      legs: [
        Limb(P(50, 62), P(66, 66), P(66, 88), P(72, 88)),
        Limb(P(50, 62), P(42, 82), P(30, 86), P(34, 90)),
      ],
    ),
    props: [Prop.floor(90)],
    held: [Held(HeldKind.dumbbell)],
    periodMs: 1800,
  ),

  // 杠铃臀推：面右，上背靠凳，髋带着杠从地面顶到肩膝一线。
  'ex_hip_thrust': ExerciseAnimation(
    start: Pose(
      head: P(22, 48),
      neck: P(28, 52),
      hip: P(44, 78),
      arms: [Limb(P(28, 52), P(36, 64), P(44, 72))],
      legs: [Limb(P(44, 78), P(60, 66), P(66, 90), P(72, 90))],
    ),
    end: Pose(
      head: P(22, 48),
      neck: P(28, 52),
      hip: P(46, 58),
      arms: [Limb(P(28, 52), P(38, 58), P(46, 52))],
      legs: [Limb(P(46, 58), P(62, 64), P(66, 90), P(72, 90))],
    ),
    props: [
      Prop.floor(92),
      Prop.rect(P(6, 50), P(30, 54)),
      Prop.rect(P(10, 54), P(13, 92)),
      Prop.rect(P(24, 54), P(27, 92)),
    ],
    held: [Held(HeldKind.dumbbell)],
  ),

  // 髋外展机：正视坐姿，双腿从并拢打开到两侧。
  'ex_hip_abduction': ExerciseAnimation(
    start: Pose(
      head: P(50, 22),
      neck: P(50, 30),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 30), P(38, 44), P(36, 56)),
        Limb(P(58, 30), P(62, 44), P(64, 56)),
      ],
      legs: [
        Limb(P(48, 60), P(47, 74), P(47, 88), P(44, 88)),
        Limb(P(52, 60), P(53, 74), P(53, 88), P(56, 88)),
      ],
    ),
    end: Pose(
      head: P(50, 22),
      neck: P(50, 30),
      hip: P(50, 60),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 30), P(38, 44), P(36, 56)),
        Limb(P(58, 30), P(62, 44), P(64, 56)),
      ],
      legs: [
        Limb(P(48, 60), P(34, 72), P(34, 88), P(30, 88)),
        Limb(P(52, 60), P(66, 72), P(66, 88), P(70, 88)),
      ],
    ),
    props: [
      Prop.floor(90),
      Prop.rect(P(44, 28), P(56, 60)),
      Prop.rect(P(36, 60), P(64, 64)),
      Prop.stack(P(84, 30), P(94, 78)),
    ],
  ),

  // 悬垂举腿：面右悬垂在杠上，双腿抬到大腿水平。
  'ex_hanging_leg_raise': ExerciseAnimation(
    start: Pose(
      head: P(50, 20),
      neck: P(50, 28),
      hip: P(50, 54),
      arms: [Limb(P(50, 28), P(50, 17), P(50, 6))],
      legs: [Limb(P(50, 54), P(50, 72), P(50, 88), P(56, 88))],
    ),
    end: Pose(
      head: P(50, 20),
      neck: P(50, 28),
      hip: P(50, 54),
      arms: [Limb(P(50, 28), P(50, 17), P(50, 6))],
      legs: [Limb(P(50, 54), P(66, 56), P(66, 74), P(72, 76))],
    ),
    props: [
      Prop.line(P(30, 6), P(70, 6)),
      Prop.line(P(30, 6), P(30, 96)),
      Prop.line(P(70, 6), P(70, 96)),
    ],
    periodMs: 1800,
  ),

  // 跪姿绳索卷腹：面左跪在高位滑轮前，绳索握在头侧，用腹部把上身卷向膝盖。
  'ex_cable_crunch': ExerciseAnimation(
    start: Pose(
      head: P(52, 32),
      neck: P(52, 40),
      hip: P(56, 66),
      arms: [Limb(P(52, 40), P(44, 44), P(46, 34))],
      legs: [Limb(P(56, 66), P(58, 88), P(76, 88), P(80, 84))],
    ),
    end: Pose(
      head: P(40, 58),
      neck: P(44, 52),
      hip: P(56, 66),
      arms: [Limb(P(44, 52), P(36, 56), P(38, 48))],
      legs: [Limb(P(56, 66), P(58, 88), P(76, 88), P(80, 84))],
    ),
    props: [
      Prop.floor(90),
      Prop.cable(P(12, 6)),
      Prop.stack(P(4, 14), P(12, 78)),
    ],
    held: [Held(HeldKind.handle)],
  ),

  // 俄罗斯转体：正视坐在垫上，双手合拢从左侧摆到右侧。
  'ex_russian_twist': ExerciseAnimation(
    start: Pose(
      head: P(50, 44),
      neck: P(50, 52),
      hip: P(50, 80),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 52), P(30, 58), P(22, 50)),
        Limb(P(58, 52), P(38, 60), P(22, 50)),
      ],
      legs: [
        Limb(P(46, 80), P(43, 66), P(42, 84), P(38, 84)),
        Limb(P(54, 80), P(57, 66), P(58, 84), P(62, 84)),
      ],
    ),
    end: Pose(
      head: P(50, 44),
      neck: P(50, 52),
      hip: P(50, 80),
      shoulderWidth: 8,
      arms: [
        Limb(P(42, 52), P(62, 60), P(78, 50)),
        Limb(P(58, 52), P(70, 58), P(78, 50)),
      ],
      legs: [
        Limb(P(46, 80), P(43, 66), P(42, 84), P(38, 84)),
        Limb(P(54, 80), P(57, 66), P(58, 84), P(62, 84)),
      ],
    ),
    props: [_floor84],
    periodMs: 1200,
  ),

  // 侧平板支撑：正对镜头，肘撑地、髋抬起，静态只有轻微起伏。
  'ex_side_plank': ExerciseAnimation(
    start: Pose(
      head: P(12, 54),
      neck: P(20, 58),
      hip: P(50, 67),
      arms: [
        Limb(P(20, 58), P(18, 78), P(30, 82)),
        Limb(P(20, 58), P(20, 44), P(22, 30)),
      ],
      legs: [Limb(P(50, 67), P(68, 74), P(84, 80), P(88, 84))],
    ),
    end: Pose(
      head: P(12, 53),
      neck: P(20, 57),
      hip: P(50, 65),
      arms: [
        Limb(P(20, 57), P(18, 78), P(30, 82)),
        Limb(P(20, 57), P(20, 43), P(22, 29)),
      ],
      legs: [Limb(P(50, 65), P(68, 73), P(84, 80), P(88, 84))],
    ),
    props: [_floor84],
    periodMs: 2200,
  ),
};
