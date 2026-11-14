import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/settings_provider.dart';

import 'fakes.dart';

/// testWidgets の中では時間が「にせもの」になり、tester.pump(時間) で一瞬で進められる
/// （30秒の時間切れも待たずにテストできる）
void main() {
  late ProviderContainer container;
  late FakePokemonRepository repo;

  void setUpContainer({bool online = true}) {
    repo = FakePokemonRepository(online: online);
    container = ProviderContainer(
      overrides: [pokemonRepositoryProvider.overrideWithValue(repo)],
    );
    // autoDispose の Provider が勝手に捨てられないよう、見張っておく
    container.listen(quizControllerProvider, (_, _) {});
  }

  QuizState read() => container.read(quizControllerProvider);

  Future<void> waitUntilAnswering(WidgetTester tester) async {
    for (var i = 0; i < 100 && read().status != QuizStatus.answering; i++) {
      await tester.pump();
    }
    expect(read().status, QuizStatus.answering);
  }

  testWidgets('10問すべてに答えると結果になり、正解数と間違い一覧が正しい', (tester) async {
    setUpContainer();
    final answerIds = <int>{};

    for (var n = 1; n <= QuizController.questionCount; n++) {
      await waitUntilAnswering(tester);
      final q = read().current!;
      expect(read().questionNumber, n);

      // 選択肢は4つで重複なし、正解を含む
      expect(q.choices.map((p) => p.id).toSet().length, 4);
      expect(q.choices.any((p) => p.id == q.answer.id), isTrue);
      answerIds.add(q.answer.id);

      // 奇数問目は正解、偶数問目はわざと間違える
      final choice = n.isOdd
          ? q.answer
          : q.choices.firstWhere((p) => p.id != q.answer.id);
      container.read(quizControllerProvider.notifier).answer(choice);
      expect(read().status, QuizStatus.answered);

      // 1秒後に次へ進む
      await tester.pump(const Duration(seconds: 1));
    }

    expect(read().status, QuizStatus.finished);
    expect(read().correctCount, 5);
    expect(read().wrongPokemons.length, 5);
    expect(answerIds.length, QuizController.questionCount); // 正解は毎回ちがうポケモン
    container.dispose();
  });

  testWidgets('30秒たつと時間切れで不正解になり、次の問題へ進む', (tester) async {
    setUpContainer();
    await waitUntilAnswering(tester);
    final answer = read().current!.answer;

    await tester.pump(const Duration(seconds: 29));
    expect(read().status, QuizStatus.answering);
    expect(read().remainingSeconds, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(read().status, QuizStatus.answered);
    expect(read().selected, isNull);
    expect(read().wrongPokemons.map((p) => p.id), [answer.id]);

    // 1秒後に2問目が始まり、残り時間が30秒に戻る
    await tester.pump(const Duration(seconds: 1));
    await waitUntilAnswering(tester);
    expect(read().questionNumber, 2);
    expect(read().remainingSeconds, QuizController.timeLimitSeconds);
    container.dispose();
  });

  testWidgets('選んだ世代のポケモンだけが出題される', (tester) async {
    setUpContainer();
    // 第9世代（906〜1025）だけにしてから、クイズを作り直す
    container.read(settingsProvider.notifier)
      ..toggleGeneration(9)
      ..toggleGeneration(1);
    container.invalidate(quizControllerProvider);

    for (var n = 1; n <= QuizController.questionCount; n++) {
      await waitUntilAnswering(tester);
      for (final p in read().current!.choices) {
        expect(p.id, inInclusiveRange(906, 1025));
      }
      container
          .read(quizControllerProvider.notifier)
          .answer(read().current!.answer);
      await tester.pump(const Duration(seconds: 1));
    }
    container.dispose();
  });

  testWidgets('答えたらタイマーが止まる', (tester) async {
    setUpContainer();
    await waitUntilAnswering(tester);
    await tester.pump(const Duration(seconds: 5));
    container
        .read(quizControllerProvider.notifier)
        .answer(read().current!.answer);

    await tester.pump(const Duration(milliseconds: 900));
    expect(read().remainingSeconds, 25); // 答えた時点のまま
    container.dispose();
  });

  testWidgets('オフラインでも、画像まで保存済みのポケモンで出題できる', (tester) async {
    setUpContainer(online: false);
    // 第1世代のうち 1〜20番 を保存済みにしておく（画像は 1〜10番 だけ）
    repo.saved.addAll([for (var i = 1; i <= 20; i++) i]);
    repo.savedImages.addAll([for (var i = 1; i <= 10; i++) i]);

    final answers = <int>{};
    for (var n = 1; n <= QuizController.questionCount; n++) {
      await waitUntilAnswering(tester);
      final q = read().current!;
      expect(q.answer.id, inInclusiveRange(1, 10)); // 正解は画像ありだけ
      for (final p in q.choices) {
        expect(p.id, inInclusiveRange(1, 20)); // はずれも保存済みだけ
      }
      answers.add(q.answer.id);
      container.read(quizControllerProvider.notifier).answer(q.answer);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(answers.length, 10); // 同じポケモンは2回正解にならない
    expect(read().status, QuizStatus.finished);
    container.dispose();
  });

  testWidgets('オフラインで保存済みが足りないと、エラーでつなぐよう案内する', (tester) async {
    setUpContainer(online: false);
    repo.saved.addAll([1, 2, 3]); // 4匹そろわない
    for (var i = 0; i < 100 && read().status != QuizStatus.error; i++) {
      await tester.pump();
    }
    expect(read().status, QuizStatus.error);
    expect(read().errorMessage, contains('インターネットに つないでね'));
    container.dispose();
  });
}
