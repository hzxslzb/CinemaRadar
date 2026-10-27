// ignore_for_file: avoid_print

import 'package:cinema_radar/data/maoyan_provider.dart';
import 'package:cinema_radar/domain/models.dart';

Future<void> main() async {
  final directory = MaoyanCinemaDirectoryProvider();
  final cities = await directory.fetchCities();
  if (cities.length < 1000) {
    throw StateError('回归失败：城市列表异常，仅 ${cities.length} 个');
  }
  final shanghai = cities.singleWhere((city) => city.id == 10);
  final districts = await directory.fetchDistricts(shanghai);
  final pudong = districts.singleWhere((district) => district.name == '浦东新区');
  final pudongCinemas = await directory.fetchCinemas(
    city: shanghai,
    district: pudong,
  );
  if (!pudongCinemas.any((cinema) => cinema.id == 37534)) {
    throw StateError('回归失败：浦东新区影院列表中没有 MOViE MOViE 前滩店');
  }
  print('PASS cities=${cities.length} districts=${districts.length} '
      'pudongCinemas=${pudongCinemas.length}');

  final cinema = knownCinemas.first;
  final snapshot = await MaoyanScheduleProvider().fetchCinema(cinema);
  final odyssey = snapshot.movies.where((movie) => movie.name == '奥德赛');
  if (odyssey.isEmpty) {
    throw StateError('回归失败：${cinema.name} 当前响应中没有《奥德赛》');
  }
  final movie = odyssey.single;
  print('PASS ${snapshot.cinemaName}');
  print('movieId=${movie.id} sessions=${movie.sessions.length}');
  for (final entry in movie.sessionsByDate.entries) {
    final times = entry.value.map((session) => session.time).join(', ');
    print('${entry.key}: $times');
  }
}
