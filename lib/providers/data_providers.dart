import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache_store.dart';
import '../data/poke_api_client.dart';
import '../data/pokemon_repository.dart';
import '../models/dex_entry.dart';
import '../models/pokemon.dart';

/// データ取得まわりの Provider
/// Provider にしておくと、テストで偽物に差し替えられる
final pokeApiClientProvider = Provider<PokeApiClient>((ref) => PokeApiClient());

final cacheStoreProvider = Provider<CacheStore>((ref) => CacheStore());

final pokemonRepositoryProvider = Provider<PokemonRepository>(
  (ref) => PokemonRepository(
    api: ref.watch(pokeApiClientProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);

/// 保存済みポケモンの数を画面に出すための Provider
/// ダウンロードが終わったら ref.invalidate で読み直す
final cachedIdsProvider = FutureProvider<Set<int>>(
  (ref) async => {...await ref.watch(pokemonRepositoryProvider).cachedIds()},
);

/// 図鑑番号ごとのポケモン（名前・画像 URL・タイプ）
/// family：引数（図鑑番号）ごとに別々の Provider を作る
/// autoDispose：画面から使われなくなったら捨てる（保存済みなら、また読むのは一瞬）
final pokemonProvider = FutureProvider.autoDispose.family<Pokemon, int>(
  (ref, id) => ref.watch(pokemonRepositoryProvider).getPokemon(id),
);

/// 図鑑番号ごとの、くわしいページ用のデータ
final dexEntryProvider = FutureProvider.autoDispose.family<DexEntry, int>(
  (ref, id) => ref.watch(pokemonRepositoryProvider).getDexEntry(id),
);
