import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// 全問正解のお祝い：花火と風船（約8秒で終わる）
/// 画面全体の上に重ねて使う。タップは下の画面にそのまま届く
class Celebration extends StatefulWidget {
  const Celebration({super.key});

  static const duration = Duration(seconds: 8);

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  // AnimationController：0.0 → 1.0 へ 8秒かけて進む「時計」
  late final _controller = AnimationController(
    vsync: this,
    duration: Celebration.duration,
  )..forward();

  // 風船と花火は、はじめに位置や色を決めておく（毎フレーム同じものを描くため）
  final _random = Random();
  late final _balloons = List.generate(14, (i) => _Balloon.random(_random, i));
  late final _fireworks = List.generate(9, (i) => _Firework.random(_random, i));

  @override
  void dispose() {
    _controller.dispose(); // 使い終わった時計は必ず止める
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // iPhone の設定で「動きを減らす」をオンにしている人には出さない
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return IgnorePointer(
      // AnimatedBuilder：時計が進むたびに、描き直す
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.isCompleted
            ? const SizedBox.shrink() // 終わったら何も描かない
            : CustomPaint(
                size: Size.infinite,
                painter: _CelebrationPainter(
                  seconds:
                      _controller.value *
                      Celebration.duration.inMilliseconds /
                      1000,
                  balloons: _balloons,
                  fireworks: _fireworks,
                ),
              ),
      ),
    );
  }
}

const _colors = [
  Color(0xFFFF5252), // あか
  Color(0xFFFFC107), // きいろ
  Color(0xFF40C4FF), // みずいろ
  Color(0xFF69F0AE), // みどり
  Color(0xFFE040FB), // むらさき
  Color(0xFFFF6E40), // オレンジ
  Color(0xFFFF80AB), // ピンク
];

/// 風船1つ分の設定（位置は画面の幅・高さに対する割合）
class _Balloon {
  final double x; // 横の位置（0〜1）
  final double start; // 上がりはじめる時間（秒）
  final double speed; // 1秒で上がる量（画面の高さに対する割合）
  final double size; // 大きさ（横の半径、px）
  final double sway; // ゆれのタイミングのずれ
  final Color color;

  const _Balloon(
    this.x,
    this.start,
    this.speed,
    this.size,
    this.sway,
    this.color,
  );

  factory _Balloon.random(Random r, int i) => _Balloon(
    0.05 + r.nextDouble() * 0.9,
    r.nextDouble() * 3.5,
    0.22 + r.nextDouble() * 0.12,
    18 + r.nextDouble() * 10,
    r.nextDouble() * pi * 2,
    _colors[i % _colors.length],
  );
}

/// 花火1つ分の設定
class _Firework {
  final double x; // 開く位置（0〜1）
  final double y; // 開く高さ（0〜1、上のほう）
  final double start; // 打ち上がる時間（秒）
  final double radius; // 広がる大きさ（px）
  final Color color;
  final Color color2; // 粒を2色まぜて、にぎやかにする

  const _Firework(
    this.x,
    this.y,
    this.start,
    this.radius,
    this.color,
    this.color2,
  );

  static const riseTime = 0.5; // 打ち上がる時間（秒）
  static const lifeTime = 1.6; // 開いてから消えるまで（秒）
  static const particles = 28; // 光の粒の数

  factory _Firework.random(Random r, int i) => _Firework(
    0.15 + r.nextDouble() * 0.7,
    0.12 + r.nextDouble() * 0.3,
    i * 0.7 + r.nextDouble() * 0.3, // 0.7秒ごとに順番に打ち上げる
    70 + r.nextDouble() * 50,
    _colors[r.nextInt(_colors.length)],
    _colors[r.nextInt(_colors.length)],
  );
}

/// 時間（seconds）に合わせて、風船と花火の「その瞬間の1コマ」を描く
class _CelebrationPainter extends CustomPainter {
  final double seconds;
  final List<_Balloon> balloons;
  final List<_Firework> fireworks;

  _CelebrationPainter({
    required this.seconds,
    required this.balloons,
    required this.fireworks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in fireworks) {
      _paintFirework(canvas, size, f);
    }
    for (final b in balloons) {
      _paintBalloon(canvas, size, b);
    }
  }

  void _paintBalloon(Canvas canvas, Size size, _Balloon b) {
    final t = seconds - b.start;
    if (t < 0) return;
    // 下から上へ。横は sin でゆらゆら
    final cy = size.height + b.size * 2 - t * b.speed * size.height;
    if (cy < -b.size * 4) return; // 画面の上に出ていったら描かない
    final cx = b.x * size.width + sin(t * 2.2 + b.sway) * 14;
    final w = b.size;
    final h = b.size * 1.25;

    // ひも（ゆれに合わせて少し曲げる）
    final string = Path()
      ..moveTo(cx, cy + h)
      ..quadraticBezierTo(
        cx + sin(t * 2.2 + b.sway + 1) * 10,
        cy + h + 30,
        cx,
        cy + h + 60,
      );
    canvas.drawPath(
      string,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // むすび目
    canvas.drawPath(
      Path()
        ..moveTo(cx - 4, cy + h + 6)
        ..lineTo(cx + 4, cy + h + 6)
        ..lineTo(cx, cy + h - 2)
        ..close(),
      Paint()..color = b.color,
    );
    // 風船の本体と、つや
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: w * 2, height: h * 2),
      Paint()..color = b.color.withValues(alpha: 0.9),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * 0.35, cy - h * 0.4),
        width: w * 0.5,
        height: h * 0.6,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  void _paintFirework(Canvas canvas, Size size, _Firework f) {
    final t = seconds - f.start;
    if (t < 0) return;
    final center = Offset(f.x * size.width, f.y * size.height);

    if (t < _Firework.riseTime) {
      // 打ち上げ：下から光の点が上がっていく
      final p = Curves.easeOut.transform(t / _Firework.riseTime);
      final y = size.height - (size.height - center.dy) * p;
      canvas.drawCircle(Offset(center.dx, y), 3, Paint()..color = f.color);
      return;
    }

    final e = (t - _Firework.riseTime) / _Firework.lifeTime; // 0〜1
    if (e >= 1) return;
    final spread = Curves.easeOut.transform(e) * f.radius; // 広がる
    final fall = e * e * 40; // だんだん下に落ちる
    final alpha = (1 - e).clamp(0.0, 1.0); // だんだん消える

    for (var i = 0; i < _Firework.particles; i++) {
      final angle = 2 * pi * i / _Firework.particles;
      final dir = Offset(cos(angle), sin(angle));
      final pos = center + dir * spread + Offset(0, fall);
      final color = (i.isEven ? f.color : f.color2).withValues(alpha: alpha);
      // 光の粒と、うしろに伸びる光のすじ
      canvas.drawLine(
        center + dir * (spread * 0.7) + Offset(0, fall * 0.7),
        pos,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.6)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      // 明るい背景でも見えるよう、粒は大きめにする
      canvas.drawCircle(pos, 4.5, Paint()..color = color);
    }
  }

  // 時間が進んだら描き直す
  @override
  bool shouldRepaint(_CelebrationPainter old) => old.seconds != seconds;
}
