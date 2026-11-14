import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/models/score.dart';

void main() {
  test('すぐ答えて正解：せいかい100＋はやさ300（30秒×10）', () {
    final s = Score.forAnswer(remainingSeconds: 30, streak: 1);
    expect((s.correct, s.speed, s.combo), (100, 300, 0));
    expect(s.total, 400);
  });

  test('残り秒数が少ないほど、はやさの点数が減る', () {
    expect(Score.forAnswer(remainingSeconds: 25, streak: 1).speed, 250);
    expect(Score.forAnswer(remainingSeconds: 1, streak: 1).speed, 10);
    expect(Score.forAnswer(remainingSeconds: 0, streak: 1).speed, 0);
  });

  test('れんぞくは (連続数−1)×20、6問連続からは100で止まる', () {
    int combo(int streak) =>
        Score.forAnswer(remainingSeconds: 0, streak: streak).combo;
    expect(
      [for (var n = 1; n <= 10; n++) combo(n)],
      [
        0, 20, 40, 60, 80, 100, 100, 100, 100, 100, //
      ],
    );
  });

  test('足し算すると、内訳ごとに足される', () {
    final a = Score.forAnswer(remainingSeconds: 30, streak: 1);
    final b = Score.forAnswer(remainingSeconds: 20, streak: 2);
    final sum = a + b + const Score(perfect: Score.perfectPoints);
    expect(
      (sum.correct, sum.speed, sum.combo, sum.perfect),
      (200, 500, 20, 500),
    );
    expect(sum.total, 1220);
  });
}
