import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache_store.dart';
import '../data/poke_api_client.dart';
import '../data/pokemon_repository.dart';

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
