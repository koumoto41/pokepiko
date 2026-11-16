import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/widgets/type_badge.dart';

/// タイトル画面から「タイプ」を開き、タイプの相性の2つのタブを撮る
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_type_chart_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('タイプの相性', (tester) async {
    await app.main();
    for (var i = 0; i < 100 && find.text('タイプ').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await wait(tester, 2000);
    await binding.takeScreenshot('tc01_title');

    await tester.tap(find.text('タイプ'));
    await wait(tester, 1500);
    await binding.takeScreenshot('tc02_pick_fire');

    // ゴーストを選ぶ（こうかなし の相手がいる）
    await tester.tap(find.widgetWithText(TypeBadge, 'ゴースト').first);
    await wait(tester, 800);
    await binding.takeScreenshot('tc03_pick_ghost');

    await tester.tap(find.text('ひょう'));
    await wait(tester, 1500);
    await binding.takeScreenshot('tc04_table');

    // 表を左にスクロールして、右のほうを見る
    await tester.drag(find.text('◎').first, const Offset(-300, 0));
    await wait(tester, 1000);
    await binding.takeScreenshot('tc05_table_right');

    await ProviderScope.containerOf(tester.element(find.text('ひょう')))
        .read(soundServiceProvider)
        .stopBgm();
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 2000);
  });
}
