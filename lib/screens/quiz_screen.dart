import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/question.dart';
import '../models/quiz_settings.dart';
import '../providers/quiz_controller.dart';
import '../providers/settings_provider.dart';
import '../providers/sound_provider.dart';
import 'result_screen.dart';
import 'route_names.dart';
import 'widgets/answer_effect.dart';
import 'widgets/choice_button.dart';
import 'widgets/image_choice.dart';
import 'widgets/pokemon_image.dart';
import 'widgets/timer_bar.dart';
import 'widgets/type_badge.dart';

/// クイズ画面：状態は QuizController が持ち、この画面は表示とタップの受付だけ
/// クイズの種類（なまえ／ポケモン→タイプ／タイプ→ポケモン）で、出しかたを変える
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  static const _titles = {
    QuizVariant.name: 'このポケモン だーれだ？',
    QuizVariant.pokemonToType: 'このポケモンの タイプは？',
    QuizVariant.typeToPokemon: 'このタイプの ポケモンは？',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: 状態が変わるたびに build し直す
    final state = ref.watch(quizControllerProvider);
    final settings = ref.watch(settingsProvider);

    // listen: 状態の変化を見て「画面遷移」など1回だけの処理をする
    ref.listen(quizControllerProvider, (prev, next) {
      // 答えた瞬間（時間切れも）に効果音
      if (next.status == QuizStatus.answered &&
          prev?.status != QuizStatus.answered) {
        final sound = ref.read(soundServiceProvider);
        next.isCorrect ? sound.playCorrect() : sound.playWrong();
      }
      if (next.status == QuizStatus.finished &&
          prev?.status != QuizStatus.finished) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: RouteNames.result),
            builder: (_) => ResultScreen(
              variant: settings.variant,
              mode: settings.mode,
              correctCount: next.correctCount,
              total: QuizController.questionCount,
              wrongPokemons: next.wrongPokemons,
              newlyFound: next.newlyFound.length,
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
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_titles[settings.variant]!),
          ),
        ),
        body: SafeArea(child: _buildBody(context, ref, state, settings.mode)),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    QuizState state,
    QuizMode mode,
  ) {
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
    // iPhone SE など縦が短い画面では、ボタンとすき間を小さくして画像の場所を広げる
    final compact = context.isCompactHeight;
    final gap = compact ? 8.0 : 12.0;
    void onChoose(int i) => ref.read(quizControllerProvider.notifier).answer(i);

    // 回答後の〇×と星（key に問題番号を入れて、問題ごとに最初から動かす）
    final effect = answered
        ? AnswerEffect(
            key: ValueKey(state.questionNumber),
            correct: state.isCorrect,
          )
        : null;

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
          if (question.variant == QuizVariant.typeToPokemon) ...[
            // タイプ→ポケモン：上に聞くタイプ、下に4匹の絵
            TypeBadge(type: question.askedType!, fontSize: compact ? 28 : 34),
            SizedBox(height: gap),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _ImageChoiceGrid(
                    question: question,
                    state: state,
                    mode: mode,
                    gap: gap,
                    onChoose: answered ? null : onChoose,
                  ),
                  ?effect,
                ],
              ),
            ),
            _Message(state: state, height: compact ? 40 : 48),
          ] else ...[
            // なまえ・ポケモン→タイプ：上にポケモンの絵、下に4つのボタン
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
                        pokemon: question.pokemon,
                        mode: mode,
                        revealed: answered,
                      ),
                    ),
                    ?effect,
                  ],
                ),
              ),
            ),
            _Message(state: state, height: compact ? 40 : 48),
            for (var i = 0; i < question.choiceCount; i++) ...[
              _buildChoiceButton(question, state, i, compact, onChoose),
              if (i < question.choiceCount - 1) SizedBox(height: gap),
            ],
          ],
        ],
      ),
    );
  }

  /// 文字のボタン（なまえクイズは名前、ポケモン→タイプはタイプ）
  Widget _buildChoiceButton(
    Question question,
    QuizState state,
    int i,
    bool compact,
    void Function(int) onChoose,
  ) {
    final isType = question.typeChoices.isNotEmpty;
    return ChoiceButton(
      // タイプはそのタイプの色、名前は4色を順番に使う
      label: isType
          ? question.typeChoices[i].label
          : question.pokemonChoices[i].name,
      color: isType
          ? question.typeChoices[i].color
          : AppColors.choices[i % AppColors.choices.length],
      keepColorWhenCorrect: isType,
      look: _choiceLook(state, i),
      height: compact ? 56 : 68,
      onPressed: state.status == QuizStatus.answered ? null : () => onChoose(i),
    );
  }
}

/// 回答後は、正解を緑・間違えて選んだものを赤にして、ほかはうすくする
ChoiceLook _choiceLook(QuizState state, int i) {
  if (state.status != QuizStatus.answered) return ChoiceLook.normal;
  if (i == state.current!.correctIndex) return ChoiceLook.correct;
  if (i == state.selectedIndex) return ChoiceLook.wrong;
  return ChoiceLook.faded;
}

/// タイプ→ポケモン：4匹の絵を 2×2 に並べる
class _ImageChoiceGrid extends StatelessWidget {
  final Question question;
  final QuizState state;
  final QuizMode mode;
  final double gap;
  final void Function(int)? onChoose; // null だと押せない

  const _ImageChoiceGrid({
    required this.question,
    required this.state,
    required this.mode,
    required this.gap,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell(int i) => Expanded(
      child: ImageChoice(
        pokemon: question.pokemonChoices[i],
        mode: mode,
        look: _choiceLook(state, i),
        onPressed: onChoose == null ? null : () => onChoose!(i),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              cell(0),
              SizedBox(width: gap),
              cell(1),
            ],
          ),
        ),
        SizedBox(height: gap),
        Expanded(
          child: Row(
            children: [
              cell(2),
              SizedBox(width: gap),
              cell(3),
            ],
          ),
        ),
      ],
    );
  }
}

/// 回答後のメッセージ（高さを固定して、ボタンの位置がずれないようにする）
class _Message extends StatelessWidget {
  final QuizState state;
  final double height;

  const _Message({required this.state, required this.height});

  @override
  Widget build(BuildContext context) {
    final question = state.current!;
    final answered = state.status == QuizStatus.answered;
    final isTimeUp = answered && state.selectedIndex == null;
    final pokemon = question.pokemon;

    final text = switch (question.variant) {
      QuizVariant.name => state.isCorrect ? 'せいかい！' : 'こたえは ${pokemon.name}',
      // タイプは2つあることもあるので、両方教える
      QuizVariant.pokemonToType =>
        '${state.isCorrect ? 'せいかい！ ' : ''}'
            '${pokemon.name}は ${pokemon.types.map((t) => t.label).join('・')}',
      QuizVariant.typeToPokemon =>
        state.isCorrect ? 'せいかい！' : 'こたえは ${pokemon.name}',
    };

    return SizedBox(
      height: height,
      child: Center(
        child: answered
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isTimeUp ? 'じかんぎれ！ ' : ''}$text',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: state.isCorrect
                        ? AppColors.correct
                        : AppColors.brown,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
