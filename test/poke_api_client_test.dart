import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokepiko/data/poke_api_client.dart';

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
}
