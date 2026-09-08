import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/features/settings/state/barbell_weight_view_model.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    c.listen(barbellWeightProvider, (_, _) {});
    return c;
  }

  test('冷启动读到默认 20', () async {
    final c = container();
    expect(await c.read(barbellWeightProvider.future), 20);
  });

  test('选 15：内存态立刻更新，写库后新容器能读回', () async {
    final c = container();
    await c.read(barbellWeightProvider.future);

    final future = c.read(barbellWeightProvider.notifier).set(15);
    expect(c.read(barbellWeightProvider).value, 15);
    await future;

    final c2 = container();
    expect(await c2.read(barbellWeightProvider.future), 15);
  });
}
