import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/pokemon.dart';
import '../models/quiz_settings.dart';
import '../models/score.dart';
import '../providers/high_score_provider.dart';
import '../providers/sound_provider.dart';
import 'quiz_screen.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';
import 'widgets/celebration.dart';
import 'widgets/type_badge.dart';

/// 正解数の段（10問なら 全問／8〜9／5〜7／0〜4 の4段階）
/// 段ごとに、星の数・ほめ言葉・鳴らす曲が決まっている
enum ResultRank {
  perfect(3, 'かんぺき！ ポケモン マスターだね！', 'se/result_perfect.wav'),
  great(3, 'すごい！ ポケモン はかせだね！', 'se/result_great.wav'),
  good(2, 'よく できました！ あと すこし！', 'se/result_good.wav'),
  // 星は、子どもががっかりしないよう最低でも1つ。曲も悲しくしない
  tryAgain(1, 'がんばったね！ つぎも ちょうせん！', 'se/result_try.wav');

  final int stars;
  final String message;
  final String jingle; // 鳴らす曲（assets/ からの場所）

  const ResultRank(this.stars, this.message, this.jingle);

  /// 正解数から段を決める（全問、8割以上、5割以上、それ以外）
  static ResultRank of(int correct, int total) {
    if (correct >= total) return perfect;
    final ratio = correct / total;
    if (ratio >= 0.8) return great;
    if (ratio >= 0.5) return good;
    return tryAgain;
  }
}

/// 結果画面：星・正解数と、間違えたポケモンの一覧
/// 表示したときに1回だけハイスコアを記録する
class ResultScreen extends ConsumerStatefulWidget {
  final QuizVariant variant; // 遊んだクイズの種類
  final QuizMode mode;
  final int correctCount;
  final int total;
  final List<Pokemon> wrongPokemons;
  final int newlyFound; // このゲームで図鑑にはじめて入ったポケモンの数
  final Score score; // 点数（ハイスコアはこれで記録する）

