"""PokéAPI から、メガシンカのすがた（名前・タイプ）を集めて、lib/models/mega.dart を書き出す。

アプリが毎回 API に聞かなくてよいよう（オフラインでも使えるよう）、一覧をアプリに持たせるため。
新しいメガシンカが増えたら、もう一度実行する。

使い方: python3 -I tool/make_mega_list.py <出力する .dart のパス>
"""
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

API = "https://pokeapi.co/api/v2"

# アプリの PokeType の名前（lib/models/poke_type.dart と合わせる）
TYPES = {
    "normal", "fire", "water", "grass", "electric", "ice", "fighting",
    "poison", "ground", "flying", "psychic", "bug", "rock", "ghost",
    "dragon", "dark", "steel", "fairy",
}

# 名前の中の全角の Ｘ・Ｙ・Ｚ を半角にそろえる（API の中で、古いものと新しいものでちがうため）
WIDE = str.maketrans("ＸＹＺ", "XYZ")


def get(url):
    # Python の標準の名前（Python-urllib）だと断られる（403）ので、名前をつける
    req = urllib.request.Request(url, headers={"User-Agent": "pokepiko-tool/1.0"})
    for attempt in range(3):  # うまくいかなかったら、少し待ってやり直す
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                return json.load(res)
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


def japanese(names):
    """ひらがな版（ja-hrkt）→ 漢字版（ja）の順に、日本語の名前を探す"""
    by_lang = {n["language"]["name"].lower(): n["name"] for n in names}
    return by_lang.get("ja-hrkt") or by_lang.get("ja")


def fetch(name):
    p = get(f"{API}/pokemon/{name}")
    form = get(p["forms"][0]["url"])
    if not form["is_mega"]:
        return None
    label = japanese(form["form_names"]) or japanese(form["names"])
    if label is None:
        raise ValueError(f"{name} の日本語名がない")
    species_id = int(p["species"]["url"].rstrip("/").split("/")[-1])
    types = [t["type"]["name"] for t in p["types"] if t["type"]["name"] in TYPES]
    return species_id, p["id"], label.translate(WIDE), types


def main(path):
    names = [r["name"] for r in get(f"{API}/pokemon?limit=5000")["results"]
             if "-mega" in r["name"]]
    # PokéAPI に負担をかけすぎないよう、同時に8つまで
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = [r for r in pool.map(fetch, names) if r is not None]

    by_species = {}
    for species_id, id_, label, types in sorted(rows, key=lambda r: (r[0], r[1])):
        by_species.setdefault(species_id, []).append((id_, label, types))

    lines = []
    for species_id, forms in sorted(by_species.items()):
        lines.append(f"    {species_id}: [")
        for id_, label, types in forms:
            type_list = ", ".join(f"PokeType.{t}" for t in types)
            lines.append(f"      MegaForm({id_}, '{label}', [{type_list}]),")
        lines.append("    ],")
    body = "\n".join(lines)

    with open(path, "w", encoding="utf-8") as f:
        f.write(f"""// このファイルは tool/make_mega_list.py で作ったもの（手で直さない）
// PokéAPI の /pokemon と /pokemon-form（is_mega）から集めた、メガシンカのすがた

import 'poke_type.dart';

/// メガシンカのすがた1つ分
class MegaForm {{
  final int id; // PokéAPI の番号（10000番台。画像の URL に使う）
  final String name; // カタカナの名前（例：メガリザードンX）
  final List<PokeType> types; // メガシンカしたあとのタイプ

  const MegaForm(this.id, this.name, this.types);
}}

/// 図鑑番号ごとの、メガシンカのすがた（{len(rows)}種類・{len(by_species)}匹）
abstract final class Mega {{
  static const _bySpecies = <int, List<MegaForm>>{{
{body}
  }};

  /// そのポケモンのメガシンカ（ないポケモンは、からっぽ）
  static List<MegaForm> of(int id) => _bySpecies[id] ?? const [];
}}
""")
    print(f"メガシンカ {len(rows)}種類・{len(by_species)}匹 → {path}")


if __name__ == "__main__":
    main(sys.argv[1])
