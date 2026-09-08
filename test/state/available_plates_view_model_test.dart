import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/features/settings/data/settings_repository.dart';
import 'package:traintrace/features/settings/state/available_plates_view_model.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    c.listen(availablePlatesProvider, (_, _) {});
    return c;
  }

  test('冷启动读到全套', () async {
    final c = container();
    expect(
      await c.read(availablePlatesProvider.future),
      SettingsRepository.defaultPlatesKg,
    );
  });

  test('勾掉 20：内存态立刻少一片，写库后新容器能读回', () async {
    final c = container();
    await c.read(availablePlatesProvider.future);

    final future = c.read(availablePlatesProvider.notifier).toggle(20);
    expect(c.read(availablePlatesProvider).value, [25, 15, 10, 5, 2.5, 1.25]);
    await future;

    final c2 = container();
    expect(
      await c2.read(availablePlatesProvider.future),
      [25, 15, 10, 5, 2.5, 1.25],
    );
  });

  test('勾回 20：插回原位（从大到小），库里也同步', () async {
    final c = container();
    await c.read(availablePlatesProvider.future);
    await c.read(availablePlatesProvider.notifier).toggle(20);
    await c.read(availablePlatesProvider.notifier).toggle(20);

    expect(
      c.read(availablePlatesProvider).value,
      SettingsRepository.defaultPlatesKg,
    );
    final c2 = container();
    expect(
      await c2.read(availablePlatesProvider.future),
      SettingsRepository.defaultPlatesKg,
    );
  });

  test('最后一种勾不掉：状态不变、库里也不变', () async {
    final c = container();
    await c.read(availablePlatesProvider.future);
    final vm = c.read(availablePlatesProvider.notifier);
    for (final kg in [25, 20, 15, 10, 5, 2.5]) {
      await vm.toggle(kg.toDouble());
    }
    expect(c.read(availablePlatesProvider).value, [1.25]);

    await vm.toggle(1.25);
    expect(c.read(availablePlatesProvider).value, [1.25]);

    final c2 = container();
    expect(await c2.read(availablePlatesProvider.future), [1.25]);
  });

  test('勾回非标准规格什么都不做', () async {
    final c = container();
    await c.read(availablePlatesProvider.future);
    await c.read(availablePlatesProvider.notifier).toggle(7.5);
    expect(
      c.read(availablePlatesProvider).value,
      SettingsRepository.defaultPlatesKg,
    );
  });
}
