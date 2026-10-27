import 'dart:convert';

class CityOption {
  const CityOption({
    required this.id,
    required this.name,
    required this.pinyin,
  });

  final int id;
  final String name;
  final String pinyin;

  String get searchText => '$name $pinyin $id'.toLowerCase();

  factory CityOption.fromMaoyan(Map<String, dynamic> json) => CityOption(
        id: (json['id'] as num).toInt(),
        name: '${json['nm'] ?? ''}',
        pinyin: '${json['py'] ?? ''}',
      );

  @override
  bool operator ==(Object other) => other is CityOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class DistrictOption {
  const DistrictOption({
    required this.id,
    required this.name,
    required this.cinemaCount,
  });

  final int id;
  final String name;
  final int cinemaCount;

  factory DistrictOption.fromMaoyan(Map<String, dynamic> json) =>
      DistrictOption(
        id: (json['id'] as num).toInt(),
        name: '${json['name'] ?? ''}',
        cinemaCount: (json['count'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is DistrictOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class RefreshIntervalOption {
  const RefreshIntervalOption(this.minutes, this.label);

  final int minutes;
  final String label;

  Duration get duration => Duration(minutes: minutes);

  Duration get androidBackgroundDuration =>
      Duration(minutes: minutes < 15 ? 15 : minutes);
}

const foregroundRefreshInterval = Duration(minutes: 3);

const refreshIntervalOptions = <RefreshIntervalOption>[
  RefreshIntervalOption(5, '5 分钟'),
  RefreshIntervalOption(10, '10 分钟'),
  RefreshIntervalOption(15, '15 分钟'),
  RefreshIntervalOption(20, '20 分钟'),
  RefreshIntervalOption(25, '25 分钟'),
  RefreshIntervalOption(30, '30 分钟'),
  RefreshIntervalOption(60, '1 小时'),
  RefreshIntervalOption(120, '2 小时'),
  RefreshIntervalOption(180, '3 小时'),
  RefreshIntervalOption(720, '12 小时'),
  RefreshIntervalOption(1440, '24 小时'),
];

class Cinema {
  const Cinema({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    required this.district,
    this.address = '',
  });

  final int id;
  final String name;
  final int cityId;
  final String cityName;
  final String district;
  final String address;

  String get key => '$cityId:$id';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'cityId': cityId,
        'cityName': cityName,
        'district': district,
        'address': address,
      };

  factory Cinema.fromJson(Map<String, dynamic> json) => Cinema(
        id: json['id'] as int,
        name: json['name'] as String,
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String,
        district: json['district'] as String,
        address: '${json['address'] ?? ''}',
      );
}

const knownCinemas = <Cinema>[
  Cinema(
    id: 37534,
    name: 'MOViE MOViE 影城（前滩太古里店）',
    cityId: 10,
    cityName: '上海',
    district: '浦东新区 · 前滩',
  ),
  Cinema(
    id: 27664,
    name: 'CGV影城（晶耀前滩店）',
    cityId: 10,
    cityName: '上海',
    district: '浦东新区 · 前滩',
  ),
  Cinema(
    id: 227,
    name: '上海影城（SHO）',
    cityId: 10,
    cityName: '上海',
    district: '长宁区 · 新华路',
  ),
  Cinema(
    id: 25516,
    name: '博悦汇影城（BFC外滩金融中心店）',
    cityId: 10,
    cityName: '上海',
    district: '黄浦区 · 外滩',
  ),
];

enum SessionHallCategory {
  standard('普通厅'),
  imax('IMAX'),
  dolby('Dolby'),
  otherSpecial('其他特效厅');

  const SessionHallCategory(this.label);
  final String label;
}

enum SessionSortOrder {
  ascending('时间升序'),
  descending('时间降序');

  const SessionSortOrder(this.label);
  final String label;
}

class Session {
  const Session({
    required this.id,
    required this.date,
    required this.time,
    required this.language,
    required this.format,
    required this.hall,
    required this.ticketStatus,
  });

  final String id;
  final String date;
  final String time;
  final String language;
  final String format;
  final String hall;
  final int ticketStatus;

  bool get canBuy => ticketStatus == 0 || ticketStatus == 5;

  DateTime? get startsAt => DateTime.tryParse('$date $time');

  SessionHallCategory get hallCategory {
    final source = '$format $hall'.toUpperCase().replaceAll(' ', '');
    if (source.contains('IMAX')) return SessionHallCategory.imax;
    if (source.contains('DOLBY') ||
        source.contains('杜比') ||
        source.contains('ATMOS')) {
      return SessionHallCategory.dolby;
    }
    const specialKeywords = <String>[
      'CINITY',
      '中国巨幕',
      'CGS',
      'SCREENX',
      '4DX',
      'MX4D',
      'LUXE',
      'LED厅',
      '激光厅',
    ];
    if (specialKeywords.any(source.contains)) {
      return SessionHallCategory.otherSpecial;
    }
    return SessionHallCategory.standard;
  }

  String get statusLabel => switch (ticketStatus) {
        0 => '可购',
        1 => '满座',
        2 || 3 => '停售',
        5 => '特惠',
        _ => '未知',
      };

  factory Session.fromMaoyan(Map<String, dynamic> json) => Session(
        id: '${json['seqNo'] ?? ''}',
        date: '${json['dt'] ?? ''}',
        time: '${json['tm'] ?? ''}',
        language: '${json['lang'] ?? ''}',
        format: '${json['tp'] ?? ''}',
        hall: '${json['th'] ?? ''}',
        ticketStatus: (json['ticketStatus'] as num?)?.toInt() ?? -1,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        'time': time,
        'language': language,
        'format': format,
        'hall': hall,
        'ticketStatus': ticketStatus,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        language: json['language'] as String,
        format: json['format'] as String,
        hall: json['hall'] as String,
        ticketStatus: json['ticketStatus'] as int,
      );
}

class MovieSchedule {
  const MovieSchedule({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.description,
    required this.posterUrl,
    required this.sessions,
  });

  final int id;
  final String name;
  final int durationMinutes;
  final String description;
  final String posterUrl;
  final List<Session> sessions;

  Map<String, List<Session>> get sessionsByDate {
    final result = <String, List<Session>>{};
    for (final session in sessions) {
      result.putIfAbsent(session.date, () => <Session>[]).add(session);
    }
    return result;
  }

  List<Session> visibleSessions({
    SessionHallCategory? category,
    SessionSortOrder order = SessionSortOrder.ascending,
  }) {
    final result = sessions
        .where(
            (session) => category == null || session.hallCategory == category)
        .toList();
    result.sort((a, b) {
      final aTime = a.startsAt;
      final bTime = b.startsAt;
      final comparison = aTime == null || bTime == null
          ? '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}')
          : aTime.compareTo(bTime);
      return order == SessionSortOrder.ascending ? comparison : -comparison;
    });
    return result;
  }

  factory MovieSchedule.fromMaoyan(Map<String, dynamic> json) {
    final sessions = <Session>[];
    for (final day in (json['shows'] as List<dynamic>? ?? const [])) {
      final dayMap = day as Map<String, dynamic>;
      for (final raw in (dayMap['plist'] as List<dynamic>? ?? const [])) {
        final session = Session.fromMaoyan(raw as Map<String, dynamic>);
        if (session.id.isNotEmpty) sessions.add(session);
      }
    }
    return MovieSchedule(
      id: (json['id'] as num).toInt(),
      name: '${json['nm'] ?? '未知影片'}',
      durationMinutes: (json['dur'] as num?)?.toInt() ?? 0,
      description: '${json['desc'] ?? ''}',
      posterUrl: '${json['img'] ?? ''}'.replaceAll('w.h', '260.360'),
      sessions: sessions,
    );
  }
}

class CinemaSnapshot {
  const CinemaSnapshot({
    required this.cinemaId,
    required this.cinemaName,
    required this.movies,
    required this.fetchedAt,
  });

  final int cinemaId;
  final String cinemaName;
  final List<MovieSchedule> movies;
  final DateTime fetchedAt;

  factory CinemaSnapshot.fromMaoyan(
    Map<String, dynamic> root, {
    DateTime? fetchedAt,
  }) {
    if (root['success'] != true || root['data'] is! Map<String, dynamic>) {
      throw const FormatException('猫眼返回了非预期响应');
    }
    final data = root['data'] as Map<String, dynamic>;
    final movies = (data['movies'] as List<dynamic>? ?? const [])
        .map((item) => MovieSchedule.fromMaoyan(item as Map<String, dynamic>))
        .where((movie) => movie.sessions.isNotEmpty)
        .toList()
      ..sort((a, b) => b.sessions.length.compareTo(a.sessions.length));
    return CinemaSnapshot(
      cinemaId: (data['cinemaId'] as num).toInt(),
      cinemaName: '${data['cinemaName'] ?? ''}',
      movies: movies,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }
}

class MovieSubscription {
  const MovieSubscription({
    required this.cinema,
    required this.movieId,
    required this.movieName,
    required this.seenSessionIds,
    required this.createdAt,
    this.lastCheckedAt,
  });

  final Cinema cinema;
  final int movieId;
  final String movieName;
  final Set<String> seenSessionIds;
  final DateTime createdAt;
  final DateTime? lastCheckedAt;

  String get key => '${cinema.key}:$movieId';

  MovieSubscription copyWith({
    Set<String>? seenSessionIds,
    DateTime? lastCheckedAt,
  }) =>
      MovieSubscription(
        cinema: cinema,
        movieId: movieId,
        movieName: movieName,
        seenSessionIds: seenSessionIds ?? this.seenSessionIds,
        createdAt: createdAt,
        lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cinema': cinema.toJson(),
        'movieId': movieId,
        'movieName': movieName,
        'seenSessionIds': seenSessionIds.toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      };

  factory MovieSubscription.fromJson(Map<String, dynamic> json) =>
      MovieSubscription(
        cinema: Cinema.fromJson(json['cinema'] as Map<String, dynamic>),
        movieId: json['movieId'] as int,
        movieName: json['movieName'] as String,
        seenSessionIds: (json['seenSessionIds'] as List<dynamic>)
            .map((value) => value as String)
            .toSet(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastCheckedAt: json['lastCheckedAt'] == null
            ? null
            : DateTime.parse(json['lastCheckedAt'] as String),
      );

  static String encodeList(List<MovieSubscription> values) =>
      jsonEncode(values.map((value) => value.toJson()).toList());

  static List<MovieSubscription> decodeList(String source) => (jsonDecode(
          source) as List<dynamic>)
      .map((item) => MovieSubscription.fromJson(item as Map<String, dynamic>))
      .toList();
}

class NewSessionNotice {
  const NewSessionNotice({
    required this.subscription,
    required this.sessions,
  });

  final MovieSubscription subscription;
  final List<Session> sessions;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'subscription': subscription.toJson(),
        'sessions': sessions.map((value) => value.toJson()).toList(),
      };

  factory NewSessionNotice.fromJson(Map<String, dynamic> json) =>
      NewSessionNotice(
        subscription: MovieSubscription.fromJson(
          json['subscription'] as Map<String, dynamic>,
        ),
        sessions: (json['sessions'] as List<dynamic>)
            .map((value) => Session.fromJson(value as Map<String, dynamic>))
            .toList(),
      );
}

class NewSessionAlert {
  const NewSessionAlert({
    required this.id,
    required this.createdAt,
    required this.notices,
  });

  final String id;
  final DateTime createdAt;
  final List<NewSessionNotice> notices;

  int get sessionCount => notices.fold<int>(
        0,
        (total, notice) => total + notice.sessions.length,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'notices': notices.map((value) => value.toJson()).toList(),
      };

  factory NewSessionAlert.fromJson(Map<String, dynamic> json) =>
      NewSessionAlert(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        notices: (json['notices'] as List<dynamic>)
            .map(
              (value) =>
                  NewSessionNotice.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static NewSessionAlert decode(String source) => NewSessionAlert.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
}
