import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/pokemon.dart';
import '../models/quiz_settings.dart';
import '../providers/high_score_provider.dart';
import 'quiz_screen.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';

/// 結果画面：星・正解数と、間違えたポケモンの一覧
/// 表示したときに1回だけハイスコアを記録する
class ResultScreen extends ConsumerStatefulWidget {
  final QuizMode mode;
  final int correctCount;
  final int total;
  final List<Pokemon> wrongPokemons;

  const ResultScreen({
    super.key,
    required this.mode,
    required this.correctCount,
    required this.total,
    required this.wrongPokemons,
  });

  /// 星の数（子どもががっかりしないよう、最低でも1つ）
  static int starsFor(int correct, int total) {
    final ratio = correct / total;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.5) return 2;
    return 1;
  }

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  // ハイスコアを更新したかどうか（記録が終わるまで待つ）
  late final Future<bool> _isNewRecord;

  static const _messages = {
    3: 'すごい！ ポケモン はかせだね！',
    2: 'よく できました！',
    1: 'がんばったね！ つぎも ちょうせん！',
  };

  @override
  void initState() {
    super.initState();
    // build は何度も呼ばれるので、記録は initState で1回だけ
    _isNewRecord = ref
        .read(highScoresProvider.notifier)
        .submit(widget.mode, widget.correctCount);
  }

  @override
  Widget build(BuildContext context) {
    final wrongPokemons = widget.wrongPokemons;
    final best = ref.watch(highScoresProvider).value?[widget.mode];
    final stars = ResultScreen.starsFor(widget.correctCount, widget.total);

    return GradientBackground(
      colors: const [Color(0xFFFFF59D), AppColors.cream], // 黄色 → クリーム色
      child: Scaffold(
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
                _Stars(count: stars),
                Text(
                  _messages[stars]!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${widget.total} もん中 '),
                      TextSpan(
                        text: '${widget.correctCount}',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const TextSpan(text: ' もん せいかい'),
                    ],
                  ),
                  style: const TextStyle(fontSize: 22),
                ),
                // ハイスコアを更新したら、お祝いの表示
                FutureBuilder<bool>(
                  future: _isNewRecord,
                  builder: (context, snapshot) => snapshot.data == true
                      ? const _NewRecordBanner()
                      : Text(
                          best == null
                              ? ''
                              : '${widget.mode.label}の ハイスコア：$best もん',
                          style: const TextStyle(fontSize: 18),
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
                            Expanded(
                              child: GridView.count(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.85,
                                children: [
                                  for (final p in wrongPokemons)
                                    _WrongPokemonCard(pokemon: p),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    // 同じ画面を作り直して、もう1ゲーム
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: RouteNames.quiz),
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
                        height: 60,
                        child: OutlinedButton(
                          // 結果画面を閉じると、下にある設定画面に戻る
                          onPressed: () => Navigator.of(context).pop(),
                          child: const FittedBox(child: Text('せっていを かえる')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: OutlinedButton(
                          // 一番下（最初）の画面＝タイトルまで戻る
                          onPressed: () =>
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst),
                          child: const FittedBox(child: Text('タイトルへ')),
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
    );
  }
}

/// 星を3つ並べ、もらえた数だけ順番に「ぽん」と出す
class _Stars extends StatelessWidget {
  final int count;
  const _Stars({required this.count});

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
              size: i == 1 ? 96 : 76, // まん中だけ大きく
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
  const _WrongPokemonCard({required this.pokemon});

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
