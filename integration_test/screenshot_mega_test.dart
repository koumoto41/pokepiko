import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/screens/zukan_detail_screen.dart';

/// 図鑑のくわしいページの、メガシンカの欄のスクリーンショットを撮る
/// （図鑑の記録は書きかえず、くわしいページだけを直接出す）
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_mega_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('メガシンカの欄', (tester) async {
    // メガシンカが1つ（フシギバナ）・2つ（リザードン）・3つ（シャリタツ）
    for (final id in [3, 6, 978]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(id), // ポケモンごとに作り直す
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ZukanDetailScreen(id: id),
          ),
        ),
      );
      final title = find.text('メガシンカ');
      for (
        var i = 0;
        i < 100 && find.byType(ListView).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(
        title,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // メガシンカの欄が画面の上のほうに来るまで動かす
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await wait(tester, 3000); // 絵の読み込みを待つ
      await binding.takeScreenshot('mega_$id');
    }
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 1000);
  });
}
