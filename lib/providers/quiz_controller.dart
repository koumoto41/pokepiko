import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pokemon.dart';
import '../models/question.dart';
import 'data_providers.dart';
import 'settings_provider.dart';

/// クイズの状態を持つ Provider
/// autoDispose: クイズ画面を閉じたら状態を捨てる（次に開くと最初から）
final quizControllerProvider =
    NotifierProvider.autoDispose<QuizController, QuizState>(QuizController.new);

/// いまクイズがどの段階にいるか
enum QuizStatus { loading, answering, answered, finished, error }

/// クイズ画面に表示する状態（変更せず、毎回作り直して使う）
class QuizState {
  final QuizStatus status;
  final int questionNumber; // 何問目か（1〜10）
  final Question? current; // 表示中の問題
  final Pokemon? selected; // タップした選択肢（時間切れなら null のまま）
  final int remainingSeconds; // 残り時間（秒）
  final int correctCount; // 正解数
  final List<Pokemon> wrongPokemons; // 間違えた問題の正解ポケモン
  final List<bool> results; // 1問ごとの結果（true = 正解）。画面上の丸の色に使う
  final String? errorMessage;

  const QuizState({
    this.status = QuizStatus.loading,
    this.questionNumber = 0,
    this.current,
    this.selected,
    this.remainingSeconds = QuizController.timeLimitSeconds,
    this.correctCount = 0,
    this.wrongPokemons = const [],
    this.results = const [],
    this.errorMessage,
  });

  /// 一部だけ変えた新しい状態を作る
  /// （selected は null に戻したいことがあるので clearSelected で指定）
  QuizState copyWith({
    QuizStatus? status,
    int? questionNumber,
    Question? current,
    Pokemon? selected,
    bool clearSelected = false,
    int? remainingSeconds,
    int? correctCount,
    List<Pokemon>? wrongPokemons,
    List<bool>? results,
    String? errorMessage,
  }) {
    return QuizState(
      status: status ?? this.status,
      questionNumber: questionNumber ?? this.questionNumber,
      current: current ?? this.current,
      selected: clearSelected ? null : (selected ?? this.selected),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      correctCount: correctCount ?? this.correctCount,
      wrongPokemons: wrongPokemons ?? this.wrongPokemons,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 出題・回答判定・次の問題への切り替えを担当する
class QuizController extends Notifier<QuizState> {
  static const questionCount = 10; // 1ゲームの問題数
  static const timeLimitSeconds = 30; // 1問ごとの制限時間
  static const _nextDelay = Duration(seconds: 1); // 回答後、次の問題までの待ち時間

  final _random = Random();
  final _usedAnswerIds = <int>{}; // 同じポケモンを2回正解にしないため
  Future<Question>? _nextQuestion; // 裏で先に読み込んでおく次の問題
  Timer? _nextTimer; // 回答後、次の問題へ進むためのタイマー
  Timer? _countdownTimer; // 残り時間を1秒ずつ減らすタイマー
  List<int> _candidateIds = []; // 出題の候補（選んだ世代の図鑑番号）
  int _gameId = 0; // やり直すたびに増える番号。古いゲームの処理を無視するために使う
  bool _offline = false; // 一度ネットにつながらなかったら、そのゲーム中は保存済みだけで出す

  @override
  QuizState build() {
    // やり直し（retry）のときも build が呼ばれるので、前のゲームの続きを全部捨てる
    final gameId = ++_gameId;
    _usedAnswerIds.clear();
    _nextQuestion = null;
    _offline = false;

    // ゲーム中に設定は変わらないので、watch ではなく read で1回だけ読む
    _candidateIds = ref.read(settingsProvider).candidateIds;
    // Provider が捨てられる・作り直されるときにタイマーも止める
    ref.onDispose(() {
      _nextTimer?.cancel();
      _countdownTimer?.cancel();
    });
    // build の中では state を変えられないので、少し後で1問目を読み込む
    Future.microtask(() => _showNextQuestion(gameId));
    return const QuizState();
  }

  /// この処理が「いまのゲーム」のものか（画面が閉じられた・やり直した なら false）
  bool _isCurrentGame(int gameId) => ref.mounted && gameId == _gameId;

  /// 選択肢をタップしたとき
  void answer(Pokemon choice) => _finishQuestion(choice);

  /// 1問を終わらせる（choice が null なら時間切れ）
  void _finishQuestion(Pokemon? choice) {
    final question = state.current;
    if (state.status != QuizStatus.answering || question == null) return;
    _countdownTimer?.cancel();

    final isCorrect = choice?.id == question.answer.id;
    state = state.copyWith(
      status: QuizStatus.answered,
      selected: choice,
      correctCount: isCorrect ? state.correctCount + 1 : null,
      wrongPokemons: isCorrect
          ? null
          : [...state.wrongPokemons, question.answer],
      results: [...state.results, isCorrect],
    );

    // 1秒後に次の問題へ（最後の問題なら結果へ）
    _nextTimer = Timer(_nextDelay, () {
      if (state.questionNumber >= questionCount) {
        state = state.copyWith(status: QuizStatus.finished);
      } else {
        _showNextQuestion(_gameId);
      }
    });
  }

  /// エラーになったとき、最初からやり直す
  void retry() => ref.invalidateSelf();

  Future<void> _showNextQuestion(int gameId) async {
    if (!_isCurrentGame(gameId)) return;
    state = state.copyWith(status: QuizStatus.loading, clearSelected: true);
    try {
      final question = await (_nextQuestion ?? _createQuestion());
      // 待っている間に画面が閉じられた・やり直した ときは何もしない
      if (!_isCurrentGame(gameId)) return;
      _nextQuestion = null;

      state = state.copyWith(
        status: QuizStatus.answering,
        questionNumber: state.questionNumber + 1,
        current: question,
        remainingSeconds: timeLimitSeconds,
      );
      _startCountdown();

      // 子どもが考えている間に、次の問題を先に読み込んでおく
      if (state.questionNumber < questionCount) {
        // ignore(): 失敗してもここではエラー扱いにせず、使うときに await で受け取る
        _nextQuestion = _createQuestion()..ignore();
      }
    } catch (e) {
      if (!_isCurrentGame(gameId)) return;
      state = state.copyWith(status: QuizStatus.error, errorMessage: '$e');
    }
  }

  /// 1秒ごとに残り時間を減らし、0になったら時間切れ（不正解）にする
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remainingSeconds - 1;
      state = state.copyWith(remainingSeconds: remaining);
      if (remaining <= 0) _finishQuestion(null);
    });
  }

