import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/models/poke_type.dart';
import 'package:pokepiko/models/type_chart.dart';
import 'package:pokepiko/screens/type_chart_screen.dart';
import 'package:pokepiko/screens/widgets/type_badge.dart';

/// tool/make_type_chart.py で PokéAPI から作った一覧と、相性表の画面
void main() {
  group('相性のデータ', () {
    test('よく知られた相性のとおり', () {
      expect(TypeChart.multiplier(PokeType.fire, PokeType.grass), 2);
      expect(TypeChart.multiplier(PokeType.water, PokeType.fire), 2);
      expect(TypeChart.multiplier(PokeType.fire, PokeType.water), 0.5);
      expect(TypeChart.multiplier(PokeType.normal, PokeType.ghost), 0);
      expect(TypeChart.multiplier(PokeType.ghost, PokeType.normal), 0);
      expect(TypeChart.multiplier(PokeType.dragon, PokeType.fairy), 0);
      expect(TypeChart.multiplier(PokeType.electric, PokeType.ground), 0);
      expect(TypeChart.multiplier(PokeType.normal, PokeType.normal), 1);
    });

    test('ほのおの わざが ばつぐんなのは、くさ・こおり・むし・はがね', () {
      expect(TypeChart.targets(PokeType.fire, 2).toSet(), {
        PokeType.grass,
        PokeType.ice,
        PokeType.bug,
        PokeType.steel,
      });
    });

    test('ほのおタイプが にがてなのは、みず・じめん・いわ', () {
      expect(TypeChart.attackers(PokeType.fire, 2).toSet(), {
        PokeType.water,
        PokeType.ground,
        PokeType.rock,
      });
    });

    test('倍率は 2・1・0.5・0 のどれか', () {
      for (final a in PokeType.values) {
        for (final d in PokeType.values) {
          expect([2, 1, 0.5, 0], contains(TypeChart.multiplier(a, d)));
        }
      }
    });
  });

  group('相性表の画面', () {
    const sizes = {
      'iPhone SE': Size(375, 667),
      'iPhone 18 Pro Max': Size(440, 956),
    };

    Future<void> pumpScreen(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TypeChartScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('$name: えらんで みる（はじめは ほのお）', (tester) async {
        await pumpScreen(tester, size);
        expect(find.text('ほのおの わざで こうげきすると…'), findsOneWidget);
        expect(find.text('ほのおタイプの ポケモンが うけると…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$name: ひょう（18×18）', (tester) async {
        await pumpScreen(tester, size);
        await tester.tap(find.text('ひょう'));
        await tester.pumpAndSettle();
        expect(find.text('たて：こうげきする わざ'), findsOneWidget);
        // ◎ は「2倍」のマスの数だけある（見えているところ）
        expect(find.text('◎'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('タイプを選ぶと、相手のタイプが切りかわる', (tester) async {
      await pumpScreen(tester, sizes['iPhone SE']!);
      // みず を選ぶ（ボタンの中の「みず」は、選択肢の一覧の先頭にある）
      await tester.tap(find.widgetWithText(TypeBadge, 'みず').first);
      await tester.pumpAndSettle();
      expect(find.text('みずの わざで こうげきすると…'), findsOneWidget);
      expect(find.text('みずタイプの ポケモンが うけると…'), findsOneWidget);
    });

    testWidgets('ノーマルは「こうかなし」の相手（ゴースト）がいて、いない欄は「なし」', (tester) async {
      await pumpScreen(tester, sizes['iPhone SE']!);
      await tester.tap(find.widgetWithText(TypeBadge, 'ノーマル').first);
      await tester.pumpAndSettle();
      // ノーマルのわざは ばつぐんの相手がいない
      expect(find.text('　なし'), findsWidgets);
    });
  });
}
