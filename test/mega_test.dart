import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/models/mega.dart';
import 'package:pokepiko/models/poke_type.dart';

/// tool/make_mega_list.py で PokéAPI から作った、メガシンカの一覧
void main() {
  test('リザードンは X と Y の2つ。タイプはメガシンカしたあとのもの', () {
    final megas = Mega.of(6);
    expect(megas.map((m) => m.id), [10034, 10035]);
    expect(megas.map((m) => m.name), ['メガリザードンX', 'メガリザードンY']);
    expect(megas[0].types, [PokeType.fire, PokeType.dragon]);
    expect(megas[1].types, [PokeType.fire, PokeType.flying]);
  });

  test('メガシンカしないポケモンは、からっぽ', () {
    expect(Mega.of(25), isEmpty); // ピカチュウ
    expect(Mega.of(1), isEmpty); // フシギダネ（メガシンカするのはフシギバナ）
  });

  test('名前はすべて「メガ」で始まり、X・Y・Z は半角にそろっている', () {
    final all = [for (var id = 1; id <= 1025; id++) ...Mega.of(id)];
    expect(all.length, greaterThan(90));
    for (final m in all) {
      expect(m.name, startsWith('メガ'));
      expect(m.name, isNot(matches(RegExp('[ＸＹＺ]'))));
      expect(m.types, isNotEmpty, reason: m.name);
      expect(m.id, greaterThan(10000), reason: m.name);
    }
  });
}
