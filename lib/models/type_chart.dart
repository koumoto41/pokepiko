// このファイルは tool/make_type_chart.py で作ったもの（手で直さない）
// PokéAPI の /type/{name} の damage_relations から集めたタイプ相性

import 'poke_type.dart';

/// タイプ相性（攻撃するわざのタイプ → 受けるポケモンのタイプ → 倍率）
abstract final class TypeChart {
  // ここに書いていない組み合わせは 1倍
  static const _chart = <PokeType, Map<PokeType, double>>{
    PokeType.normal: {
      PokeType.rock: 0.5,
      PokeType.steel: 0.5,
      PokeType.ghost: 0,
    },
    PokeType.fire: {
      PokeType.bug: 2,
      PokeType.steel: 2,
      PokeType.grass: 2,
      PokeType.ice: 2,
      PokeType.rock: 0.5,
      PokeType.fire: 0.5,
      PokeType.water: 0.5,
      PokeType.dragon: 0.5,
    },
    PokeType.water: {
      PokeType.ground: 2,
      PokeType.rock: 2,
      PokeType.fire: 2,
      PokeType.water: 0.5,
      PokeType.grass: 0.5,
      PokeType.dragon: 0.5,
    },
    PokeType.grass: {
      PokeType.ground: 2,
      PokeType.rock: 2,
      PokeType.water: 2,
      PokeType.flying: 0.5,
      PokeType.poison: 0.5,
      PokeType.bug: 0.5,
      PokeType.steel: 0.5,
      PokeType.fire: 0.5,
      PokeType.grass: 0.5,
      PokeType.dragon: 0.5,
    },
    PokeType.electric: {
      PokeType.flying: 2,
      PokeType.water: 2,
      PokeType.grass: 0.5,
      PokeType.electric: 0.5,
      PokeType.dragon: 0.5,
      PokeType.ground: 0,
    },
    PokeType.ice: {
      PokeType.flying: 2,
      PokeType.ground: 2,
      PokeType.grass: 2,
      PokeType.dragon: 2,
      PokeType.steel: 0.5,
      PokeType.fire: 0.5,
      PokeType.water: 0.5,
      PokeType.ice: 0.5,
    },
    PokeType.fighting: {
      PokeType.normal: 2,
      PokeType.rock: 2,
      PokeType.steel: 2,
      PokeType.ice: 2,
      PokeType.dark: 2,
      PokeType.flying: 0.5,
      PokeType.poison: 0.5,
      PokeType.bug: 0.5,
      PokeType.psychic: 0.5,
      PokeType.fairy: 0.5,
      PokeType.ghost: 0,
    },
    PokeType.poison: {
      PokeType.grass: 2,
      PokeType.fairy: 2,
      PokeType.poison: 0.5,
      PokeType.ground: 0.5,
      PokeType.rock: 0.5,
      PokeType.ghost: 0.5,
      PokeType.steel: 0,
    },
    PokeType.ground: {
      PokeType.poison: 2,
      PokeType.rock: 2,
      PokeType.steel: 2,
      PokeType.fire: 2,
      PokeType.electric: 2,
      PokeType.bug: 0.5,
      PokeType.grass: 0.5,
      PokeType.flying: 0,
    },
    PokeType.flying: {
      PokeType.fighting: 2,
      PokeType.bug: 2,
      PokeType.grass: 2,
      PokeType.rock: 0.5,
      PokeType.steel: 0.5,
      PokeType.electric: 0.5,
    },
    PokeType.psychic: {
      PokeType.fighting: 2,
      PokeType.poison: 2,
      PokeType.steel: 0.5,
      PokeType.psychic: 0.5,
      PokeType.dark: 0,
    },
    PokeType.bug: {
      PokeType.grass: 2,
      PokeType.psychic: 2,
      PokeType.dark: 2,
      PokeType.fighting: 0.5,
      PokeType.flying: 0.5,
      PokeType.poison: 0.5,
      PokeType.ghost: 0.5,
      PokeType.steel: 0.5,
      PokeType.fire: 0.5,
      PokeType.fairy: 0.5,
    },
    PokeType.rock: {
      PokeType.flying: 2,
      PokeType.bug: 2,
      PokeType.fire: 2,
      PokeType.ice: 2,
      PokeType.fighting: 0.5,
      PokeType.ground: 0.5,
      PokeType.steel: 0.5,
    },
    PokeType.ghost: {
      PokeType.ghost: 2,
      PokeType.psychic: 2,
      PokeType.dark: 0.5,
      PokeType.normal: 0,
    },
    PokeType.dragon: {
      PokeType.dragon: 2,
      PokeType.steel: 0.5,
      PokeType.fairy: 0,
    },
    PokeType.dark: {
      PokeType.ghost: 2,
      PokeType.psychic: 2,
      PokeType.fighting: 0.5,
      PokeType.dark: 0.5,
      PokeType.fairy: 0.5,
    },
    PokeType.steel: {
      PokeType.rock: 2,
      PokeType.ice: 2,
      PokeType.fairy: 2,
      PokeType.steel: 0.5,
      PokeType.fire: 0.5,
      PokeType.water: 0.5,
      PokeType.electric: 0.5,
    },
    PokeType.fairy: {
      PokeType.fighting: 2,
      PokeType.dragon: 2,
      PokeType.dark: 2,
      PokeType.poison: 0.5,
      PokeType.steel: 0.5,
      PokeType.fire: 0.5,
    },
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
