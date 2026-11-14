import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/models/question.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/settings_provider.dart';

import 'fakes.dart';

/// testWidgets の中では時間が「にせもの」になり、tester.pump(時間) で一瞬で進められる
/// （30秒の時間切れも待たずにテストできる）
void main() {
  late ProviderContainer container;
  late FakePokemonRepository repo;

  /// variant：遊ぶクイズの種類（設定を変えてからクイズを始める）
  void setUpContainer({
    bool online = true,
    QuizVariant variant = QuizVariant.name,
  }) {
    repo = FakePokemonRepository(online: online);
    container = ProviderContainer(
      overrides: [pokemonRepositoryProvider.overrideWithValue(repo)],
    );
    final settings = container.read(settingsProvider.notifier);
    switch (variant) {
      case QuizVariant.name:
        settings.setKind(QuizKind.name);
      case QuizVariant.pokemonToType:
        settings
          ..setKind(QuizKind.type)
          ..setTypeDirection(TypeDirection.pokemonToType);
      case QuizVariant.typeToPokemon:
        settings
          ..setKind(QuizKind.type)
          ..setTypeDirection(TypeDirection.typeToPokemon);
    }
    // autoDispose の Provider が勝手に捨てられないよう、見張っておく
    container.listen(quizControllerProvider, (_, _) {});
  }

  QuizState read() => container.read(quizControllerProvider);
  Question question() => read().current!;
  void answer(int index) =>
      container.read(quizControllerProvider.notifier).answer(index);
  int wrongIndex() => (question().correctIndex + 1) % 4;

  Future<void> waitUntilAnswering(WidgetTester tester) async {
    for (var i = 0; i < 100 && read().status != QuizStatus.answering; i++) {
      await tester.pump();
    }
    expect(read().status, QuizStatus.answering);
  }

  /// 10問を、check で中身を確かめながら正解して進める
  Future<void> playAll(
    WidgetTester tester,
    void Function(Question q) check,
  ) async {
    for (var n = 1; n <= QuizController.questionCount; n++) {
      await waitUntilAnswering(tester);
      check(question());
      answer(question().correctIndex);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(read().status, QuizStatus.finished);
  }

  group('なまえクイズ', () {
    testWidgets('10問すべてに答えると結果になり、正解数と間違い一覧が正しい', (tester) async {
      setUpContainer();
      final answerIds = <int>{};

      for (var n = 1; n <= QuizController.questionCount; n++) {
        await waitUntilAnswering(tester);
        final q = question();
        expect(read().questionNumber, n);

        // 選択肢は4匹で重複なし、正解の位置に主役のポケモンがいる
        expect(q.pokemonChoices.map((p) => p.id).toSet().length, 4);
        expect(q.pokemonChoices[q.correctIndex].id, q.pokemon.id);
        answerIds.add(q.pokemon.id);

        // 奇数問目は正解、偶数問目はわざと間違える
        answer(n.isOdd ? q.correctIndex : wrongIndex());
        expect(read().status, QuizStatus.answered);
        expect(read().isCorrect, n.isOdd);

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
      final pokemon = question().pokemon;

      await tester.pump(const Duration(seconds: 29));
      expect(read().status, QuizStatus.answering);
      expect(read().remainingSeconds, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(read().status, QuizStatus.answered);
      expect(read().selectedIndex, isNull);
      expect(read().isCorrect, isFalse);
      expect(read().wrongPokemons.map((p) => p.id), [pokemon.id]);

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

      await playAll(tester, (q) {
        for (final p in q.pokemonChoices) {
          expect(p.id, inInclusiveRange(906, 1025));
        }
      });
      container.dispose();
    });

    testWidgets('答えたらタイマーが止まる', (tester) async {
      setUpContainer();
      await waitUntilAnswering(tester);
      await tester.pump(const Duration(seconds: 5));
      answer(question().correctIndex);

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
      await playAll(tester, (q) {
        expect(q.pokemon.id, inInclusiveRange(1, 10)); // 正解は画像ありだけ
        for (final p in q.pokemonChoices) {
          expect(p.id, inInclusiveRange(1, 20)); // はずれも保存済みだけ
        }
        answers.add(q.pokemon.id);
      });
      expect(answers.length, 10); // 同じポケモンは2回正解にならない
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
  });

  group('タイプクイズ（ポケモン→タイプ）', () {
    testWidgets('正解はそのポケモンのタイプ1つだけで、はずれは持っていないタイプ', (tester) async {
      setUpContainer(variant: QuizVariant.pokemonToType);
      var sawDualType = false;

      await playAll(tester, (q) {
        expect(q.variant, QuizVariant.pokemonToType);
        expect(q.typeChoices.length, 4);
        expect(q.typeChoices.toSet().length, 4); // 同じタイプは出ない
        // 選択肢のうち、ポケモンが持っているタイプはちょうど1つ（＝正解）
        final owned = [
          for (final (i, t) in q.typeChoices.indexed)
            if (q.pokemon.types.contains(t)) i,
        ];
        expect(owned, [q.correctIndex]);
        if (q.pokemon.types.length == 2) sawDualType = true;
      });
      // 2タイプのポケモンも出題されている（3の倍数の番号は2タイプ）
      expect(sawDualType, isTrue);
      container.dispose();
    });

    testWidgets('間違えたら、そのポケモンが「おぼえてね」に入る', (tester) async {
      setUpContainer(variant: QuizVariant.pokemonToType);
      await waitUntilAnswering(tester);
      final pokemon = question().pokemon;
      answer(wrongIndex());
      expect(read().isCorrect, isFalse);
      expect(read().wrongPokemons.single.id, pokemon.id);
      container.dispose();
    });
  });

  group('タイプクイズ（タイプ→ポケモン）', () {
    testWidgets('聞いたタイプを持つポケモンは、選択肢の中で正解の1匹だけ', (tester) async {
      setUpContainer(variant: QuizVariant.typeToPokemon);

      await playAll(tester, (q) {
        expect(q.variant, QuizVariant.typeToPokemon);
        final asked = q.askedType!;
        expect(q.pokemon.types, contains(asked));
        expect(q.pokemonChoices.map((p) => p.id).toSet().length, 4);
        final having = [
          for (final (i, p) in q.pokemonChoices.indexed)
            if (p.types.contains(asked)) i,
        ];
        expect(having, [q.correctIndex]);
      });
      container.dispose();
    });

    testWidgets('オフラインでは、4匹とも画像が保存済みのポケモンから出す', (tester) async {
      setUpContainer(online: false, variant: QuizVariant.typeToPokemon);
      repo.saved.addAll([for (var i = 1; i <= 60; i++) i]);
      repo.savedImages.addAll([for (var i = 1; i <= 40; i++) i]);

      await playAll(tester, (q) {
        for (final p in q.pokemonChoices) {
          expect(repo.savedImages, contains(p.id)); // 絵で選ぶので全部画像が必要
        }
      });
      container.dispose();
    });
  });
}
