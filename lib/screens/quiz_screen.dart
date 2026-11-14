import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/pokemon.dart';
import '../providers/quiz_controller.dart';
import '../providers/settings_provider.dart';
import '../providers/sound_provider.dart';
import 'result_screen.dart';
import 'route_names.dart';
import 'widgets/answer_effect.dart';
import 'widgets/choice_button.dart';
import 'widgets/pokemon_image.dart';
import 'widgets/timer_bar.dart';

/// クイズ画面：状態は QuizController が持ち、この画面は表示とタップの受付だけ
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: 状態が変わるたびに build し直す
    final state = ref.watch(quizControllerProvider);

    // listen: 状態の変化を見て「画面遷移」など1回だけの処理をする
    ref.listen(quizControllerProvider, (prev, next) {
      // 答えた瞬間（時間切れも）に効果音
      if (next.status == QuizStatus.answered &&
          prev?.status != QuizStatus.answered) {
        final sound = ref.read(soundServiceProvider);
        next.selected?.id == next.current?.answer.id
            ? sound.playCorrect()
            : sound.playWrong();
      }
      if (next.status == QuizStatus.finished &&
          prev?.status != QuizStatus.finished) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: RouteNames.result),
            builder: (_) => ResultScreen(
              mode: ref.read(settingsProvider).mode,
              correctCount: next.correctCount,
              total: QuizController.questionCount,
              wrongPokemons: next.wrongPokemons,
            ),
          ),
        );
      }
    });

    return GradientBackground(
      colors: const [Color(0xFFB3E5FC), AppColors.cream], // 空色 → クリーム色
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // 小さい画面でもタイトルが「…」で切れないよう、入りきらなければ縮める
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('このポケモン だーれだ？'),
          ),
        ),
        body: SafeArea(child: _buildBody(context, ref, state)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, QuizState state) {
    if (state.status == QuizStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 96, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'よみこみに しっぱいしました',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: ref.read(quizControllerProvider.notifier).retry,
                child: const Text('もういちど'),
              ),
            ],
          ),
        ),
      );
    }

    final question = state.current;
    if (state.status == QuizStatus.loading || question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final answered = state.status == QuizStatus.answered;
    final isCorrect = state.selected?.id == question.answer.id;
    final isTimeUp = answered && state.selected == null;
    // iPhone SE など縦が短い画面では、ボタンとすき間を小さくして画像の場所を広げる
    final compact = context.isCompactHeight;
    final gap = compact ? 8.0 : 12.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          ProgressDots(
            total: QuizController.questionCount,
            current: state.questionNumber,
            results: state.results,
          ),
          SizedBox(height: gap),
          TimerBar(
            remainingSeconds: state.remainingSeconds,
            totalSeconds: QuizController.timeLimitSeconds,
          ),
          SizedBox(height: gap),
          // ポケモンの画像（白いカードの上）と、回答後の演出
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    // シルエットモードでも、答えたらカラーで答え合わせ
                    child: PokemonImage(
                      pokemon: question.answer,
                      mode: ref.watch(settingsProvider).mode,
                      revealed: answered,
                    ),
                  ),
                  if (answered)
                    // key に問題番号を入れて、問題ごとに演出を最初から動かす
                    AnswerEffect(
                      key: ValueKey(state.questionNumber),
                      correct: isCorrect,
                    ),
                ],
              ),
            ),
          ),
          // 回答後のメッセージ（高さを固定して、ボタンの位置がずれないようにする）
          SizedBox(
            height: compact ? 40 : 48,
            child: Center(
              child: answered
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isCorrect
                            ? 'せいかい！'
                            : '${isTimeUp ? 'じかんぎれ！ ' : ''}こたえは ${question.answer.name}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isCorrect
                              ? AppColors.correct
                              : AppColors.brown,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          for (final (i, p) in question.choices.indexed) ...[
            ChoiceButton(
              label: p.name,
              color: AppColors.choices[i % AppColors.choices.length],
              look: _choiceLook(state, p),
              height: compact ? 56 : 68,
              onPressed: answered
                  ? null
                  : () => ref.read(quizControllerProvider.notifier).answer(p),
            ),
            if (i < question.choices.length - 1) SizedBox(height: gap),
          ],
        ],
      ),
    );
  }

  /// 回答後は、正解を緑・間違えて選んだものを赤にして、ほかはうすくする
  ChoiceLook _choiceLook(QuizState state, Pokemon p) {
    if (state.status != QuizStatus.answered) return ChoiceLook.normal;
    if (p.id == state.current!.answer.id) return ChoiceLook.correct;
    if (p.id == state.selected?.id) return ChoiceLook.wrong;
    return ChoiceLook.faded;
  }
}
