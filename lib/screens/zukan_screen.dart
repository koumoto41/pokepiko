import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../data/poke_api_client.dart';
import '../models/generation.dart';
import '../providers/collection_provider.dart';
import '../providers/data_providers.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';
import 'zukan_detail_screen.dart';

/// 図鑑の一覧：世代を選んで、その世代のポケモンを並べる
/// クイズで正解した（みつけた）ポケモンだけ絵と名前が見え、まだのポケモンは「？」
class ZukanScreen extends ConsumerStatefulWidget {
  const ZukanScreen({super.key});

  @override
  ConsumerState<ZukanScreen> createState() => _ZukanScreenState();
}

class _ZukanScreenState extends ConsumerState<ZukanScreen> {
  int? _generation; // 見ている世代（null のあいだは、自動で決める）
  bool _foundOnly = false; // true：みつけたポケモンだけ並べる

  @override
  Widget build(BuildContext context) {
    // 読み込み中は「まだ何もみつけていない」として表示する
    final found = ref.watch(collectionProvider).value ?? const <int>{};
    // はじめは、みつけたポケモンがいる いちばん若い世代を見せる（いなければ第1世代）
    final selected =
        _generation ??
        Generation.all
            .firstWhere(
              (g) => g.ids.any(found.contains),
              orElse: () => Generation.all.first,
            )
            .number;
    final generation = Generation.all[selected - 1];
    final foundInGeneration = generation.ids.where(found.contains).length;
    // 並べる図鑑番号（「みつけた だけ」のときは、みつけたポケモンだけ）
    final ids = [
      for (final id in generation.ids)
        if (!_foundOnly || found.contains(id)) id,
    ];

    return GradientBackground(
      colors: const [Color(0xFFFFE0B2), AppColors.cream], // オレンジ → クリーム色
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('ずかん')),
        body: SafeArea(
          child: Column(
            children: [
              _FoundCounter(
                found: found.length,
                total: Generation.all.last.lastId,
              ),
              const SizedBox(height: 8),
              // 世代をえらぶ（横にスクロールできる）
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final g in Generation.all)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            '${g.number} ${g.region}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          selected: g.number == selected,
                          onSelected: (_) =>
                              setState(() => _generation = g.number),
                        ),
                      ),
                  ],
                ),
              ),
              // 世代の数と「みつけた だけ」のチェック（縦の場所をとらないよう同じ行に）
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'このせだい：$foundInGeneration / ${generation.count} ひき',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    // FilterChip：押すとオン・オフが切りかわる、チェックつきのボタン
                    FilterChip(
                      label: const Text(
                        'みつけた だけ',
                        style: TextStyle(fontSize: 16),
                      ),
                      selected: _foundOnly,
                      onSelected: (on) => setState(() => _foundOnly = on),
                    ),
                  ],
                ),
              ),
              // その世代のポケモンを4列で並べる
              Expanded(
                child: ids.isEmpty
                    // 「みつけた だけ」で、この世代にまだ1匹もいないとき
                    ? const Center(
                        child: Text(
                          'このせだいは まだ みつけていないよ\nシルエットクイズで さがしてみよう！',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : GridView.builder(
                        // 世代や「みつけた だけ」を変えたら、いちばん上から見せる
                        key: ValueKey((selected, _foundOnly)),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.78,
                            ),
                        itemCount: ids.length,
                        itemBuilder: (context, i) => _ZukanTile(
                          id: ids[i],
                          found: found.contains(ids[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「みつけた ○ / 1025 ひき」とバー
class _FoundCounter extends StatelessWidget {
  final int found;
  final int total;

  const _FoundCounter({required this.found, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'みつけた '),
                    TextSpan(
                      text: '$found',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    TextSpan(text: ' / $total ひき'),
                  ],
                ),
                style: const TextStyle(fontSize: 20),
              ),
              const Text(
                'シルエットで せいかいすると ずかんに はいるよ',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: found / total,
                  minHeight: 10,
                  color: Colors.orange,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一覧の1マス
class _ZukanTile extends ConsumerWidget {
  final int id;
  final bool found;

  const _ZukanTile({required this.id, required this.found});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = Text(
      'No.${id.toString().padLeft(4, '0')}',
      style: const TextStyle(fontSize: 11),
    );

    if (!found) {
      // まだみつけていない：絵も名前も出さない（画像を読み込まないので通信もしない）
      return Material(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('シルエットクイズで せいかいすると みつかるよ！'),
                duration: Duration(seconds: 2),
              ),
            ),
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    '？',
                    style: TextStyle(fontSize: 32, color: Colors.black26),
                  ),
                ),
              ),
              number,
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    }

    // みつけた：絵と名前（名前は保存済みのデータから読む）
    final name = ref.watch(pokemonProvider(id)).value?.name ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(ZukanDetailScreen.route(id)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(
                child: CachedImage(
                  url: PokeApiClient.artworkUrl(id),
                  error: const Icon(Icons.help_outline, size: 32),
                ),
              ),
              number,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 図鑑の一覧を開くときの画面遷移（BGM の切りかえのために名前をつける）
Route<void> zukanRoute() => MaterialPageRoute(
  settings: const RouteSettings(name: RouteNames.zukan),
  builder: (_) => const ZukanScreen(),
);
