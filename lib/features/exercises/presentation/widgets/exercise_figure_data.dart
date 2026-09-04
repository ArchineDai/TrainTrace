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

// ── 16 个内置动作 ─────────────────────────────────────────────────

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

/// 内置动作 id → 动画。自定义动作没有条目，页面显示占位。
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
};
