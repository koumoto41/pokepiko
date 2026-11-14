import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collection_store.dart';

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
