import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../data/poke_api_client.dart';
import '../models/dex_entry.dart';
import '../models/pokemon.dart';
import '../providers/collection_provider.dart';
import '../providers/data_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/sound_provider.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';
import 'widgets/type_badge.dart';

/// 図鑑のくわしいページ
class ZukanDetailScreen extends ConsumerWidget {
  final int id;

  const ZukanDetailScreen({super.key, required this.id});

  /// このページを開くときの画面遷移（BGM の切りかえのために名前をつける）
  static Route<void> route(int id) => MaterialPageRoute(
    settings: const RouteSettings(name: RouteNames.zukanDetail),
    builder: (_) => ZukanDetailScreen(id: id),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemon = ref.watch(pokemonProvider(id));
    final entry = ref.watch(dexEntryProvider(id));

    return GradientBackground(
      colors: const [Color(0xFFFFE0B2), AppColors.cream],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('No.${id.toString().padLeft(4, '0')}')),
        // switch：読み込み中・失敗・成功で出すものを変える
        body: SafeArea(
          child: switch ((pokemon, entry)) {
            (AsyncData(value: final p), AsyncData(value: final e)) =>
              _DetailBody(pokemon: p, entry: e),
            (AsyncError(), _) || (_, AsyncError()) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'よみこめませんでした\nインターネットに つないでね',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Pokemon pokemon;
  final DexEntry entry;

  const _DetailBody({required this.pokemon, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kanji = ref.watch(settingsProvider.select((s) => s.dexKanji));
    // 選んだ書きかたが無いときは、もう片方を使う
    final genus = kanji
        ? entry.genusKanji ?? entry.genusKana
        : entry.genusKana ?? entry.genusKanji;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // 大きな絵（ドット絵があれば右下に小さく）
        SizedBox(
          height: context.isCompactHeight ? 200 : 260,
          child: Card(
            margin: EdgeInsets.zero,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CachedImage(
                      url:
                          pokemon.artworkUrl ??
                          PokeApiClient.artworkUrl(pokemon.id),
                    ),
                  ),
                ),
                if (pokemon.spriteUrl case final sprite?)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    width: 64,
                    height: 64,
                    child: CachedImage(
                      url: sprite,
                      filterQuality: FilterQuality.none,
                      error: const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  pokemon.name,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (entry.cryUrl != null) _CryButton(id: pokemon.id),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TypeBadges(types: pokemon.types, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _InfoRow(label: 'ぶんるい', value: genus ?? '？'),
                _InfoRow(label: 'たかさ', value: entry.heightText),
                _InfoRow(label: 'おもさ', value: entry.weightText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FlavorCard(entry: entry, kanji: kanji),
        if (entry.evolution.length > 1) ...[
          const SizedBox(height: 12),
          _EvolutionCard(entry: entry, currentId: pokemon.id),
        ],
      ],
    );
  }
}

/// 鳴き声のボタン
class _CryButton extends ConsumerStatefulWidget {
  final int id;
  const _CryButton({required this.id});

  @override
  ConsumerState<_CryButton> createState() => _CryButtonState();
}

class _CryButtonState extends ConsumerState<_CryButton> {
  bool _loading = false; // 鳴き声をダウンロードしているあいだ

  Future<void> _play() async {
    setState(() => _loading = true);
    final player = ref.read(cryPlayerProvider);
    try {
      final file = await ref.read(pokemonRepositoryProvider).getCry(widget.id);
      if (file != null) await player.play(file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('なきごえを よみこめませんでした')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.orange,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: _loading ? null : _play,
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Icon(Icons.volume_up, size: 28),
      label: const Text('なきごえ'),
    );
  }
}

/// 「ぶんるい：ねずみポケモン」のような1行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 図鑑の説明文（ひらがな／かんじ を切りかえられる）
class _FlavorCard extends ConsumerWidget {
  final DexEntry entry;
  final bool kanji;

  const _FlavorCard({required this.entry, required this.kanji});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 選んだ書きかたが無いときは、もう片方を使う
    final text = kanji
        ? entry.flavorKanji ?? entry.flavorKana
        : entry.flavorKana ?? entry.flavorKanji;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SegmentedButton：いくつかの中から1つを選ぶボタン
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('ひらがな')),
                  ButtonSegment(value: true, label: Text('かんじ')),
                ],
                selected: {kanji},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(settingsProvider.notifier).setDexKanji(s.first),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text ?? 'せつめいは まだ ないよ',
              style: const TextStyle(fontSize: 20, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 進化のつながり（段階ごとに上から下へ。枝分かれは横に並べる）
class _EvolutionCard extends ConsumerWidget {
  final DexEntry entry;
  final int currentId;

  const _EvolutionCard({required this.entry, required this.currentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(collectionProvider).value ?? const <int>{};
    // 進化の仲間が全員みつかったか
    final complete = entry.evolution.every(
      (stage) => stage.every(found.contains),
    );

    return Card(
      margin: EdgeInsets.zero,
      // そろったら、金色のふちどりで特別に見せる
      shape: complete
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.amber, width: 3),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'しんか',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (complete)
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                    SizedBox(width: 4),
                    Text(
                      'コンプリート！',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
            for (final (i, stage) in entry.evolution.indexed) ...[
              if (i > 0)
                const Icon(
                  Icons.arrow_downward,
                  color: Colors.orange,
                  size: 28,
                ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in stage)
                    _EvolutionMember(
                      id: id,
                      found: found.contains(id),
                      current: id == currentId,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvolutionMember extends ConsumerWidget {
  final int id;
  final bool found;
  final bool current; // いま見ているポケモン

  const _EvolutionMember({
    required this.id,
    required this.found,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // みつけたポケモンだけ名前を読む（まだのポケモンは通信しない）
    final name = found ? ref.watch(pokemonProvider(id)).value?.name : null;

    return GestureDetector(
      // みつけた仲間を押すと、そのポケモンのページへ
      onTap: found && !current
          ? () =>
                Navigator.of(context)
                    .pushReplacement(ZukanDetailScreen.route(id))
          : null,
      child: Container(
        width: 84,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: found ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: current ? Colors.orange : Colors.grey.shade300,
            width: current ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: found
                  ? CachedImage(url: PokeApiClient.artworkUrl(id))
                  : const Center(
                      child: Text(
                        '？',
                        style: TextStyle(fontSize: 28, color: Colors.black26),
                      ),
                    ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name ?? '？？？',
                style: const TextStyle(
                  fontSize: 13,
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
