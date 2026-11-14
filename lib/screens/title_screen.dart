import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/quiz_settings.dart';
import '../providers/high_score_provider.dart';
import 'route_names.dart';
import 'settings_screen.dart';

/// タイトル画面
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 上から下へ、明るい色のグラデーション
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF59D), Color(0xFFFFCC80)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(
                  Icons.catching_pokemon,
                  // iPhone SE ではハイスコアの表が入るよう、少し小さく
                  size: context.isCompactHeight ? 112 : 160,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'ポケピコ',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const Text(
                  'ポケモン クイズ',
                  style: TextStyle(fontSize: 24, color: Colors.brown),
                ),
                const SizedBox(height: 24),
                const _HighScores(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(
                          name: RouteNames.settings,
                        ),
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    child: const Text('はじめる', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// モードごとのハイスコア
class _HighScores extends ConsumerWidget {
  const _HighScores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 読み込み中は何も出さない
    final scores = ref.watch(highScoresProvider).value;
    if (scores == null) return const SizedBox(height: 96);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber),
              SizedBox(width: 4),
              Text(
                'ハイスコア',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 行：クイズの種類、列：画像の見せかた
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {0: FlexColumnWidth(1.6)},
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  for (final mode in QuizMode.values)
                    _cell(mode.label, const TextStyle(fontSize: 13)),
                ],
              ),
              for (final variant in QuizVariant.values)
                TableRow(
                  children: [
                    _cell(
                      variant.label,
                      const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final mode in QuizMode.values)
                      _cell(
                        '${scores[(variant, mode)] ?? 0}',
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 表の1マス（入りきらなければ文字を縮める）
  Widget _cell(String text, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, style: style),
    ),
  );
}
