import '../domain/models.dart';

class TicketLinks {
  const TicketLinks._();

  static Uri maoyanWeb({
    required Cinema cinema,
    required MovieSchedule movie,
    required Session session,
  }) =>
      maoyanWebForSession(
        cinema: cinema,
        movieId: movie.id,
        session: session,
      );

  static Uri maoyanWebForSession({
    required Cinema cinema,
    required int movieId,
    required Session session,
  }) =>
      Uri.https(
        'm.maoyan.com',
        '/mtrade/cinema/seat',
        <String, String>{
          'seqNo': session.id,
          'cinemaId': '${cinema.id}',
          'movieId': '$movieId',
          'ci': '${cinema.cityId}',
        },
      );

  /// 猫眼官方唤端页：已安装时打开 App，否则展示下载/打开页。
  static Uri get maoyanApp => Uri.https(
        'deeplink.maoyan.com',
        '/maoyan-app/app',
        <String, String>{'channel': 'CinemaRadar'},
      );

  /// 淘票票当前 H5 前端使用的原生客户端 scheme。
  static Uri get taopiaopiaoApp => Uri.parse('tbmovie://taobao.com/');

  /// 支付宝内的淘票票入口。猫眼与淘票票场次 ID 不互通，因此不拼接场次。
  static Uri get taopiaopiaoAlipay =>
      Uri.parse('alipays://platformapi/startapp?appId=20000131');

  static Uri get taopiaopiaoWeb => Uri.parse('https://h5.m.taopiaopiao.com/');
}
