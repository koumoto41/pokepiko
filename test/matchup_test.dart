import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/models/matchup.dart';
import 'package:pokepiko/models/poke_type.dart';

/// あいしょうクイズの、2匹の勝ち負けの決めかた
void main() {
  const fire = [PokeType.fire];
  const water = [PokeType.water];
  const grass = [PokeType.grass];
  const normal = [PokeType.normal];

  test('いちばん効くタイプのわざで、2タイプはかけ算する', () {
    expect(Matchup.best(water, fire), 2);
    expect(Matchup.best(fire, water), 0.5);
    // ほのお → くさ・はがね（ナットレイ）は 4倍
    expect(Matchup.best(fire, [PokeType.grass, PokeType.steel]), 4);
    // みず・じめん（ヌオー）に でんきは効かず、くさは 4倍。でんき・くさのポケモンは くさを使う
    expect(
      Matchup.best(
        [PokeType.electric, PokeType.grass],
        [PokeType.water, PokeType.ground],
      ),
      4,
    );
  });

  test('ばつぐんで攻撃でき、相手からは ばつぐんを受けないほうが勝ち', () {
    expect(Matchup.winner(fire, water), 1);
    expect(Matchup.winner(water, fire), 0);
    expect(Matchup.winner(grass, water), 0);
    // みず・ひこう（ギャラドス）とくさ：みず→くさは今ひとつでも、ひこう→くさは ばつぐん
    expect(Matchup.winner([PokeType.water, PokeType.flying], grass), 0);
  });

  test('勝ち負けがはっきりしないときは null', () {
    // おたがいに 1倍
    expect(Matchup.winner(normal, normal), isNull);
    expect(Matchup.winner(fire, [PokeType.electric]), isNull);
    // おたがいに ばつぐん（ドラゴン同士）
    expect(Matchup.winner([PokeType.dragon], [PokeType.dragon]), isNull);
  });

  test('勝つ理由は、勝つほうのタイプと、2倍になる相手のタイプ', () {
    expect(Matchup.reason(water, fire), (PokeType.water, PokeType.fire));
    expect(Matchup.reason([PokeType.water, PokeType.flying], grass), (
      PokeType.flying,
      PokeType.grass,
    ));
    expect(Matchup.reason(fire, [PokeType.grass, PokeType.steel]), (
      PokeType.fire,
      PokeType.grass,
    ));
  });
}
