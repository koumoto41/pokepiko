import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poke_type.dart';
import '../models/pokemon.dart';
import '../models/question.dart';
import '../models/score.dart';
import '../models/quiz_settings.dart';
import 'collection_provider.dart';
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
  final int? selectedIndex; // タップした選択肢の位置（時間切れなら null のまま）
  final int remainingSeconds; // 残り時間（秒）
  final int correctCount; // 正解数
  final List<Pokemon> wrongPokemons; // 間違えた問題の主役のポケモン
  final List<bool> results; // 1問ごとの結果（true = 正解）。画面上の丸の色に使う
  final List<Pokemon> newlyFound; // このゲームで、図鑑にはじめて入ったポケモン
  final Score score; // ここまでの点数
  final int streak; // いま何問つづけて正解しているか
  final Score? lastPoints; // 直前の問題で取った点数（正解したときだけ。画面にぴょこっと出す）
  final String? errorMessage;

  const QuizState({
    this.status = QuizStatus.loading,
    this.questionNumber = 0,
    this.current,
    this.selectedIndex,
    this.remainingSeconds = QuizController.timeLimitSeconds,
    this.correctCount = 0,
    this.wrongPokemons = const [],
    this.results = const [],
    this.newlyFound = const [],
    this.score = const Score(),
    this.streak = 0,
    this.lastPoints,
    this.errorMessage,
  });

  /// 一部だけ変えた新しい状態を作る
  /// （selectedIndex は null に戻したいことがあるので clearSelected で指定）
  QuizState copyWith({
    QuizStatus? status,
    int? questionNumber,
    Question? current,
    int? selectedIndex,
    bool clearSelected = false,
    int? remainingSeconds,
    int? correctCount,
    List<Pokemon>? wrongPokemons,
    List<bool>? results,
    List<Pokemon>? newlyFound,
    Score? score,
    int? streak,
    Score? lastPoints,
    bool clearLastPoints = false,
    String? errorMessage,
  }) {
    return QuizState(
      status: status ?? this.status,
      questionNumber: questionNumber ?? this.questionNumber,
      current: current ?? this.current,
      selectedIndex: clearSelected
          ? null
          : (selectedIndex ?? this.selectedIndex),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      correctCount: correctCount ?? this.correctCount,
      wrongPokemons: wrongPokemons ?? this.wrongPokemons,
      results: results ?? this.results,
      newlyFound: newlyFound ?? this.newlyFound,
      score: score ?? this.score,
      streak: streak ?? this.streak,
      lastPoints: clearLastPoints ? null : (lastPoints ?? this.lastPoints),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 答えた選択肢が正解か（時間切れは false）
  bool get isCorrect =>
      selectedIndex != null && selectedIndex == current?.correctIndex;
}

/// 出題・回答判定・次の問題への切り替えを担当する
class QuizController extends Notifier<QuizState> {
  static const questionCount = 10; // 1ゲームの問題数
  static const timeLimitSeconds = 30; // 1問ごとの制限時間
  static const _nextDelay = Duration(seconds: 1); // 回答後、次の問題までの待ち時間
  static const _maxOnlineTries = 40; // 条件に合うポケモンを探すとき、ネットから取る数の上限

  final _random = Random();
  final _usedAnswerIds = <int>{}; // 同じポケモンを2回正解にしないため
  Future<Question>? _nextQuestion; // 裏で先に読み込んでおく次の問題
  Timer? _nextTimer; // 回答後、次の問題へ進むためのタイマー
  Timer? _countdownTimer; // 残り時間を1秒ずつ減らすタイマー
  List<int> _candidateIds = []; // 出題の候補（選んだ世代の図鑑番号）
  QuizVariant _variant = QuizVariant.name; // 遊んでいるクイズの種類
  bool _collects = false; // 正解したポケモンを図鑑に入れるか（シルエットのときだけ）
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
    final settings = ref.read(settingsProvider);
    _candidateIds = settings.candidateIds;
    _variant = settings.variant;
    _collects = settings.mode == QuizMode.silhouette;
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

  /// 選択肢をタップしたとき（index: 何番目の選択肢か）
  void answer(int index) => _finishQuestion(index);

  /// 1問を終わらせる（index が null なら時間切れ）
  void _finishQuestion(int? index) {
    final question = state.current;
    if (state.status != QuizStatus.answering || question == null) return;
    _countdownTimer?.cancel();

    final isCorrect = index == question.correctIndex;
    // 点数：正解なら「せいかい＋はやさ＋れんぞく」を足す。間違い・時間切れは0点で連続も切れる
    final streak = isCorrect ? state.streak + 1 : 0;
    final points = isCorrect
        ? Score.forAnswer(
            remainingSeconds: state.remainingSeconds,
            streak: streak,
          )
        : null;
    state = state.copyWith(
      status: QuizStatus.answered,
      score: points == null ? null : state.score + points,
      streak: streak,
      lastPoints: points,
      clearLastPoints: points == null,
      selectedIndex: index,
      correctCount: isCorrect ? state.correctCount + 1 : null,
      wrongPokemons: isCorrect
          ? null
          : [...state.wrongPokemons, question.pokemon],
      results: [...state.results, isCorrect],
    );

    // 図鑑に入るのは、シルエットで正解したときだけ（影だけで当てたごほうび）
    if (isCorrect && _collects) _collect(question.pokemon);

    // 1秒後に次の問題へ（最後の問題なら結果へ）
    _nextTimer = Timer(_nextDelay, () {
      if (state.questionNumber >= questionCount) {
        // 全問正解なら、パーフェクトボーナス
        final perfect = state.correctCount >= questionCount;
        state = state.copyWith(
          status: QuizStatus.finished,
          score: perfect
              ? state.score + const Score(perfect: Score.perfectPoints)
              : null,
        );
      } else {
        _showNextQuestion(_gameId);
      }
    });
  }

  /// 正解したポケモンを図鑑に記録する（結果を待たずにクイズは進める）
  Future<void> _collect(Pokemon pokemon) async {
    final gameId = _gameId;
    // await のあいだに画面が閉じられると ref が使えなくなるので、先に取り出しておく
    final collection = ref.read(collectionProvider.notifier);
    final repo = ref.read(pokemonRepositoryProvider);

    // 図鑑のくわしいページと鳴き声も、オフラインで見られるように保存しておく
    // （失敗しても、図鑑を開いたときにもう一度取りにいくので、ここでは気にしない）
    repo.downloadDex(pokemon.id).ignore();

    final isNew = await collection.add(pokemon.id);
    if (isNew && _isCurrentGame(gameId)) {
      state = state.copyWith(newlyFound: [...state.newlyFound, pokemon]);
    }
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

  /// 問題を1つ作る
  /// まずは普通に作り（保存済みのものは保存から読む）、
  /// ネットにつながらず失敗したら、保存済みのポケモンだけで作り直す
  Future<Question> _createQuestion() async {
    if (!_offline) {
      try {
        return await _createQuestionFrom(_candidateIds, offline: false);
      } catch (_) {
        _offline = true;
      }
    }
    final cached = await ref.read(pokemonRepositoryProvider).cachedIds();
    final pool = _candidateIds.where(cached.contains).toList();
    if (pool.length < 4) throw const NotEnoughOfflineDataException();
    return _createQuestionFrom(pool, offline: true);
  }

  Future<Question> _createQuestionFrom(
    List<int> pool, {
    required bool offline,
  }) async {
    final question = await switch (_variant) {
      QuizVariant.name => _createNameQuestion(pool, offline),
      QuizVariant.pokemonToType => _createPokemonToTypeQuestion(pool, offline),
      QuizVariant.typeToPokemon => _createTypeToPokemonQuestion(pool, offline),
    };
    _usedAnswerIds.add(question.pokemon.id);
    return question;
  }

  /// なまえクイズ：ポケモンの絵を見せて、4つの名前から選ぶ
  Future<Question> _createNameQuestion(List<int> pool, bool offline) async {
    final answer = await _pickPokemon(
      pool,
      offline: offline,
      needImages: true,
      exclude: _usedAnswerIds,
    );
    // はずれの3匹は名前だけ使うので、画像はいらない
    final others = <Pokemon>[];
    for (var i = 0; i < 3; i++) {
      others.add(
        await _pickPokemon(
          pool,
          offline: offline,
          needImages: false,
          exclude: {answer.id, for (final p in others) p.id},
        ),
      );
    }
    final choices = [answer, ...others]..shuffle(_random);
    return Question(
      variant: QuizVariant.name,
      pokemon: answer,
      pokemonChoices: choices,
      correctIndex: choices.indexOf(answer),
    );
  }

  /// ポケモン→タイプ：ポケモンの絵を見せて、4つのタイプから選ぶ
  /// 2つのタイプを持つポケモンは、どちらか1つだけを選択肢に入れる（両方入れると正解が2つになる）
  Future<Question> _createPokemonToTypeQuestion(
    List<int> pool,
    bool offline,
  ) async {
    final pokemon = await _pickPokemon(
      pool,
      offline: offline,
      needImages: true,
      exclude: _usedAnswerIds,
      where: (p) => p.types.isNotEmpty,
    );
    final correct = pokemon.types[_random.nextInt(pokemon.types.length)];
    // はずれは、そのポケモンが持っていないタイプから3つ
    final wrong = [
      for (final t in PokeType.values)
        if (!pokemon.types.contains(t)) t,
    ]..shuffle(_random);
    final choices = [correct, ...wrong.take(3)]..shuffle(_random);
    return Question(
      variant: QuizVariant.pokemonToType,
      pokemon: pokemon,
      typeChoices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  /// タイプ→ポケモン：タイプを見せて、4匹のポケモン（絵）から選ぶ
  /// 正解のポケモンのタイプの1つを聞き、はずれはそのタイプを持たない3匹にする
  Future<Question> _createTypeToPokemonQuestion(
    List<int> pool,
    bool offline,
  ) async {
    final answer = await _pickPokemon(
      pool,
      offline: offline,
      needImages: true,
      exclude: _usedAnswerIds,
      where: (p) => p.types.isNotEmpty,
    );
    final asked = answer.types[_random.nextInt(answer.types.length)];
    // 選択肢はすべて絵で見せるので、はずれも画像が必要
    final others = <Pokemon>[];
    for (var i = 0; i < 3; i++) {
      others.add(
        await _pickPokemon(
          pool,
          offline: offline,
          needImages: true,
          exclude: {answer.id, for (final p in others) p.id},
          where: (p) => p.types.isNotEmpty && !p.types.contains(asked),
        ),
      );
    }
    final choices = [answer, ...others]..shuffle(_random);
    return Question(
      variant: QuizVariant.typeToPokemon,
      pokemon: answer,
      askedType: asked,
      pokemonChoices: choices,
      correctIndex: choices.indexOf(answer),
    );
  }

  /// pool からランダムに、条件に合うポケモンを1匹選ぶ
  /// - exclude：選ばない図鑑番号
  /// - where：ポケモンの条件（タイプなど）
  /// - needImages：画像が必要か。オンラインなら保存し、オフラインなら保存済みのものだけ選ぶ
  Future<Pokemon> _pickPokemon(
    List<int> pool, {
    required bool offline,
    required bool needImages,
    Set<int> exclude = const {},
    bool Function(Pokemon)? where,
  }) async {
    final repo = ref.read(pokemonRepositoryProvider);
    var tries = 0;
    for (final id in [...pool]..shuffle(_random)) {
      if (exclude.contains(id)) continue;
      // ネットから取るのは時間がかかるので、探す数に上限をつける
      if (!offline && ++tries > _maxOnlineTries) break;

      final pokemon = await repo.getPokemon(id);
      if (where != null && !where(pokemon)) continue;
      if (needImages) {
        if (offline) {
          if (!await repo.hasImages(pokemon)) continue;
        } else {
          // 問題を出す前に画像を保存しておく（次からオフラインでも出せる）
          await repo.downloadImages(pokemon);
        }
      }
      return pokemon;
    }
    throw offline
        ? const NotEnoughOfflineDataException()
        : StateError('じょうけんに あう ポケモンが みつかりません');
  }
}

/// オフラインで、保存済みのポケモンが足りなくて問題を作れないとき
class NotEnoughOfflineDataException implements Exception {
  const NotEnoughOfflineDataException();

  @override
  String toString() => 'インターネットに つないでね\n（ほぞんされた ポケモンが たりません）';
}
