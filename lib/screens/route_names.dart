/// 画面の名前（MaterialPageRoute の settings.name に入れて、BGM の切りかえに使う）
abstract final class RouteNames {
  static const title = '/'; // 最初の画面（home）は自動で '/' になる
  static const settings = 'settings';
  static const quiz = 'quiz';
  static const result = 'result';
  static const zukan = 'zukan';
  static const zukanDetail = 'zukanDetail';
  static const typeChart = 'typeChart';
  static const dexComplete = 'dexComplete'; // 図鑑かんせいの おめでとう画面
}
