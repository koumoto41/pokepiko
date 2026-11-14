import 'dart:async';
import 'dart:io';

import 'package:pokepiko/data/pokemon_repository.dart';
import 'package:pokepiko/models/dex_entry.dart';
import 'package:pokepiko/models/poke_type.dart';
import 'package:pokepiko/models/pokemon.dart';

/// テスト用の偽の窓口（通信もファイルも使わず、メモリの中だけで動く）
/// online = false にすると「ネットにつながらない」状態になる
class FakePokemonRepository implements PokemonRepository {
  bool online;
  final Set<int> saved = {}; // 保存済みのつもりの図鑑番号
  final Set<int> savedImages = {}; // 画像まで保存済みのつもりの図鑑番号

  FakePokemonRepository({this.online = true});

  /// 番号から決まったタイプを作る（3の倍数は2タイプ持ち）
  static List<PokeType> typesOf(int id) => [
    PokeType.values[id % PokeType.values.length],
    if (id % 3 == 0) PokeType.values[(id + 5) % PokeType.values.length],
  ];

  Pokemon _make(int id) => Pokemon(
    id: id,
    name: 'P$id',
    artworkUrl: 'https://example.com/art/$id.png',
    // 7の倍数の番号は、ドット絵がないポケモンにする（新しい世代の一部と同じ）
    spriteUrl: id % 7 == 0 ? null : 'https://example.com/dot/$id.png',
    types: typesOf(id),
  );

  @override
  Future<Pokemon> getPokemon(int id) async {
    if (saved.contains(id)) return _make(id);
    if (!online) throw const SocketException('offline');
    saved.add(id);
    return _make(id);
  }

  @override
  Future<void> downloadImages(Pokemon pokemon) async {
    if (savedImages.contains(pokemon.id)) return;
    if (!online) throw const SocketException('offline');
    savedImages.add(pokemon.id);
  }

  @override
  Future<bool> hasImages(Pokemon pokemon) async =>
      savedImages.contains(pokemon.id);

  @override
  Future<Set<int>> cachedIds() async => saved;

  /// true: 画像は読み込み失敗にする（くるくるが回り続けないので pumpAndSettle が使える）
  bool imagesFail = false;

  // 画像は表示しないので、ふだんはずっと読み込み中にしておく
  @override
  Future<File> getImage(String url) => imagesFail
      ? Future.error(const FileSystemException('no image'))
      : Completer<File>().future;

  final Set<int> savedDex = {}; // 図鑑データを保存済みのつもりの図鑑番号

  /// 図鑑のテスト用：番号 n のポケモンは、n → n+1 に進化することにする
  static DexEntry dexOf(int id) => DexEntry(
    id: id,
    genusKana: 'テストポケモン',
    genusKanji: '試験ポケモン',
    flavorKana: 'ひらがなの せつめい $id',
    flavorKanji: '漢字の説明 $id',
    heightDm: 4,
    weightHg: 60,
    cryUrl: 'https://example.com/cry/$id.ogg',
    evolution: [
      [id],
      [id + 1],
    ],
  );

  @override
  Future<DexEntry> getDexEntry(int id) async {
    if (!savedDex.contains(id) && !online) {
      throw const SocketException('offline');
    }
    savedDex.add(id);
    return dexOf(id);
  }

  @override
  Future<DexEntry?> cachedDexEntry(int id) async =>
      savedDex.contains(id) ? dexOf(id) : null;

  // 鳴き声のファイルは使わないので、ずっと読み込み中にしておく
  @override
  Future<File?> getCry(int id) => Completer<File?>().future;

  @override
  Future<void> downloadDex(int id) async {
    await getDexEntry(id);
  }

  /// downloadAll を途中で止めておきたいときに使う（complete するまで終わらない）
  Completer<void>? downloadGate;
  List<int>? downloadedIds; // 最後に downloadAll で頼まれた番号

  @override
  Future<int> downloadAll(
    List<int> ids, {
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    downloadedIds = ids;
    await downloadGate?.future;
    saved.addAll(ids);
    onProgress(ids.length, ids.length);
    return 0;
  }
}
