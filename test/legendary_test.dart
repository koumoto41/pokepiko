import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/models/generation.dart';
import 'package:pokepiko/models/legendary.dart';

/// tool/make_legendary_list.py で PokéAPI から作った一覧が、おかしくないか
void main() {
  test('伝説71匹・幻23匹で、重なりはない', () {
    expect(Legendary.legendary.length, 71);
    expect(Legendary.mythical.length, 23);
    expect(Legendary.legendary.intersection(Legendary.mythical), isEmpty);
    expect(Legendary.all.length, 94);
  });

  test('API で確かめた例のとおり', () {
    expect(Legendary.isLegendary(144), isTrue); // フリーザー
    expect(Legendary.isLegendary(150), isTrue); // ミュウツー
    expect(Legendary.isMythical(151), isTrue); // ミュウ
    expect(Legendary.isMythical(1025), isTrue); // モモワロウ
    expect(Legendary.isSpecial(25), isFalse); // ピカチュウ
    expect(Legendary.isSpecial(172), isFalse); // ピチュー（ベイビィ）
  });

  test('どれも全国図鑑の範囲に入っている', () {
    for (final id in Legendary.all) {
      expect(id, inInclusiveRange(1, Generation.all.last.lastId));
    }
  });
}
