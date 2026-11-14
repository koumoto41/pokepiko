import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokepiko/data/poke_api_client.dart';
import 'package:pokepiko/models/poke_type.dart';

import 'api_fixtures.dart';

/// 指定した言語コードで species の名前を返す、偽のサーバー
PokeApiClient clientWithNames(List<(String, String)> names) {
  final mock = MockClient((req) async {
    final body = req.url.path.contains('pokemon-species')
        ? {
            'name': 'pikachu',
            'names': [
              for (final (lang, name) in names)
                {
                  'language': {'name': lang},
                  'name': name,
                },
            ],
          }
        : {
            'sprites': {'front_default': null, 'other': {}},
            // 本物の API と同じ形。stellar のような知らないタイプは無視されるはず
            'types': [
              {
                'slot': 1,
                'type': {'name': 'electric'},
              },
              {
                'slot': 2,
                'type': {'name': 'stellar'},
              },
            ],
          };
    // 本物と同じく UTF-8 のバイト列で返す
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
  return PokeApiClient(client: mock);
}

void main() {
  test('言語コードが小文字の ja-hrkt でもカタカナ名を使う', () async {
    final api = clientWithNames([('en', 'Pikachu'), ('ja-hrkt', 'ピカチュウ')]);
    expect((await api.fetchPokemon(25)).name, 'ピカチュウ');
  });

  test('言語コードが ja-Hrkt（大文字まじり）でもカタカナ名を使う', () async {
    final api = clientWithNames([('en', 'Pikachu'), ('ja-Hrkt', 'ピカチュウ')]);
    expect((await api.fetchPokemon(25)).name, 'ピカチュウ');
  });

  test('ja-hrkt が無ければ ja を使う', () async {
    final api = clientWithNames([('en', 'Pikachu'), ('ja', 'ピカチュウ')]);
    expect((await api.fetchPokemon(25)).name, 'ピカチュウ');
  });

  test('タイプを読み取る（知らないタイプは入れない）', () async {
    final api = clientWithNames([('ja-hrkt', 'ピカチュウ')]);
    expect((await api.fetchPokemon(25)).types, [PokeType.electric]);
  });

  group('図鑑データ', () {
    late int chainRequests; // 進化のつながりを何回取りにいったか

    /// species と pokemon と evolution-chain を返す偽のサーバー
    /// 25・26 番はピカチュウの仲間、133 番はイーブイ、906 番は説明文なし
    PokeApiClient dexClient() {
      chainRequests = 0;
      return PokeApiClient(
        client: MockClient((req) async {
          final path = req.url.path;
          final id = int.parse(path.split('/').where((s) => s.isNotEmpty).last);
          final Object body;
          if (path.contains('evolution-chain')) {
            chainRequests++;
            body = id == 67 ? eeveeChainJson() : pikachuChainJson();
          } else if (path.contains('pokemon-species')) {
            body = speciesJson(
              id,
              chainId: id == 133 ? 67 : 10,
              withFlavor: id != 906,
            );
          } else {
            body = pokemonJson(id);
          }
          return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
        }),
      );
    }

    test('分類・説明文（いちばん新しいもの）・高さ・重さ・鳴き声を読み取る', () async {
      final e = await dexClient().fetchDexEntry(25);
      expect(e.genusKana, 'ねずみポケモン');
      expect(e.genusKanji, 'ねずみポケモン');
      // 改行（\n や \f）は全角スペースにして1行にする
      expect(e.flavorKana, 'しっぽを　たてて　まわりの　ようすを　さぐる。');
      expect(e.flavorKanji, '尻尾を　立てて　まわりの　様子を探る。');
      expect(e.heightText, '0.4 m');
      expect(e.weightText, '6.0 kg');
      expect(e.cryUrl, 'https://example.com/cries/latest/25.ogg');
    });

    test('進化のつながりを段階ごとに読み取り、同じ仲間では使い回す', () async {
      final api = dexClient();
      final pikachu = await api.fetchDexEntry(25);
      expect(pikachu.evolution, [
        [172],
        [25],
        [26],
      ]);
      await api.fetchDexEntry(26); // ライチュウも同じ進化のつながり
      expect(chainRequests, 1);
    });

    test('枝分かれする進化（イーブイ）は、同じ段階に並べる', () async {
      final eevee = await dexClient().fetchDexEntry(133);
      expect(eevee.evolution, [
        [133],
        [134, 135, 136],
      ]);
    });

    test('日本語の説明文がないポケモンは null', () async {
      final e = await dexClient().fetchDexEntry(906);
      expect(e.flavorKana, isNull);
      expect(e.flavorKanji, isNull);
      expect(e.genusKana, 'ねずみポケモン'); // 分類はある
    });
  });
}