  /// 問題を1つ作る（正解1匹＋はずれ3匹、すべて別のポケモン）
  /// まずは普通に作り（保存済みのものは保存から読む）、
  /// ネットにつながらず失敗したら、保存済みのポケモンだけで作り直す
  Future<Question> _createQuestion() async {
    if (!_offline) {
      try {
        return await _createQuestionFrom(
          answerPool: _candidateIds,
          choicePool: _candidateIds,
        );
      } catch (_) {
        _offline = true;
      }
    }
    return _createOfflineQuestion();
  }

  /// 保存済みのポケモンだけで問題を作る
  Future<Question> _createOfflineQuestion() async {
    final repo = ref.read(pokemonRepositoryProvider);
    final cached = await repo.cachedIds();
    // はずれ用：名前が保存されていればよい
    final choicePool = _candidateIds.where(cached.contains).toList();
    if (choicePool.length < 4) throw const NotEnoughOfflineDataException();

    // 正解用：画像まで保存されているポケモンを、ランダムな順に探す
    final answerPool = [...choicePool]..shuffle(_random);
    for (final id in answerPool) {
      if (_usedAnswerIds.contains(id)) continue;
      if (!await repo.hasImages(await repo.getPokemon(id))) continue;
      return _createQuestionFrom(answerPool: [id], choicePool: choicePool);
    }
    throw const NotEnoughOfflineDataException();
  }

  /// answerPool から正解を、choicePool からはずれを選んで問題を作る
  Future<Question> _createQuestionFrom({
    required List<int> answerPool,
    required List<int> choicePool,
  }) async {
    int pick(List<int> pool) => pool[_random.nextInt(pool.length)];

    int answerId;
    do {
      answerId = pick(answerPool);
    } while (_usedAnswerIds.contains(answerId) && answerPool.length > 1);

    // Set は同じ値を入れても増えないので、重複しない4匹がそろう
    // はずれも正解と同じ世代の範囲から選ぶ
    final ids = <int>{answerId};
    while (ids.length < 4) {
      ids.add(pick(choicePool));
    }

    final repo = ref.read(pokemonRepositoryProvider);
    final pokemons = await Future.wait(ids.map(repo.getPokemon));
    final answer = pokemons.first; // Set は入れた順を保つので、先頭が正解
    // 問題を出す前に正解の画像を保存しておく（次からオフラインでも出せる）
    await repo.downloadImages(answer);

    _usedAnswerIds.add(answerId);
    return Question(answer: answer, choices: [...pokemons]..shuffle(_random));
  }
}

/// オフラインで、保存済みのポケモンが足りなくて問題を作れないとき
class NotEnoughOfflineDataException implements Exception {
  const NotEnoughOfflineDataException();

  @override
  String toString() => 'インターネットに つないでね\n（ほぞんされた ポケモンが たりません）';
}
