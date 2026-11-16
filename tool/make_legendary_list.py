"""PokéAPI の全ポケモンから、伝説（is_legendary）と幻（is_mythical）の図鑑番号を集めて、
lib/models/legendary.dart を書き出す。

アプリが毎回 API に聞かなくてよいよう（オフラインでも使えるよう）、一覧をアプリに持たせるため。
新しいポケモンが増えたら、もう一度実行する。

使い方: python3 -I tool/make_legendary_list.py <出力する .dart のパス>
"""
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

LAST_ID = 1025  # lib/models/generation.dart の最後の図鑑番号と合わせる


def fetch(id_):
    url = f"https://pokeapi.co/api/v2/pokemon-species/{id_}"
    # Python の標準の名前（Python-urllib）だと断られる（403）ので、名前をつける
    req = urllib.request.Request(url, headers={"User-Agent": "pokepiko-tool/1.0"})
    for attempt in range(3):  # うまくいかなかったら、少し待ってやり直す
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                d = json.load(res)
            return id_, d["is_legendary"], d["is_mythical"]
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


def main(path):
    # PokéAPI に負担をかけすぎないよう、同時に8つまで
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(fetch, range(1, LAST_ID + 1)))
    legendary = [i for i, leg, _ in rows if leg]
    mythical = [i for i, _, myth in rows if myth]

    def dart_set(ids):
        lines, line = [], "   "
        for i in ids:
            item = f" {i},"
            if len(line) + len(item) > 78:
                lines.append(line)
                line = "   "
            line += item
        lines.append(line)
        return "\n".join(lines)

    with open(path, "w", encoding="utf-8") as f:
        f.write(f"""// このファイルは tool/make_legendary_list.py で作ったもの（手で直さない）
// PokéAPI の /pokemon-species の is_legendary・is_mythical から集めた図鑑番号

/// 伝説・幻のポケモン
abstract final class Legendary {{
  /// 伝説のポケモン（{len(legendary)}匹）
  static const legendary = {{
{dart_set(legendary)}
  }};

  /// 幻のポケモン（{len(mythical)}匹）
  static const mythical = {{
{dart_set(mythical)}
  }};

  static bool isLegendary(int id) => legendary.contains(id);
  static bool isMythical(int id) => mythical.contains(id);

  /// 伝説か幻のどちらか
  static bool isSpecial(int id) => isLegendary(id) || isMythical(id);

  /// 伝説・幻をあわせた一覧（番号の順）。でんせつクイズの出題の候補
  static final all = [...legendary, ...mythical]..sort();
}}
""")
    print(f"伝説 {len(legendary)}匹・幻 {len(mythical)}匹 → {path}")


if __name__ == "__main__":
    main(sys.argv[1])