  const ResultScreen({
    super.key,
    required this.variant,
    required this.mode,
    required this.correctCount,
    required this.total,
    required this.wrongPokemons,
    this.newlyFound = 0,
    this.score = const Score(),
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  // ハイスコアを更新したかどうか（記録が終わるまで待つ）
  late final Future<bool> _isNewRecord;

  // 下の2つのボタン（どちらも同じ大きさの文字にする）
  static final _smallButtonStyle = OutlinedButton.styleFrom(
    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    padding: const EdgeInsets.symmetric(horizontal: 8),
  );

  @override
  void initState() {
    super.initState();
    // build は何度も呼ばれるので、記録は initState で1回だけ
    _isNewRecord = ref
        .read(highScoresProvider.notifier)
        .submit(widget.variant, widget.mode, widget.score.total);
    // 正解数に合わせた曲を、1回だけ鳴らす
    ref
        .read(soundServiceProvider)
        .playJingle(ResultRank.of(widget.correctCount, widget.total).jingle);
  }

  @override
  Widget build(BuildContext context) {
    final wrongPokemons = widget.wrongPokemons;
    final best = ref
        .watch(highScoresProvider)
        .value?[(widget.variant, widget.mode)];
    final rank = ResultRank.of(widget.correctCount, widget.total);
    final compact = context.isCompactHeight; // iPhone SE など縦が短い画面

    return GradientBackground(
      colors: const [Color(0xFFFFF59D), AppColors.cream], // 黄色 → クリーム色
      // Stack：結果画面の上に、全問正解のお祝い（花火と風船）を重ねる
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('けっか'),
              automaticallyImplyLeading: false, // 戻るボタンを出さない
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _Stars(count: rank.stars, scale: compact ? 0.75 : 1),
                    // 長いメッセージでも2行にならないよう、入りきらなければ縮める
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rank.message,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 点数を大きく、その下に正解数と点数の内訳
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${widget.score.total}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const TextSpan(text: ' てん'),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${widget.total} もん中 ${widget.correctCount} もん せいかい',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    _ScoreBreakdown(score: widget.score),
                    if (widget.newlyFound > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.menu_book, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'ずかんに ${widget.newlyFound}ひき ふえたよ！',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    // ハイスコアを更新したら、お祝いの表示
                    FutureBuilder<bool>(
                      future: _isNewRecord,
                      builder: (context, snapshot) => snapshot.data == true
                          ? const _NewRecordBanner()
                          // 長いと2行に折れるので、入りきらなければ縮めて1行にする
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                best == null
                                    ? ''
                                    : '${widget.variant.label}・${widget.mode.label}の'
                                          ' ハイスコア：$best てん',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    // 間違えたポケモンを、絵つきのカードで並べる
                    Expanded(
                      child: wrongPokemons.isEmpty
                          ? const Center(
                              child: Text(
                                'ぜんもん せいかい！',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                const Text(
                                  'おぼえてね！',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 8),
                                // 横にスワイプして見る列（カードが途中で切れず、名前まで見える）
                                Expanded(
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: wrongPokemons.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, i) => AspectRatio(
                                      aspectRatio: 0.8,
                                      child: _WrongPokemonCard(
                                        // タイプクイズのときは、タイプもいっしょに覚えられるように出す
                                        showTypes:
                                            widget.variant != QuizVariant.name,
                                        pokemon: wrongPokemons[i],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 60 : 68,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        // 同じ画面を作り直して、もう1ゲーム
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: RouteNames.quiz,
                            ),
                            builder: (_) => const QuizScreen(),
                          ),
                        ),
                        child: const Text('もういちど'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: compact ? 52 : 60,
                            child: OutlinedButton(
                              style: _smallButtonStyle,
                              // 結果画面を閉じると、下にある設定画面に戻る
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('せってい'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: compact ? 52 : 60,
                            child: OutlinedButton(
                              style: _smallButtonStyle,
                              // 一番下（最初）の画面＝タイトルまで戻る
                              onPressed: () =>
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst),
                              child: const Text('タイトル'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.correctCount >= widget.total)
            const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

/// 星を3つ並べ、もらえた数だけ順番に「ぽん」と出す
class _Stars extends StatelessWidget {
  final int count;
  final double scale; // 小さい画面では小さく
  const _Stars({required this.count, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          // TweenAnimationBuilder: 0 → 1 の値を、時間をかけて渡してくれる
          // 星ごとに時間をずらして、1つずつ出てくるように見せる
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 500 + i * 300),
            curve: Interval(i * 0.3, 1, curve: Curves.elasticOut),
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Icon(
              Icons.star_rounded,
              size: (i == 1 ? 96 : 76) * scale, // まん中だけ大きく
              color: i < count ? Colors.amber : Colors.grey.shade300,
              shadows: const [Shadow(color: Colors.white, blurRadius: 8)],
            ),
          ),
      ],
    );
  }
}

/// 間違えたポケモン1匹のカード
class _WrongPokemonCard extends StatelessWidget {
  final Pokemon pokemon;
  final bool showTypes;
  const _WrongPokemonCard({required this.pokemon, this.showTypes = false});

  @override
  Widget build(BuildContext context) {
    final url = pokemon.artworkUrl ?? pokemon.spriteUrl;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: url == null
                  ? const Icon(Icons.help_outline, size: 48)
                  : CachedImage(url: url),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pokemon.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showTypes) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: TypeBadges(types: pokemon.types, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「ハイスコア こうしん！」の表示
class _NewRecordBanner extends StatelessWidget {
  const _NewRecordBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: Colors.white, size: 32),
          SizedBox(width: 8),
          // 小さい画面では、はみ出さないよう文字を縮める
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'ハイスコア こうしん！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 点数の内訳（せいかい・はやさ・れんぞく・パーフェクト）を小さく並べる
class _ScoreBreakdown extends StatelessWidget {
  final Score score;
  const _ScoreBreakdown({required this.score});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('せいかい', score.correct),
      ('はやさ', score.speed),
      ('れんぞく', score.combo),
      if (score.perfect > 0) ('パーフェクト', score.perfect),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        [for (final (label, points) in items) '$label $points'].join('・'),
        style: const TextStyle(fontSize: 15, color: Colors.black54),
      ),
    );
  }
}
