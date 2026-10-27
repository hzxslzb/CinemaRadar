import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

abstract interface class ScheduleProvider {
  Future<CinemaSnapshot> fetchCinema(Cinema cinema);
}

abstract interface class CinemaDirectoryProvider {
  Future<List<CityOption>> fetchCities();
  Future<List<DistrictOption>> fetchDistricts(CityOption city);
  Future<List<Cinema>> fetchCinemas({
    required CityOption city,
    required DistrictOption district,
  });
}

class MaoyanCinemaDirectoryProvider implements CinemaDirectoryProvider {
  MaoyanCinemaDirectoryProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  Future<List<CityOption>>? _citiesRequest;
  final Map<int, Future<List<DistrictOption>>> _districtRequests = {};
  final Map<String, Future<List<Cinema>>> _cinemaRequests = {};

  @override
  Future<List<CityOption>> fetchCities() =>
      _citiesRequest ??= _loadCities().catchError((Object error) {
        _citiesRequest = null;
        throw error;
      });

  Future<List<CityOption>> _loadCities() async {
    final root =
        await _getJson(Uri.https('m.maoyan.com', '/dianying/cities.json'));
    final cities = (root['cts'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => CityOption.fromMaoyan(item as Map<String, dynamic>))
        .where((city) => city.id > 0 && city.name.isNotEmpty)
        .toList();
    if (cities.isEmpty) {
      throw const ScheduleProviderException('猫眼没有返回城市列表');
    }
    return List<CityOption>.unmodifiable(cities);
  }

  @override
  Future<List<DistrictOption>> fetchDistricts(CityOption city) =>
      _districtRequests.putIfAbsent(
        city.id,
        () => _loadDistricts(city).catchError((Object error) {
          _districtRequests.remove(city.id);
          throw error;
        }),
      );

  Future<List<DistrictOption>> _loadDistricts(CityOption city) async {
    final root = await _getJson(Uri.https(
      'm.maoyan.com',
      '/ajax/filterCinemas',
      <String, String>{'ci': '${city.id}'},
    ));
    final district = root['district'] as Map<String, dynamic>?;
    final values = (district?['subItems'] as List<dynamic>? ??
            const <dynamic>[])
        .map((item) => DistrictOption.fromMaoyan(item as Map<String, dynamic>))
        .where((item) => item.name.isNotEmpty)
        .toList();
    if (values.isEmpty) {
      throw ScheduleProviderException('没有查到${city.name}的行政区');
    }
    return List<DistrictOption>.unmodifiable(values);
  }

  @override
  Future<List<Cinema>> fetchCinemas({
    required CityOption city,
    required DistrictOption district,
  }) {
    final key = '${city.id}:${district.id}';
    return _cinemaRequests.putIfAbsent(
      key,
      () => _loadCinemas(city, district).catchError((Object error) {
        _cinemaRequests.remove(key);
        throw error;
      }),
    );
  }

  Future<List<Cinema>> _loadCinemas(
    CityOption city,
    DistrictOption district,
  ) async {
    const pageSize = 100;
    final cinemas = <Cinema>[];
    var offset = 0;
    var hasMore = true;
    while (hasMore && offset < 2000) {
      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final root = await _getJson(Uri.https(
        'm.maoyan.com',
        '/ajax/cinemaList',
        <String, String>{
          'day': day,
          'offset': '$offset',
          'limit': '$pageSize',
          'districtId': '${district.id}',
          'cityId': '${city.id}',
        },
      ));
      final rawCinemas = root['cinemas'] as List<dynamic>? ?? const <dynamic>[];
      for (final raw in rawCinemas) {
        final value = raw as Map<String, dynamic>;
        final id = (value['id'] as num?)?.toInt() ?? 0;
        if (id <= 0) continue;
        cinemas.add(Cinema(
          id: id,
          name: '${value['nm'] ?? ''}',
          cityId: city.id,
          cityName: city.name,
          district: district.id == -1 ? city.name : district.name,
          address: '${value['addr'] ?? ''}',
        ));
      }
      final paging = root['paging'] as Map<String, dynamic>?;
      hasMore = paging?['hasMore'] == true && rawCinemas.isNotEmpty;
      offset += rawCinemas.length;
    }
    final unique = <int, Cinema>{
      for (final cinema in cinemas) cinema.id: cinema
    };
    final result = unique.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List<Cinema>.unmodifiable(result);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri, headers: <String, String>{
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/140.0 Mobile Safari/537.36',
      'Referer': 'https://m.maoyan.com/cinemas',
      'X-Requested-With': 'XMLHttpRequest',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ScheduleProviderException('影院目录返回 HTTP ${response.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (error) {
      throw ScheduleProviderException('无法解析影院目录：$error');
    }
  }
}

List<Cinema> fuzzyFilterCinemas(List<Cinema> cinemas, String query) {
  final needles = query
      .trim()
      .split(RegExp(r'\s+'))
      .map(_normalizeSearch)
      .where((value) => value.isNotEmpty)
      .toList();
  if (needles.isEmpty) return cinemas;
  final result = cinemas.where((cinema) {
    final haystack = _normalizeSearch('${cinema.name}${cinema.address}');
    return needles.every(haystack.contains);
  }).toList();
  result.sort((a, b) {
    final aName = _normalizeSearch(a.name);
    final bName = _normalizeSearch(b.name);
    final aStarts = aName.startsWith(needles.first);
    final bStarts = bName.startsWith(needles.first);
    if (aStarts != bStarts) return aStarts ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return result;
}

String _normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\s\-—_·（）()【】\[\]，,。.：:；;！!？?]+'), '');

class MaoyanScheduleProvider implements ScheduleProvider {
  MaoyanScheduleProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static final String _deviceId = _newDeviceId();

  @override
  Future<CinemaSnapshot> fetchCinema(Cinema cinema) async {
    final uri = Uri.https(
      'm.maoyan.com',
      '/mtrade/cinema/cinema/shows.json',
      <String, String>{
        'cinemaId': '${cinema.id}',
        'ci': '${cinema.cityId}',
        'userid': '',
        'channelId': '4',
      },
    );
    final response = await _client.get(uri, headers: <String, String>{
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/140.0 Mobile Safari/537.36',
      'Referer':
          'https://m.maoyan.com/mtrade/cinema/cinema?cinemaId=${cinema.id}&ci=${cinema.cityId}',
      'X-Requested-With': 'ajax',
      'x-ta': '1',
      'uuid': _deviceId,
      'channelId': '4',
      'X-Channel-ID': '4',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ScheduleProviderException('数据源返回 HTTP ${response.statusCode}');
    }
    try {
      final root = jsonDecode(utf8.decode(response.bodyBytes));
      return CinemaSnapshot.fromMaoyan(root as Map<String, dynamic>);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw ScheduleProviderException('无法解析排片响应：$error');
    }
  }

  static String _newDeviceId() {
    final random = Random.secure();
    return List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join().toUpperCase();
  }
}

class ScheduleProviderException implements Exception {
  const ScheduleProviderException(this.message);
  final String message;

  @override
  String toString() => message;
}
