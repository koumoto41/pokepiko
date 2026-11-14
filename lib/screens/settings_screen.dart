import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../data/poke_api_client.dart';
import '../models/generation.dart';
import '../models/quiz_settings.dart';
import '../providers/data_providers.dart';
import '../providers/settings_provider.dart';
import 'quiz_screen.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';

/// 設定画面：出題する世代（複数可）とモードを選んで「スタート」
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // モードごとのアイコンと色（文字が読めなくても選べるように）
  static const _modeIcons = {
    QuizMode.illustration: Icons.image,
    QuizMode.pixel: Icons.grid_on,
    QuizMode.silhouette: Icons.help,
  };
  static const _modeColors = {
    QuizMode.illustration: Colors.orange,
    QuizMode.pixel: Colors.green,
    QuizMode.silhouette: Colors.indigo,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final allSelected = settings.generations.length == Generation.all.length;

    return GradientBackground(
      colors: const [Color(0xFFC8E6C9), AppColors.cream], // 若草色 → クリーム色
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('せってい')),
        body: SafeArea(
          child: Column(
            children: [
              // 画面が小さくても全部見られるように、ここだけスクロールできる
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('せだい')),
                        FilterChip(
                          label: const Text(
                            'ぜんぶ',
                            style: TextStyle(fontSize: 18),
                          ),
                          selected: allSelected,
                          onSelected: (_) => controller.toggleAllGenerations(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 世代を3列のタイルで並べる
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true, // ListView の中に入れるため
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.85, // ポケモンの絵が入るよう縦長に
                      children: [
                        for (final g in Generation.all)
                          _GenerationTile(
                            generation: g,
                            selected: settings.generations.contains(g.number),
                            onTap: () => controller.toggleGeneration(g.number),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${settings.candidateIds.length} ひきから しゅつだい',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _DownloadSection(ids: settings.candidateIds),
                    const SizedBox(height: 24),
                    const _SectionTitle('モード'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final mode in QuizMode.values) ...[
                          Expanded(
                            child: _SelectTile(
                              selected: settings.mode == mode,
                              color: _modeColors[mode]!,
                              onTap: () => controller.setMode(mode),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_modeIcons[mode], size: 40),
                                  Text(
                                    mode.label,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (mode != QuizMode.values.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // スタートボタンは常に画面の下に見えるようにする
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: RouteNames.quiz),
                        builder: (_) => const QuizScreen(),
                      ),
                    ),
                    child: const Text('スタート！', style: TextStyle(fontSize: 32)),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}

/// 世代のタイル（数字を大きく、地方名を小さく）
class _GenerationTile extends StatelessWidget {
  final Generation generation;
  final bool selected;
  final VoidCallback onTap;

  const _GenerationTile({
    required this.generation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectTile(
      selected: selected,
      color: Colors.blue,
      onTap: onTap,
      child: Column(
        children: [
          // 代表のポケモン（えらばれていないときは うすく表示）
          Expanded(
            child: Opacity(
              opacity: selected ? 1.0 : 0.4,
              child: CachedImage(
                url: PokeApiClient.artworkUrl(generation.mascotId),
                // 読み込めないとき（オフラインなど）は絵なしで数字だけ
                error: const SizedBox(),
              ),
            ),
          ),
          Text(
            '${generation.number}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(generation.region, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// えらばれていると色がつく、押しやすいタイル
class _SelectTile extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  const _SelectTile({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          // 中の文字・アイコンの色を、えらばれているかどうかでまとめて変える
          child: IconTheme(
            data: IconThemeData(
              color: selected ? Colors.white : Colors.black54,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: selected ? Colors.white : Colors.black54),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 保存済みの数と、まとめてダウンロードするボタン（保護者向け）
/// 上の段：えらんでいる世代、下の段：全国図鑑すべて
class _DownloadSection extends ConsumerWidget {
  final List<int> ids; // 選んでいる世代の図鑑番号

  const _DownloadSection({required this.ids});

  // 全国図鑑すべてを保存したときの、だいたいの容量（公式イラスト1枚 約140KB × 1025匹）
  static const _allSizeLabel = '約150MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 読み込み中は 0 として表示
    final cached = ref.watch(cachedIdsProvider).value ?? const <int>{};
    final allIds = Generation.allIds;
    // 全世代をえらんでいるときは、下の段だけ出す（同じ内容が2つ並ばないように）
    final showSelected = ids.length != allIds.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (showSelected) ...[
              _DownloadRow(
                label: 'えらんだ せだい',
                ids: ids,
                cached: cached,
                onDownload: () => _startDownload(context, ids),
              ),
              const Divider(),
            ],
            _DownloadRow(
              label: 'ぜんこく ずかん',
              ids: allIds,
              cached: cached,
              buttonText: 'ぜんぶ ダウンロード',
              onDownload: () => _confirmDownloadAll(context, allIds),
            ),
          ],
        ),
      ),
    );
  }

  void _startDownload(BuildContext context, List<int> ids) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // 外側を押しても閉じない
      builder: (_) => _DownloadDialog(ids: ids),
    );
  }

  /// 全部は容量も時間もかかるので、確認してから始める
  Future<void> _confirmDownloadAll(BuildContext context, List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ぜんぶ ダウンロードしますか？'),
        content: Text(
          '全国図鑑 ${ids.length}匹ぶんの名前と画像を保存します。\n'
          '・容量：$_allSizeLabel くらい\n'
          '・時間：数分〜10分ほど\n'
          'Wi-Fi につないだ状態でおすすめします。\n'
          '保存済みのポケモンはとばすので、途中でやめても続きからできます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ダウンロード'),
          ),
        ],
      ),
    );
    // await のあいだに画面が閉じられていたら何もしない
    if (ok == true && context.mounted) _startDownload(context, ids);
  }
}

/// 「○○：ほぞんずみ X / Y ひき [ダウンロード]」の1行
class _DownloadRow extends StatelessWidget {
  final String label;
  final List<int> ids;
  final Set<int> cached;
  final String buttonText;
  final VoidCallback onDownload;

  const _DownloadRow({
    required this.label,
    required this.ids,
    required this.cached,
    required this.onDownload,
    this.buttonText = 'ダウンロード',
  });

  @override
  Widget build(BuildContext context) {
    final savedCount = ids.where(cached.contains).length;
    final allSaved = savedCount == ids.length;

    return Row(
      children: [
        Icon(
          allSaved ? Icons.offline_pin : Icons.cloud_download,
          color: allSaved ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                allSaved
                    ? 'ぜんぶ ほぞんずみ（オフラインで あそべる）'
                    : 'ほぞんずみ $savedCount / ${ids.length} ひき',
              ),
            ],
          ),
        ),
        if (!allSaved)
          FilledButton.tonal(onPressed: onDownload, child: Text(buttonText)),
      ],
    );
  }
}

/// ダウンロードの進み具合を出すダイアログ
class _DownloadDialog extends ConsumerStatefulWidget {
  final List<int> ids;
  const _DownloadDialog({required this.ids});

  @override
  ConsumerState<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<_DownloadDialog> {
  int _done = 0;
  int? _failed; // null のあいだはダウンロード中
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // 「やめる」でダイアログを閉じたあとも最後に表示を更新できるよう、
    // ref ではなく Provider の入れ物（container）を先にとっておく
    // （閉じたあとの画面の ref は使えないため）
    final container = ProviderScope.containerOf(context, listen: false);
    final failed = await container
        .read(pokemonRepositoryProvider)
        .downloadAll(
          widget.ids,
          onProgress: (done, _) {
            if (mounted) setState(() => _done = done);
          },
          isCancelled: () => _cancelled,
        );
    // 保存済みの数を読み直して、設定画面の表示を更新する
    container.invalidate(cachedIdsProvider);
    if (mounted) setState(() => _failed = failed);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.ids.length;
    final finished = _failed != null;

    return AlertDialog(
      title: Text(finished ? 'おわったよ' : 'ダウンロードちゅう…'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: total == 0 ? null : _done / total),
          const SizedBox(height: 12),
          Text('$_done / $total ひき'),
          if (finished && _failed! > 0)
            Text('$_failed ひき しっぱい（もういちど おすと やりなおせます）'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (finished) {
              Navigator.of(context).pop();
            } else {
              // やめる：いまダウンロード中の分が終わったら止まる
              setState(() => _cancelled = true);
              Navigator.of(context).pop();
            }
          },
          child: Text(finished ? 'とじる' : 'やめる'),
        ),
      ],
    );
  }
}
