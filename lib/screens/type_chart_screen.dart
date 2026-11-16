import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../models/poke_type.dart';
import '../models/type_chart.dart';
import 'route_names.dart';
import 'widgets/type_badge.dart';

/// タイプの相性：「えらんで みる」（子ども向け）と「ひょう」（保護者向け）の2つのタブ
class TypeChartScreen extends StatelessWidget {
  const TypeChartScreen({super.key});

  /// この画面を開くときの画面遷移（BGM の切りかえのために名前をつける）
  static Route<void> route() => MaterialPageRoute(
    settings: const RouteSettings(name: RouteNames.typeChart),
    builder: (_) => const TypeChartScreen(),
  );

  @override
  Widget build(BuildContext context) {
    // DefaultTabController：上のタブと、下の中身の切りかえをまとめて管理する
    return DefaultTabController(
      length: 2,
      child: GradientBackground(
        colors: const [Color(0xFFE1BEE7), AppColors.cream], // うすむらさき → クリーム色
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('タイプの あいしょう'),
            bottom: const TabBar(
              labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'えらんで みる'),
                Tab(text: 'ひょう'),
              ],
            ),
          ),
          body: const SafeArea(
            child: TabBarView(children: [_PickView(), _TableView()]),
          ),
        ),
      ),
    );
  }
}

/// 倍率ごとの記号と色（表と、えらんで みる で同じものを使う）
({String mark, Color color}) _markOf(double multiplier) => switch (multiplier) {
  2 => (mark: '◎', color: Colors.red),
  0.5 => (mark: '△', color: Colors.blue),
  0 => (mark: '✕', color: Colors.grey),
  _ => (mark: '', color: Colors.transparent),
};

/// 「えらんで みる」：タイプを1つ選ぶと、つよい・よわい相手を大きく出す
class _PickView extends StatefulWidget {
  const _PickView();

  @override
  State<_PickView> createState() => _PickViewState();
}

class _PickViewState extends State<_PickView> {
  PokeType _selected = PokeType.fire; // 選んでいるタイプ

  @override
  Widget build(BuildContext context) {
    final t = _selected;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 18タイプのボタン（選んでいるものは大きく、白いふち）
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final type in PokeType.values)
              GestureDetector(
                onTap: () => setState(() => _selected = type),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: type == t ? 1.15 : 1,
                  child: Opacity(
                    opacity: type == t ? 1 : 0.55,
                    child: TypeBadge(type: type, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _RelationCard(
          title: '${t.label}の わざで こうげきすると…',
          rows: [
            (2, 'こうかばつぐん（2ばい）', TypeChart.targets(t, 2)),
            (0.5, 'いまひとつ（はんぶん）', TypeChart.targets(t, 0.5)),
            (0, 'こうかなし', TypeChart.targets(t, 0)),
          ],
        ),
        const SizedBox(height: 12),
        _RelationCard(
          title: '${t.label}タイプの ポケモンが うけると…',
          rows: [
            (2, 'にがて（2ばい うける）', TypeChart.attackers(t, 2)),
            (0.5, 'つよい（はんぶん うける）', TypeChart.attackers(t, 0.5)),
            (0, 'きかない', TypeChart.attackers(t, 0)),
          ],
        ),
      ],
    );
  }
}

/// 「◎ こうかばつぐん：くさ こおり …」のように、倍率ごとにタイプを並べたカード
class _RelationCard extends StatelessWidget {
  final String title;
  final List<(double, String, List<PokeType>)> rows; // (倍率, 説明, タイプ)

  const _RelationCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            for (final (multiplier, label, types) in rows) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _markOf(multiplier).mark,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _markOf(multiplier).color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 15)),
                ],
              ),
              const SizedBox(height: 4),
              types.isEmpty
                  ? const Text(
                      '　なし',
                      style: TextStyle(fontSize: 15, color: Colors.black38),
                    )
                  : Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final type in types)
                          TypeBadge(type: type, fontSize: 15),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「ひょう」：たて＝こうげきする わざ、よこ＝うける ポケモン の 18×18 の表
class _TableView extends StatelessWidget {
  const _TableView();

  static const _cell = 34.0; // 1マスの大きさ

  /// 表の見出しに使う、タイプの短い名前（はじめの2文字）
  static String _short(PokeType t) => t.label.substring(0, 2);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 見かたの説明
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              Text('たて：こうげきする わざ'),
              Text('よこ：うける ポケモン'),
              Text('◎ 2ばい', style: TextStyle(color: Colors.red)),
              Text('△ はんぶん', style: TextStyle(color: Colors.blue)),
              Text('✕ こうかなし', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        // 縦にも横にもスクロールできる表
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: _cell * 1.3, height: _cell),
                      for (final defend in PokeType.values)
                        _header(defend, vertical: true),
                    ],
                  ),
                  for (final attack in PokeType.values)
                    Row(
                      children: [
                        _header(attack),
                        for (final defend in PokeType.values)
                          _mark(TypeChart.multiplier(attack, defend)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 見出しのマス（タイプの色に短い名前）
  Widget _header(PokeType t, {bool vertical = false}) {
    return Container(
      width: vertical ? _cell : _cell * 1.3,
      height: _cell,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _short(t),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 倍率のマス（◎・△・✕。1倍は空白）
  Widget _mark(double multiplier) {
    final m = _markOf(multiplier);
    return Container(
      width: _cell,
      height: _cell,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      color: Colors.white.withValues(alpha: 0.8),
      child: Text(
        m.mark,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: m.color,
        ),
      ),
    );
  }
}
