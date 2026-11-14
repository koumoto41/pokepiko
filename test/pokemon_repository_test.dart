import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokepiko/data/cache_store.dart';
import 'package:pokepiko/data/poke_api_client.dart';
import 'package:pokepiko/data/pokemon_repository.dart';
import 'package:pokepiko/models/poke_type.dart';

import 'api_fixtures.dart';

/// 本物のファイル保存（一時フォルダ）＋ 偽のサーバーでテストする
void main() {
  late Directory tempDir;
  late int requestCount; // サーバーに何回問い合わせたか
  late bool online;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pokepiko_test');
    requestCount = 0;
    online = true;
  });
  tearDown(() => tempDir.delete(recursive: true));

  final mock = MockClient((req) async {
    if (!online) throw const SocketException('offline');
    requestCount++;
    final path = req.url.path;
    // 画像と鳴き声は、中身を [1, 2, 3] にしておく
    if (path.endsWith('.png') || path.endsWith('.ogg')) {
      return http.Response.bytes([1, 2, 3], 200);
    }
    final id = int.parse(path.split('/').where((s) => s.isNotEmpty).last);
    final body = path.contains('pokemon-species')
        ? speciesJson(id)
        : path.contains('evolution-chain')
        ? pikachuChainJson()
        : pokemonJson(id);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });

  // アプリを起動し直したときと同じく、毎回新しく作る（メモリの中身は空）
  PokemonRepository newRepository() => PokemonRepository(
    api: PokeApiClient(client: mock),
    cache: CacheStore(baseDir: () async => tempDir),
  );

  test('1回取ったデータと画像は、オフラインでも保存から読める', () async {
    final first = newRepository();
    final pikachu = await first.getPokemon(25);
    await first.downloadImages(pikachu);
    expect(pikachu.name, 'ピカチュウ');
    expect(await first.hasImages(pikachu), isTrue);

    // ネットを切って、アプリを起動し直したつもり
    online = false;
    final second = newRepository();
    final again = await second.getPokemon(25);
    expect(again.name, 'ピカチュウ');
    expect(again.artworkUrl, pikachu.artworkUrl);
    expect(await second.hasImages(again), isTrue);
    expect(await (await second.getImage(again.artworkUrl!)).readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(await second.cachedIds(), {25});
  });

  test('保存済みなら、サーバーに問い合わせない', () async {
    final repo = newRepository();
    await repo.downloadImages(await repo.getPokemon(25));
    final count = requestCount;

    await repo.downloadImages(await repo.getPokemon(25));
    expect(requestCount, count);
  });

  test('保存していないポケモンは、オフラインだとエラーになる', () async {
    online = false;
    await expectLater(newRepository().getPokemon(1), throwsA(anything));
  });

  test('まとめてダウンロードで、進み具合が通知される', () async {
    final progress = <int>[];
    final failed = await newRepository().downloadAll(
      [1, 2, 3, 4, 5],
      onProgress: (done, total) => progress.add(done),
      isCancelled: () => false,
    );
    expect(failed, 0);
    expect(progress, [1, 2, 3, 4, 5]);
    expect(await newRepository().cachedIds(), {1, 2, 3, 4, 5});
  });

  test('同じ画像を同時に頼んでも、ダウンロードは1回だけで両方成功する', () async {
    final repo = newRepository();
    final pikachu = await repo.getPokemon(25);
    final count = requestCount;

    final files = await Future.wait([
      repo.getImage(pikachu.artworkUrl!),
      repo.getImage(pikachu.artworkUrl!),
    ]);
    expect(requestCount, count + 1);
    expect(files[0].path, files[1].path);
  });

  test('タイプが入っていない古い保存データは、APIから取り直す（画像は取り直さない）', () async {
    // 1回目：ふつうに取って、画像まで保存する
    final first = newRepository();
    await first.downloadImages(await first.getPokemon(25));

    // タイプクイズ追加前の形（types なし）で保存されていたことにする
    final file = File('${tempDir.path}/cache/pokemon/25.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>
      ..remove('types');
    await file.writeAsString(jsonEncode(json));

    final count = requestCount;
    final repo = newRepository();
    final pikachu = await repo.getPokemon(25);
    expect(pikachu.types, [PokeType.electric]);
    expect(requestCount, count + 2); // species と pokemon の2回だけ
    await repo.downloadImages(pikachu);
    expect(requestCount, count + 2); // 画像は保存済みなので取らない
  });

  test('図鑑データと鳴き声も保存され、オフラインで読める', () async {
    final first = newRepository();
    await first.downloadDex(25);

    online = false;
    final second = newRepository();
    final entry = await second.getDexEntry(25);
    expect(entry.genusKana, 'ねずみポケモン');
    expect(entry.evolution, [
      [172],
      [25],
      [26],
    ]);
    final cry = await second.getCry(25);
    expect(await cry!.readAsBytes(), [1, 2, 3]);
  });

  test('まとめてダウンロードすると、図鑑データも保存される', () async {
    await newRepository().downloadAll(
      [25],
      onProgress: (_, _) {},
      isCancelled: () => false,
    );
    online = false;
    expect((await newRepository().getDexEntry(25)).heightDm, 4);
  });
}
