// このファイルは tool/make_mega_list.py で作ったもの（手で直さない）
// PokéAPI の /pokemon と /pokemon-form（is_mega）から集めた、メガシンカのすがた

import 'poke_type.dart';

/// メガシンカのすがた1つ分
class MegaForm {
  final int id; // PokéAPI の番号（10000番台。画像の URL に使う）
  final String name; // カタカナの名前（例：メガリザードンX）
  final List<PokeType> types; // メガシンカしたあとのタイプ

  const MegaForm(this.id, this.name, this.types);
}

/// 図鑑番号ごとの、メガシンカのすがた（97種類・87匹）
abstract final class Mega {
  static const _bySpecies = <int, List<MegaForm>>{
    3: [
      MegaForm(10033, 'メガフシギバナ', [PokeType.grass, PokeType.poison]),
    ],
    6: [
      MegaForm(10034, 'メガリザードンX', [PokeType.fire, PokeType.dragon]),
      MegaForm(10035, 'メガリザードンY', [PokeType.fire, PokeType.flying]),
    ],
    9: [
      MegaForm(10036, 'メガカメックス', [PokeType.water]),
    ],
    15: [
      MegaForm(10090, 'メガスピアー', [PokeType.bug, PokeType.poison]),
    ],
    18: [
      MegaForm(10073, 'メガピジョット', [PokeType.normal, PokeType.flying]),
    ],
    26: [
      MegaForm(10304, 'メガライチュウX', [PokeType.electric]),
      MegaForm(10305, 'メガライチュウY', [PokeType.electric]),
    ],
    36: [
      MegaForm(10278, 'メガピクシー', [PokeType.fairy, PokeType.flying]),
    ],
    65: [
      MegaForm(10037, 'メガフーディン', [PokeType.psychic]),
    ],
    71: [
      MegaForm(10279, 'メガウツボット', [PokeType.grass, PokeType.poison]),
    ],
    80: [
      MegaForm(10071, 'メガヤドラン', [PokeType.water, PokeType.psychic]),
    ],
    94: [
      MegaForm(10038, 'メガゲンガー', [PokeType.ghost, PokeType.poison]),
    ],
    115: [
      MegaForm(10039, 'メガガルーラ', [PokeType.normal]),
    ],
    121: [
      MegaForm(10280, 'メガスターミー', [PokeType.water, PokeType.psychic]),
    ],
    127: [
      MegaForm(10040, 'メガカイロス', [PokeType.bug, PokeType.flying]),
    ],
    130: [
      MegaForm(10041, 'メガギャラドス', [PokeType.water, PokeType.dark]),
    ],
    142: [
      MegaForm(10042, 'メガプテラ', [PokeType.rock, PokeType.flying]),
    ],
    149: [
      MegaForm(10281, 'メガカイリュー', [PokeType.dragon, PokeType.flying]),
    ],
    150: [
      MegaForm(10043, 'メガミュウツーX', [PokeType.psychic, PokeType.fighting]),
      MegaForm(10044, 'メガミュウツーY', [PokeType.psychic]),
    ],
    154: [
      MegaForm(10282, 'メガメガニウム', [PokeType.grass, PokeType.fairy]),
    ],
    160: [
      MegaForm(10283, 'メガオーダイル', [PokeType.water, PokeType.dragon]),
    ],
    181: [
      MegaForm(10045, 'メガデンリュウ', [PokeType.electric, PokeType.dragon]),
    ],
    208: [
      MegaForm(10072, 'メガハガネール', [PokeType.steel, PokeType.ground]),
    ],
    212: [
      MegaForm(10046, 'メガハッサム', [PokeType.bug, PokeType.steel]),
    ],
    214: [
      MegaForm(10047, 'メガヘラクロス', [PokeType.bug, PokeType.fighting]),
    ],
    227: [
      MegaForm(10284, 'メガエアームド', [PokeType.steel, PokeType.flying]),
    ],
    229: [
      MegaForm(10048, 'メガヘルガー', [PokeType.dark, PokeType.fire]),
    ],
    248: [
      MegaForm(10049, 'メガバンギラス', [PokeType.rock, PokeType.dark]),
    ],
    254: [
      MegaForm(10065, 'メガジュカイン', [PokeType.grass, PokeType.dragon]),
    ],
    257: [
      MegaForm(10050, 'メガバシャーモ', [PokeType.fire, PokeType.fighting]),
    ],
    260: [
      MegaForm(10064, 'メガラグラージ', [PokeType.water, PokeType.ground]),
    ],
    282: [
      MegaForm(10051, 'メガサーナイト', [PokeType.psychic, PokeType.fairy]),
    ],
    302: [
      MegaForm(10066, 'メガヤミラミ', [PokeType.dark, PokeType.ghost]),
    ],
    303: [
      MegaForm(10052, 'メガクチート', [PokeType.steel, PokeType.fairy]),
    ],
    306: [
      MegaForm(10053, 'メガボスゴドラ', [PokeType.steel]),
    ],
    308: [
      MegaForm(10054, 'メガチャーレム', [PokeType.fighting, PokeType.psychic]),
    ],
    310: [
      MegaForm(10055, 'メガライボルト', [PokeType.electric]),
    ],
    319: [
      MegaForm(10070, 'メガサメハダー', [PokeType.water, PokeType.dark]),
    ],
    323: [
      MegaForm(10087, 'メガバクーダ', [PokeType.fire, PokeType.ground]),
    ],
    334: [
      MegaForm(10067, 'メガチルタリス', [PokeType.dragon, PokeType.fairy]),
    ],
    354: [
      MegaForm(10056, 'メガジュペッタ', [PokeType.ghost]),
    ],
    358: [
      MegaForm(10306, 'メガチリーン', [PokeType.psychic, PokeType.steel]),
    ],
    359: [
      MegaForm(10057, 'メガアブソル', [PokeType.dark]),
      MegaForm(10307, 'メガアブソルZ', [PokeType.dark, PokeType.ghost]),
    ],
    362: [
      MegaForm(10074, 'メガオニゴーリ', [PokeType.ice]),
    ],
    373: [
      MegaForm(10089, 'メガボーマンダ', [PokeType.dragon, PokeType.flying]),
    ],
    376: [
      MegaForm(10076, 'メガメタグロス', [PokeType.steel, PokeType.psychic]),
    ],
    380: [
      MegaForm(10062, 'メガラティアス', [PokeType.dragon, PokeType.psychic]),
    ],
    381: [
      MegaForm(10063, 'メガラティオス', [PokeType.dragon, PokeType.psychic]),
    ],
    384: [
      MegaForm(10079, 'メガレックウザ', [PokeType.dragon, PokeType.flying]),
    ],
    398: [
      MegaForm(10308, 'メガムクホーク', [PokeType.fighting, PokeType.flying]),
    ],
    428: [
      MegaForm(10088, 'メガミミロップ', [PokeType.normal, PokeType.fighting]),
    ],
    445: [
      MegaForm(10058, 'メガガブリアス', [PokeType.dragon, PokeType.ground]),
      MegaForm(10309, 'メガガブリアスZ', [PokeType.dragon]),
    ],
    448: [
      MegaForm(10059, 'メガルカリオ', [PokeType.fighting, PokeType.steel]),
      MegaForm(10310, 'メガルカリオZ', [PokeType.fighting, PokeType.steel]),
    ],
    460: [
      MegaForm(10060, 'メガユキノオー', [PokeType.grass, PokeType.ice]),
    ],
    475: [
      MegaForm(10068, 'メガエルレイド', [PokeType.psychic, PokeType.fighting]),
    ],
    478: [
      MegaForm(10285, 'メガユキメノコ', [PokeType.ice, PokeType.ghost]),
    ],
    485: [
      MegaForm(10311, 'メガヒードラン', [PokeType.fire, PokeType.steel]),
    ],
    491: [
      MegaForm(10312, 'メガダークライ', [PokeType.dark]),
    ],
    500: [
      MegaForm(10286, 'メガエンブオー', [PokeType.fire, PokeType.fighting]),
    ],
    530: [
      MegaForm(10287, 'メガドリュウズ', [PokeType.ground, PokeType.steel]),
    ],
    531: [
      MegaForm(10069, 'メガタブンネ', [PokeType.normal, PokeType.fairy]),
    ],
    545: [
      MegaForm(10288, 'メガペンドラー', [PokeType.bug, PokeType.poison]),
    ],
    560: [
      MegaForm(10289, 'メガズルズキン', [PokeType.dark, PokeType.fighting]),
    ],
    604: [
      MegaForm(10290, 'メガシビルドン', [PokeType.electric]),
    ],
    609: [
      MegaForm(10291, 'メガシャンデラ', [PokeType.ghost, PokeType.fire]),
    ],
    623: [
      MegaForm(10313, 'メガゴルーグ', [PokeType.ground, PokeType.ghost]),
    ],
    652: [
      MegaForm(10292, 'メガブリガロン', [PokeType.grass, PokeType.fighting]),
    ],
    655: [
      MegaForm(10293, 'メガマフォクシー', [PokeType.fire, PokeType.psychic]),
    ],
    658: [
      MegaForm(10294, 'メガゲッコウガ', [PokeType.water, PokeType.dark]),
    ],
    668: [
      MegaForm(10295, 'メガカエンジシ', [PokeType.fire, PokeType.normal]),
    ],
    670: [
      MegaForm(10296, 'メガフラエッテ', [PokeType.fairy]),
    ],
    678: [
      MegaForm(10314, 'メガニャオニクス', [PokeType.psychic]),
      MegaForm(10326, 'メガニャオニクス', [PokeType.psychic]),
    ],
    687: [
      MegaForm(10297, 'メガカラマネロ', [PokeType.dark, PokeType.psychic]),
    ],
    689: [
      MegaForm(10298, 'メガガメノデス', [PokeType.rock, PokeType.fighting]),
    ],
    691: [
      MegaForm(10299, 'メガドラミドロ', [PokeType.poison, PokeType.dragon]),
    ],
    701: [
      MegaForm(10300, 'メガルチャブル', [PokeType.fighting, PokeType.flying]),
    ],
    718: [
      MegaForm(10301, 'メガジガルデ', [PokeType.dragon, PokeType.ground]),
    ],
    719: [
      MegaForm(10075, 'メガディアンシー', [PokeType.rock, PokeType.fairy]),
    ],
    740: [
      MegaForm(10315, 'メガケケンカニ', [PokeType.fighting, PokeType.ice]),
    ],
    768: [
      MegaForm(10316, 'メガグソクムシャ', [PokeType.bug, PokeType.steel]),
    ],
    780: [
      MegaForm(10302, 'メガジジーロン', [PokeType.normal, PokeType.dragon]),
    ],
    801: [
      MegaForm(10317, 'メガマギアナ', [PokeType.steel, PokeType.fairy]),
      MegaForm(10318, 'メガマギアナ', [PokeType.steel, PokeType.fairy]),
    ],
    807: [
      MegaForm(10319, 'メガゼラオラ', [PokeType.electric]),
    ],
    870: [
      MegaForm(10303, 'メガタイレーツ', [PokeType.fighting]),
    ],
    952: [
      MegaForm(10320, 'メガスコヴィラン', [PokeType.grass, PokeType.fire]),
    ],
    970: [
      MegaForm(10321, 'メガキラフロル', [PokeType.rock, PokeType.poison]),
    ],
    978: [
      MegaForm(10322, 'メガシャリタツ', [PokeType.dragon, PokeType.water]),
      MegaForm(10323, 'メガシャリタツ', [PokeType.dragon, PokeType.water]),
      MegaForm(10324, 'メガシャリタツ', [PokeType.dragon, PokeType.water]),
    ],
    998: [
      MegaForm(10325, 'メガセグレイブ', [PokeType.dragon, PokeType.ice]),
    ],
  };

  /// そのポケモンのメガシンカ（ないポケモンは、からっぽ）
  static List<MegaForm> of(int id) => _bySpecies[id] ?? const [];
}
