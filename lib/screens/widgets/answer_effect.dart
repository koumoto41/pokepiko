import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app_theme.dart';

/// 答えたときに画像の上に出す演出
/// - 正解：大きな〇が「ぽよん」と出て、まわりに星が飛び散る
/// - 不正解：× が出る
/// 表示されたときに1回だけ動く（次の問題で新しく作り直される）
class AnswerEffect extends StatefulWidget {
  final bool correct;

  const AnswerEffect({super.key, required this.correct});

  @override
  State<AnswerEffect> createState() => _AnswerEffectState();
}

class _AnswerEffectState extends State<AnswerEffect>
    with SingleTickerProviderStateMixin {
  // AnimationController: 0.0 → 1.0 へ、決めた時間をかけて進む「時計」
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  // elasticOut: 行きすぎてから戻る、ばねのような動き
  late final _pop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.7, curve: Curves.elasticOut),
  );

  static const _starCount = 12;
  static const _starColors = [
    Colors.amber,
    Colors.pinkAccent,
    Colors.lightBlueAccent,
    Colors.lightGreenAccent,
  ];

  @override
  void dispose() {
    _controller.dispose(); // 使い終わった時計は必ず止める
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // AnimatedBuilder: 時計が進むたびに builder だけを描き直す
      // LayoutBuilder: 置かれた場所の大きさを知って、〇や星の大きさを合わせる
      // （小さい画面で〇がカードからはみ出さないように）
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                _buildFrame(_controller.value, size.isFinite ? size : 300),
          );
        },
      ),
    );
  }

  /// アニメーションの1コマ分（t: 0.0〜1.0、size: 使える大きさ）
  Widget _buildFrame(double t, double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.correct)
          for (var i = 0; i < _starCount; i++) _star(i, t, size),
        Transform.scale(
          scale: _pop.value,
          child: Text(
            widget.correct ? '〇' : '×',
            // 文字は上下に余白があるので、使える大きさより少し大きめでちょうどよい
            style: TextStyle(
              height: 1,
              fontSize: min(220, size * 0.9),
              fontWeight: FontWeight.bold,
              color: (widget.correct ? Colors.red : Colors.blue).withValues(
                alpha: 0.75,
              ),
              shadows: const [Shadow(color: Colors.white, blurRadius: 12)],
            ),
          ),
        ),
      ],
    );
  }

  /// i 番目の星：まん中から外へ飛んで、だんだん消える
  Widget _star(int i, double t, double size) {
    final angle = 2 * pi * i / _starCount;
    final distance = size * (0.2 + 0.35 * Curves.easeOut.transform(t));
    return Transform.translate(
      offset: Offset(cos(angle) * distance, sin(angle) * distance),
      child: Opacity(
        opacity: (1 - t).clamp(0, 1),
        child: Transform.rotate(
          angle: t * pi,
          child: Icon(
            Icons.star,
            size: min(36, size * 0.15),
            color: _starColors[i % _starColors.length],
          ),
        ),
      ),
    );
  }
}

/// 何問目か・それまでの結果を丸の列で見せる（数字が読めなくても分かる）
class ProgressDots extends StatelessWidget {
  final int total;
  final int current; // いま何問目か（1から）
  final List<bool> results; // 答え終わった問題の結果

  const ProgressDots({
    super.key,
    required this.total,
    required this.current,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            // いまの問題の丸だけ大きくする
            width: i == current - 1 ? 22 : 16,
            height: i == current - 1 ? 22 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < results.length
                  ? (results[i] ? AppColors.correct : AppColors.wrong)
                  : (i == current - 1 ? Colors.orange : Colors.white),
              border: Border.all(color: Colors.orange.shade200, width: 2),
            ),
          ),
      ],
    );
  }
}
