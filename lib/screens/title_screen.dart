import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/generation.dart';
import '../models/quiz_settings.dart';
import '../providers/collection_provider.dart';
import '../providers/high_score_provider.dart';
import 'route_names.dart';
import 'settings_screen.dart';
import 'widgets/title_decorations.dart';
import 'zukan_screen.dart';

/// タイトル画面
/// 主役のポケモン（図鑑でみつけたポケモンから1匹）と、背景にただようシルエットで、にぎやかにする
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> {
  final _random = Random();
  int? _featuredId; // 主役のポケモン（図鑑の記録を読み込んでから決める）
  List<int> _silhouetteIds = const []; // 背景のシルエットに使うポケモン

  // 図鑑でまだ1匹もみつけていないときは、設定画面の代表9匹を使う
  static final _mascots = [for (final g in Generation.all) g.mascotId];

  /// 図鑑の記録から、主役と背景のポケモンを決める（画面を開いているあいだは変えない）
  void _pickPokemon(Set<int> found) {
    final pool = found.isEmpty ? _mascots : found.toList();
    _featuredId = pool[_random.nextInt(pool.length)];
    _silhouetteIds = ([
      ...pool,
      ..._mascots,
    ]..shuffle(_random)).take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final found = ref.watch(collectionProvider).value;
    if (found != null && _featuredId == null) _pickPokemon(found);

    // iPhone SE など縦が短い画面では、主役のポケモンとロゴを横に並べて場所を節約する
    final compact = context.isCompactHeight;
    final featured = _featuredId == null
        ? SizedBox.square(dimension: compact ? 120 : 180)
        : FeaturedPokemon(id: _featuredId!, size: compact ? 120 : 180);
    final logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: TitleLogo(fontSize: compact ? 48 : 64),
        ),
        Text(
          'ポケモン クイズ',
          style: TextStyle(
            fontSize: compact ? 18 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
      ],
    );

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
        child: Stack(
          children: [
            // いちばん後ろに、ただようシルエット
            Positioned.fill(child: FloatingSilhouettes(ids: _silhouetteIds)),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: compact ? 12 : 24,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    if (compact)
                      Row(
                        children: [
                          featured,
                          const SizedBox(width: 8),
                          Expanded(child: logo),
                        ],
                      )
                    else ...[
                      featured,
                      const SizedBox(height: 8),
                      logo,
                    ],
                    SizedBox(height: compact ? 12 : 24),
                    const _HighScores(),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 68 : 80,
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
                        child: const Text(
                          'はじめる',
                          style: TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () =>
                            Navigator.of(context).push(zukanRoute()),
                        icon: const Icon(Icons.menu_book, size: 32),
                        label: const Text('ずかん'),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 32),
                  ],
                ),
              ),
            ),
          ],
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
