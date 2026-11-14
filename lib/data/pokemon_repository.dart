import 'dart:io';

import '../models/dex_entry.dart';
import '../models/pokemon.dart';
import 'cache_store.dart';
import 'poke_api_client.dart';

/// ポケモンのデータと画像の窓口
/// 「端末に保存済みならそれを使い、無ければ PokéAPI から取って保存する」
class PokemonRepository {
  final PokeApiClient _api;
  final CacheStore _cache;

  // this._api と書くと、呼ぶ側は「api:」という名前で渡せる
  PokemonRepository({required this._api, required this._cache});

  // ダウンロード中のもの。同じものを同時に頼まれたら、1回のダウンロードを使い回す
  final _pendingPokemon = <int, Future<Pokemon>>{};
  final _pendingImages = <String, Future<File>>{};
  final _pendingDex = <int, Future<DexEntry>>{};

  /// ポケモン1匹分のデータ（保存済み → なければ API）
  Future<Pokemon> getPokemon(int id) {
    return _pendingPokemon[id] ??= () async {
      try {
        final cached = await _cache.readPokemon(id);
        if (cached != null) return cached;

        final pokemon = await _api.fetchPokemon(id);
        await _cache.writePokemon(pokemon);
        return pokemon;
      } finally {
        _pendingPokemon.remove(id); // 終わったら（失敗しても）一覧から外す
      }
    }();
  }

  /// 図鑑のくわしいページ用のデータ（保存済み → なければ API）
  Future<DexEntry> getDexEntry(int id) {
    return _pendingDex[id] ??= () async {
      try {
        final cached = await _cache.readDexEntry(id);
        if (cached != null) return cached;

        final entry = await _api.fetchDexEntry(id);
        await _cache.writeDexEntry(entry);
        return entry;
      } finally {
        _pendingDex.remove(id);
      }
    }();
  }

  /// 保存済みの図鑑データだけを読む（無ければ null。ネットには取りにいかない）
  Future<DexEntry?> cachedDexEntry(int id) => _cache.readDexEntry(id);

  /// 鳴き声の音声ファイル（無いポケモンは null）。画像と同じしくみで保存する
  Future<File?> getCry(int id) async {
    final url = (await getDexEntry(id)).cryUrl;
    return url == null ? null : getImage(url);
  }

  /// 図鑑で見るためのデータ（くわしいページ・鳴き声）を、まとめて保存しておく
  Future<void> downloadDex(int id) async {
    await getDexEntry(id);
    await getCry(id);
  }

  /// 画像のファイル（保存済み → なければダウンロードして保存）
  /// 画像以外のファイル（鳴き声）にも使える
  Future<File> getImage(String url) {
    return _pendingImages[url] ??= () async {
      try {
        final cached = await _cache.readImage(url);
        if (cached != null) return cached;
        return await _cache.writeImage(url, await _api.downloadBytes(url));
      } finally {
        _pendingImages.remove(url);
      }
    }();
  }

  /// そのポケモンの画像（イラスト・ドット絵）をすべて保存しておく
  Future<void> downloadImages(Pokemon pokemon) async {
    await Future.wait(pokemon.imageUrls.map(getImage));
  }

  /// 画像がすべて保存済みか（オフラインで正解として出せるか）
  Future<bool> hasImages(Pokemon pokemon) async {
    for (final url in pokemon.imageUrls) {
      if (await _cache.readImage(url) == null) return false;
    }
    return true;
  }

  /// 保存済みポケモンの図鑑番号
  Future<Set<int>> cachedIds() => _cache.cachedPokemonIds();

  /// まとめてダウンロードする（設定画面の「ダウンロード」ボタン用）
  /// - 同時に4匹ずつにして、PokéAPI に負担をかけすぎないようにする
  /// - isCancelled が true を返したら、そこでやめる
  /// - 戻り値は、失敗した数
  Future<int> downloadAll(
    List<int> ids, {
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    var next = 0; // 次に取る番号の位置
    var done = 0;
    var failed = 0;

    // 4つの「係」が、順番に次の番号を取っていく
    Future<void> worker() async {
      while (next < ids.length && !isCancelled()) {
        final id = ids[next++];
        try {
          await downloadImages(await getPokemon(id));
          await downloadDex(id); // 図鑑もオフラインで見られるように
        } catch (_) {
          failed++;
        }
        onProgress(++done, ids.length);
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    return failed;
  }
}
