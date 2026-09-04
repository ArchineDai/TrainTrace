import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 所有业务表的主键：客户端生成的 UUID v4。
///
/// 客户端 id 即全局 id —— 未来接服务器时服务端不再分配主键（PLAN.md 1.5）。
String newId() => _uuid.v4();
