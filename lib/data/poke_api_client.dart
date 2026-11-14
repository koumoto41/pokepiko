import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pokemon.dart';

/// PokéAPI と通信するクラス
class PokeApiClient {
  static const _baseUrl = 'https://pokeapi.co/api/v2';
  // オフラインなどで返事が来ないとき、いつまでも待たないように
  static const _timeout = Duration(seconds: 10);

  /// 公式イラストのURL（PokéAPI が /pokemon/{id} で返すものと同じ場所）
  /// 図鑑番号だけ分かれば、API に問い合わせずに表示できる
  static String artworkUrl(int id) =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

  final http.Client _client;

  PokeApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// 図鑑番号からポケモン1匹分のデータを取ってくる
  Future<Pokemon> fetchPokemon(int id) async {
    // 名前（species）と画像（pokemon）は別のエンドポイントなので並行して取る
    final results = await Future.wait([
      _getJson('$_baseUrl/pokemon-species/$id'),
      _getJson('$_baseUrl/pokemon/$id'),
    ]);
    final species = results[0];
    final pokemon = results[1];

    final sprites = pokemon['sprites'] as Map<String, dynamic>;
    return Pokemon(
      id: id,
      name: _japaneseName(species),
      artworkUrl:
          sprites['other']?['official-artwork']?['front_default'] as String?,
      spriteUrl: sprites['front_default'] as String?,
    );
  }

  /// species の names から日本語名を取り出す
  /// 言語コードは「ja-hrkt」（カタカナ）を優先し、無ければ「ja」を使う。
  /// API 側で大文字小文字が変わったことがあるので、小文字にそろえて比べる
  static String _japaneseName(Map<String, dynamic> species) {
    final names = species['names'] as List<dynamic>;
    String? find(String lang) {
      for (final n in names) {
        if ((n['language']['name'] as String).toLowerCase() == lang) {
          return n['name'] as String;
        }
      }
      return null;
    }

    return find('ja-hrkt') ?? find('ja') ?? species['name'] as String;
  }

  /// 画像などのファイルをそのままバイト列でダウンロードする
  Future<List<int>> downloadBytes(String url) async {
    return (await _get(url)).bodyBytes;
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final res = await _get(url);
    // utf8 で明示的にデコードしないと日本語が文字化けすることがある
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<http.Response> _get(String url) async {
    final res = await _client.get(Uri.parse(url)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('通信エラー: ${res.statusCode} ($url)');
    }
    return res;
  }
}
