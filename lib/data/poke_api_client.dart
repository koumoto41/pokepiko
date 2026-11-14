import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dex_entry.dart';
import '../models/poke_type.dart';
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

  // 進化のつながりは、同じ進化の仲間（例：ピチュー・ピカチュウ・ライチュウ）で共通なので、
  // 1回取ったら使い回す（URL → 段階ごとの図鑑番号）
  final _evolutionCache = <String, Future<List<List<int>>>>{};

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
      // types: [{slot: 1, type: {name: fire}}, ...] から、知っているタイプだけ取り出す
      types: [
        // ?: 知らないタイプ（null）は入れない
        for (final t in pokemon['types'] as List<dynamic>)
          ?PokeType.fromApiName(t['type']['name'] as String),
      ],
    );
  }

  /// 図鑑のくわしいページ用のデータを取ってくる
  /// （分類と説明文は species、高さ・重さ・鳴き声は pokemon、進化は evolution-chain）
  Future<DexEntry> fetchDexEntry(int id) async {
    final results = await Future.wait([
      _getJson('$_baseUrl/pokemon-species/$id'),
      _getJson('$_baseUrl/pokemon/$id'),
    ]);
    final species = results[0];
    final pokemon = results[1];

    final chainUrl = species['evolution_chain']?['url'] as String?;
    final cries = pokemon['cries'] as Map<String, dynamic>?;
    return DexEntry(
      id: id,
      genusKana: _pickText(species['genera'], 'ja-hrkt', 'genus'),
      genusKanji: _pickText(species['genera'], 'ja', 'genus'),
      flavorKana: _pickText(
        species['flavor_text_entries'],
        'ja-hrkt',
        'flavor_text',
      ),
      flavorKanji: _pickText(
        species['flavor_text_entries'],
        'ja',
        'flavor_text',
      ),
      heightDm: pokemon['height'] as int,
      weightHg: pokemon['weight'] as int,
      // 新しい鳴き声（latest）を優先し、無ければ昔の鳴き声（legacy）
      cryUrl: cries?['latest'] as String? ?? cries?['legacy'] as String?,
      evolution: chainUrl == null
          ? [
              [id],
            ]
          : await (_evolutionCache[chainUrl] ??= _fetchEvolution(chainUrl)),
    );
  }

  /// 進化のつながりを、段階ごとの図鑑番号にする
  /// chain は { species: {url: .../172/}, evolves_to: [ {species, evolves_to}, ... ] } の入れ子
  Future<List<List<int>>> _fetchEvolution(String url) async {
    final json = await _getJson(url);
    final stages = <List<int>>[];
    var current = [json['chain'] as Map<String, dynamic>];
    while (current.isNotEmpty) {
      stages.add([
        for (final node in current)
          _idFromUrl(node['species']['url'] as String),
      ]);
      current = [
        for (final node in current)
          for (final next in node['evolves_to'] as List<dynamic>)
            next as Map<String, dynamic>,
      ];
    }
    return stages;
  }

  /// 「https://pokeapi.co/api/v2/pokemon-species/25/」から 25 を取り出す
  static int _idFromUrl(String url) =>
      int.parse(url.split('/').where((s) => s.isNotEmpty).last);

  /// 言語ごとの文章のリストから、指定した言語のいちばん新しいものを取り出す
  /// 説明文はゲームのバージョンごとに入っていて、リストの後ろほど新しい
  static String? _pickText(dynamic entries, String lang, String field) {
    String? found;
    for (final e in entries as List<dynamic>) {
      if ((e['language']['name'] as String).toLowerCase() == lang) {
        found = e[field] as String;
      }
    }
    // 説明文の中の改行は、ゲーム画面での折り返し。全角スペースにして1行にする
    return found
        ?.replaceAll(RegExp(r'[\n\f]+'), '\u3000')
        .replaceAll(RegExp('\u3000+'), '\u3000')
        .trim();
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
