import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collection_store.dart';
import 'data_providers.dart';

final collectionStoreProvider = Provider<CollectionStore>(
  (ref) => CollectionStore(),
);

/// 図鑑で「みつけた」ポケモンの図鑑番号
final collectionProvider =
    AsyncNotifierProvider<CollectionController, Set<int>>(
      CollectionController.new,
    );

class CollectionController extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() => ref.watch(collectionStoreProvider).read();

  /// みつけたポケモンを記録する。はじめてみつけたら true
  Future<bool> add(int id) async {
    final found = await future; // 読み込みが終わるのを待つ
    if (found.contains(id)) return false;

    final next = {...found, id};
    state = AsyncData(next);
    await ref.read(collectionStoreProvider).write(next);
    return true;
  }
}

/// 進化の仲間を1つの文字にする（例：[3, 1, 2] → "1,2,3"）。お知らせ済みの記録に使う
String familyKey(List<int> members) => (members.toList()..sort()).join(',');

/// 進化の仲間（2匹以上）が、全員みつかった仲間の一覧
/// 進化の情報は保存済みのものだけを使う（オフラインでも図鑑を開くのが遅くならないように）
/// autoDispose：図鑑を開くたびに調べ直す（あとから保存された進化の情報も使えるように）
final completedFamiliesProvider = FutureProvider.autoDispose<List<List<int>>>((
  ref,
) async {
  final found = await ref.watch(collectionProvider.future);
  final repo = ref.watch(pokemonRepositoryProvider);

  final families = <String, List<int>>{};
  for (final id in found.toList()..sort()) {
    if (families.values.any((f) => f.contains(id))) continue; // もう調べた仲間
    final entry = await repo.cachedDexEntry(id);
    if (entry == null) continue;
    final members = [for (final stage in entry.evolution) ...stage];
    if (members.length > 1 && members.every(found.contains)) {
      families[familyKey(members)] = members;
    }
  }
  return families.values.toList();
});

/// 新しくそろった（まだお知らせしていない）仲間を返し、お知らせ済みとして記録する
Future<List<List<int>>> takeNewlyCompletedFamilies(WidgetRef ref) async {
  final store = ref.read(collectionStoreProvider);
  final completed = await ref.read(completedFamiliesProvider.future);
  final announced = await store.readAnnouncedFamilies();
  final fresh = [
    for (final f in completed)
      if (!announced.contains(familyKey(f))) f,
  ];
  if (fresh.isNotEmpty) {
    await store.writeAnnouncedFamilies({
      ...announced,
      for (final f in fresh) familyKey(f),
    });
  }
  return fresh;
}
