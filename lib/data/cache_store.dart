import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/pokemon.dart';

/// 取ってきたポケモンのデータと画像を、端末のファイルに保存・読み込みする
///
/// 保存場所: アプリ専用の Application Support フォルダの中
///   cache/pokemon/25.json        … 名前と画像URL
///   cache/images/official-artwork_25.png … 画像そのもの
/// （iOS の「Caches」フォルダと違い、容量が減っても OS に勝手に消されない）
class CacheStore {
  /// 保存先フォルダの決め方（テストでは一時フォルダに差し替える）
  final Future<Directory> Function() _baseDir;

  CacheStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  Future<Directory>? _root;
  Set<int>? _cachedIds; // 保存済みの図鑑番号（最初の1回だけフォルダを調べる）

  /// cache フォルダ（無ければ作る）。何度呼ばれても1回だけ作る
  Future<Directory> _rootDir() => _root ??= () async {
    final root = Directory('${(await _baseDir()).path}/cache');
    await Directory('${root.path}/pokemon').create(recursive: true);
    await Directory('${root.path}/images').create(recursive: true);
    return root;
  }();

  Future<File> _pokemonFile(int id) async =>
      File('${(await _rootDir()).path}/pokemon/$id.json');

  /// 画像の保存ファイル。URL の最後の2つ（例: official-artwork/25.png）から名前を作る
  Future<File> _imageFile(String url) async {
    final segments = Uri.parse(url).pathSegments;
    final name = segments.skip(segments.length - 2).join('_');
    return File('${(await _rootDir()).path}/images/$name');
  }

  /// 保存済みのポケモンを読む（無ければ null）
  Future<Pokemon?> readPokemon(int id) async {
    final file = await _pokemonFile(id);
    if (!await file.exists()) return null;
    try {
      return Pokemon.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on FormatException {
      return null; // ファイルが壊れていたら、無かったことにして取り直す
    }
  }

  Future<void> writePokemon(Pokemon pokemon) async {
    await _writeAtomically(
      await _pokemonFile(pokemon.id),
      utf8.encode(jsonEncode(pokemon.toJson())),
    );
    (await cachedPokemonIds()).add(pokemon.id);
  }

  /// 保存済みポケモンの図鑑番号の一覧
  Future<Set<int>> cachedPokemonIds() async {
    return _cachedIds ??= await () async {
      final dir = Directory('${(await _rootDir()).path}/pokemon');
      return {
        // ?: 数字に変換できない（null の）ファイル名は入れない
        await for (final f in dir.list())
          ?int.tryParse(f.uri.pathSegments.last.replaceAll('.json', '')),
      };
    }();
  }

  /// 保存済みの画像ファイル（無ければ null）
  Future<File?> readImage(String url) async {
    final file = await _imageFile(url);
    return await file.exists() ? file : null;
  }

  Future<File> writeImage(String url, List<int> bytes) async {
    final file = await _imageFile(url);
    await _writeAtomically(file, bytes);
    return file;
  }

  int _tmpCounter = 0;

  /// 書いている途中でアプリが終了しても壊れたファイルが残らないよう、
  /// 一時ファイルに書いてから名前を変える
  /// （同じファイルを同時に書いてもぶつからないよう、一時ファイル名は毎回変える）
  Future<void> _writeAtomically(File file, List<int> bytes) async {
    final tmp = File('${file.path}.${_tmpCounter++}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }
}
