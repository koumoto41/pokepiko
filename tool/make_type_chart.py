"""PokéAPI の各タイプの damage_relations から、タイプ相性の一覧を作って
lib/models/type_chart.dart を書き出す。

アプリが毎回 API に聞かなくてよいよう（オフラインでも見られるよう）、一覧をアプリに持たせるため。
相性が変わったら（新しい作品で変わることがある）、もう一度実行する。

使い方: python3 -I tool/make_type_chart.py <出力する .dart のパス>
"""
import json
import sys
import urllib.request

# lib/models/poke_type.dart の PokeType と同じ18種類（同じ順番）
TYPES = [
    "normal", "fire", "water", "grass", "electric", "ice", "fighting",
    "poison", "ground", "flying", "psychic", "bug", "rock", "ghost",
    "dragon", "dark", "steel", "fairy",
]


def fetch(name):
    url = f"https://pokeapi.co/api/v2/type/{name}"
    # Python の標準の名前（Python-urllib）だと断られる（403）ので、名前をつける
    req = urllib.request.Request(url, headers={"User-Agent": "pokepiko-tool/1.0"})
    with urllib.request.urlopen(req, timeout=30) as res:
        return json.load(res)["damage_relations"]


def main(path):
    rows = []
    for attack in TYPES:
        rel = fetch(attack)
        # 攻撃する側から見た倍率（書いていないタイプは 1倍）
        multipliers = {}
        for key, value in [
            ("double_damage_to", "2"),
            ("half_damage_to", "0.5"),
            ("no_damage_to", "0"),
        ]:
            for t in rel[key]:
                if t["name"] in TYPES:  # stellar などは使わない
                    multipliers[t["name"]] = value
        items = ", ".join(
            f"PokeType.{d}: {m}" for d, m in multipliers.items()
        )
        rows.append(f"    PokeType.{attack}: {{{items}}},")

    with open(path, "w", encoding="utf-8") as f:
        f.write("""// このファイルは tool/make_type_chart.py で作ったもの（手で直さない）
// PokéAPI の /type/{name} の damage_relations から集めたタイプ相性

import 'poke_type.dart';

/// タイプ相性（攻撃するわざのタイプ → 受けるポケモンのタイプ → 倍率）
abstract final class TypeChart {
  // ここに書いていない組み合わせは 1倍
  static const _chart = <PokeType, Map<PokeType, double>>{
""" + "\n".join(rows) + """
  };

  /// attack タイプのわざで、defend タイプのポケモンを攻撃したときの倍率（2, 1, 0.5, 0）
  static double multiplier(PokeType attack, PokeType defend) =>
      _chart[attack]?[defend] ?? 1;

  /// attack タイプのわざが、倍率 value になる相手のタイプ
  static List<PokeType> targets(PokeType attack, double value) => [
    for (final t in PokeType.values)
      if (multiplier(attack, t) == value) t,
  ];

  /// defend タイプのポケモンが、倍率 value で受けるわざのタイプ
  static List<PokeType> attackers(PokeType defend, double value) => [
    for (final t in PokeType.values)
      if (multiplier(t, defend) == value) t,
  ];
}
""")
    print(f"{len(TYPES)}タイプ → {path}")


if __name__ == "__main__":
    main(sys.argv[1])
