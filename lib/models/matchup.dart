import 'poke_type.dart';
import 'type_chart.dart';

/// 2匹のポケモンが戦ったときの、タイプの相性（あいしょうクイズで使う）
/// わざは、自分のタイプと同じタイプのものを使うことにする
abstract final class Matchup {
  /// attack のタイプのわざで、defend のタイプのポケモンを攻撃したときの倍率
  /// （2タイプのポケモンは倍率をかけ算する。わざのタイプは、いちばん効くものを選ぶ）
  static double best(List<PokeType> attack, List<PokeType> defend) {
    var best = 0.0;
    for (final a in attack) {
      final value = defend.fold(1.0, (v, d) => v * TypeChart.multiplier(a, d));
      if (value > best) best = value;
    }
    return best;
  }

  /// a と b のどちらが相性で勝つか（0 = a、1 = b）。はっきりしないときは null
  /// 「勝つ」＝ 相手に「こうかばつぐん（2倍以上）」で、相手からは ばつぐんを受けない
  static int? winner(List<PokeType> a, List<PokeType> b) {
    final aToB = best(a, b);
    final bToA = best(b, a);
    if (aToB >= 2 && bToA <= 1) return 0;
    if (bToA >= 2 && aToB <= 1) return 1;
    return null;
  }

  /// 勝つ理由（「みず は ほのお に つよい」の、みず と ほのお）
  /// 2倍以上になるのは、どれかのタイプの組み合わせが2倍のときだけなので、必ず見つかる
  static (PokeType, PokeType) reason(
    List<PokeType> winner,
    List<PokeType> loser,
  ) {
    final attack = winner.reduce(
      (x, y) => best([x], loser) >= best([y], loser) ? x : y,
    );
    final defend = loser.firstWhere(
      (d) => TypeChart.multiplier(attack, d) == 2,
    );
    return (attack, defend);
  }
}
