// テスト用の「本物の PokéAPI と同じ形の返事」
// 実際の API（ピカチュウなど）を確かめて、使う項目だけを同じ形で作っている

Map<String, dynamic> _lang(String lang, String field, String text) => {
  'language': {'name': lang},
  field: text,
};

/// /pokemon-species/{id}
Map<String, dynamic> speciesJson(
  int id, {
  String name = 'ピカチュウ',
  int chainId = 10,
  bool withFlavor = true,
}) => {
  'name': 'pokemon$id',
  'names': [_lang('ja-hrkt', 'name', name)],
  'genera': [
    _lang('ja-hrkt', 'genus', 'ねずみポケモン'),
    _lang('ja', 'genus', 'ねずみポケモン'),
    _lang('en', 'genus', 'Mouse Pokémon'),
  ],
  // 説明文はバージョンごとにあり、後ろほど新しい。ゲーム画面での改行 \n や \f が入っている
  'flavor_text_entries': withFlavor
      ? [
          _lang('ja-hrkt', 'flavor_text', 'ふるい\nせつめい'),
          _lang('ja', 'flavor_text', '古い\n説明'),
          _lang('ja-hrkt', 'flavor_text', 'しっぽを　たてて\nまわりの\fようすを　さぐる。'),
          _lang('ja', 'flavor_text', '尻尾を　立てて\nまわりの\f様子を探る。'),
          _lang('en', 'flavor_text', 'English text'),
        ]
      : [],
  'evolution_chain': {
    'url': 'https://pokeapi.co/api/v2/evolution-chain/$chainId/',
  },
};

/// /pokemon/{id}
Map<String, dynamic> pokemonJson(int id) => {
  'height': 4,
  'weight': 60,
  'sprites': {
    'front_default': 'https://example.com/sprites/pokemon/$id.png',
    'other': {
      'official-artwork': {
        'front_default':
            'https://example.com/pokemon/other/official-artwork/$id.png',
      },
    },
  },
  'types': [
    {
      'slot': 1,
      'type': {'name': 'electric'},
    },
  ],
  'cries': {
    'latest': 'https://example.com/cries/latest/$id.ogg',
    'legacy': 'https://example.com/cries/legacy/$id.ogg',
  },
};

Map<String, dynamic> _node(int id, List<Map<String, dynamic>> next) => {
  'species': {'url': 'https://pokeapi.co/api/v2/pokemon-species/$id/'},
  'evolves_to': next,
};

/// /evolution-chain/{id}：ピチュー(172) → ピカチュウ(25) → ライチュウ(26)
Map<String, dynamic> pikachuChainJson() => {
  'chain': _node(172, [
    _node(25, [_node(26, [])]),
  ]),
};

/// /evolution-chain/{id}：イーブイ(133) → 3匹に枝分かれ
Map<String, dynamic> eeveeChainJson() => {
  'chain': _node(133, [_node(134, []), _node(135, []), _node(136, [])]),
};
