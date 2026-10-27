import 'dart:convert';

import 'package:cinema_radar/app.dart';
import 'package:cinema_radar/app_controller.dart';
import 'package:cinema_radar/data/maoyan_provider.dart';
import 'package:cinema_radar/data/subscription_store.dart';
import 'package:cinema_radar/domain/models.dart';
import 'package:cinema_radar/services/subscription_monitor.dart';
import 'package:cinema_radar/services/ticket_links.dart';
import 'package:cinema_radar/services/notification_service.dart';
import 'package:cinema_radar/utils/session_date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('formats session dates with Chinese weekdays', () {
    expect(formatSessionDate('2026-08-16'), '2026年8月16日 周日');
    expect(
      formatSessionDate('2026-08-17', short: true),
      '8月17日 周一',
    );
    expect(formatSessionDate('待定'), '待定');
    expect(
      buildNewSessionNotificationPreview(const <Session>[
        Session(
          id: 'weekday-preview',
          date: '2026-08-16',
          time: '09:45',
          language: '英语',
          format: 'IMAX2D',
          hall: 'IMAX 激光厅',
          ticketStatus: 0,
        ),
      ]),
      '2026年8月16日 周日 09:45 IMAX 激光厅',
    );
  });

  test('parses Maoyan cinema response and groups Odyssey sessions', () {
    final root = jsonDecode(_fixture) as Map<String, dynamic>;
    final snapshot = CinemaSnapshot.fromMaoyan(
      root,
      fetchedAt: DateTime(2026, 8, 14, 10),
    );

    expect(snapshot.cinemaId, 37534);
    expect(snapshot.cinemaName, contains('MOViE MOViE'));
    expect(snapshot.movies, hasLength(1));
    final odyssey = snapshot.movies.single;
    expect(odyssey.id, 1545360);
    expect(odyssey.name, '奥德赛');
    expect(odyssey.sessions, hasLength(2));
    expect(odyssey.sessionsByDate.keys, ['2026-08-14', '2026-08-15']);
    expect(odyssey.sessions.first.canBuy, isTrue);
  });

  test('detects only unseen seqNo values as new sessions', () {
    const sessions = <Session>[
      Session(
        id: 'old',
        date: '2026-08-14',
        time: '10:00',
        language: '英语',
        format: 'IMAX2D',
        hall: 'IMAX 激光厅',
        ticketStatus: 0,
      ),
      Session(
        id: 'new',
        date: '2026-08-15',
        time: '13:00',
        language: '英语',
        format: '2D',
        hall: '2号厅',
        ticketStatus: 0,
      ),
    ];

    final added = detectNewSessions(sessions, <String>{'old'});
    expect(added.map((item) => item.id), ['new']);
  });

  test('sorts sessions by start time and groups normal versus special halls',
      () {
    const sessions = <Session>[
      Session(
        id: 'normal',
        date: '2026-08-15',
        time: '09:30',
        language: '英语',
        format: '2D',
        hall: '2号厅',
        ticketStatus: 0,
      ),
      Session(
        id: 'dolby',
        date: '2026-08-14',
        time: '20:00',
        language: '英语',
        format: '杜比视界',
        hall: 'Dolby Cinema',
        ticketStatus: 0,
      ),
      Session(
        id: 'imax',
        date: '2026-08-14',
        time: '18:00',
        language: '英语',
        format: 'IMAX2D',
        hall: 'IMAX 激光厅',
        ticketStatus: 0,
      ),
    ];
    const movie = MovieSchedule(
      id: 1,
      name: '测试电影',
      durationMinutes: 100,
      description: '',
      posterUrl: '',
      sessions: sessions,
    );

    expect(
      movie.visibleSessions().map((item) => item.id),
      <String>['imax', 'dolby', 'normal'],
    );
    expect(
      movie
          .visibleSessions(category: SessionHallCategory.standard)
          .map((item) => item.id),
      <String>['normal'],
    );
    expect(sessions[1].hallCategory, SessionHallCategory.dolby);
    expect(sessions[2].hallCategory, SessionHallCategory.imax);
  });

  test('loads and caches city, district and district-scoped cinema directories',
      () async {
    var calls = 0;
    final provider = MaoyanCinemaDirectoryProvider(
      client: MockClient((request) async {
        calls++;
        if (request.url.path == '/dianying/cities.json') {
          return http.Response(
            '{"cts":[{"id":10,"nm":"上海","py":"shanghai"},'
            '{"id":1,"nm":"北京","py":"beijing"}]}',
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        if (request.url.path == '/ajax/filterCinemas') {
          return http.Response(
            '{"district":{"subItems":[{"id":5,"name":"浦东新区","count":2}]}}',
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        return http.Response(
          '{"cinemas":['
          '{"id":37534,"nm":"MOViE MOViE 影城（前滩太古里店）",'
          '"addr":"浦东新区东育路500弄1-9号"},'
          '{"id":27664,"nm":"CGV影城（晶耀前滩店）",'
          '"addr":"浦东新区耀体路308号"}],'
          '"paging":{"hasMore":false,"offset":0,"limit":100,"total":2}}',
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
    );

    final cities = await provider.fetchCities();
    final districts = await provider.fetchDistricts(cities.first);
    final cinemas = await provider.fetchCinemas(
      city: cities.first,
      district: districts.first,
    );
    expect(cities.map((item) => item.name), <String>['上海', '北京']);
    expect(districts.single.name, '浦东新区');
    expect(fuzzyFilterCinemas(cinemas, 'movie 前滩').length, 1);

    await provider.fetchCities();
    await provider.fetchDistricts(cities.first);
    await provider.fetchCinemas(
      city: cities.first,
      district: districts.first,
    );
    expect(calls, 3, reason: '相同目录应命中端侧内存缓存');
  });

  test('keeps exact Maoyan seat URL and separate Taopiaopiao routes', () {
    const session = Session(
      id: 'seq-1',
      date: '2026-08-14',
      time: '18:00',
      language: '英语',
      format: '2D',
      hall: '1号厅',
      ticketStatus: 0,
    );
    const movie = MovieSchedule(
      id: 1545360,
      name: '奥德赛',
      durationMinutes: 172,
      description: '',
      posterUrl: '',
      sessions: <Session>[session],
    );
    final maoyan = TicketLinks.maoyanWeb(
      cinema: knownCinemas.first,
      movie: movie,
      session: session,
    );
    expect(maoyan.queryParameters['seqNo'], 'seq-1');
    expect(maoyan.queryParameters['cinemaId'], '37534');
    expect(TicketLinks.taopiaopiaoApp.scheme, 'tbmovie');
    expect(TicketLinks.taopiaopiaoAlipay.scheme, 'alipays');
    expect(TicketLinks.taopiaopiaoWeb.host, 'h5.m.taopiaopiao.com');
  });

  test('subscription serialization preserves the baseline session set', () {
    final subscription = MovieSubscription(
      cinema: knownCinemas.first,
      movieId: 1545360,
      movieName: '奥德赛',
      seenSessionIds: <String>{'a', 'b'},
      createdAt: DateTime(2026, 8, 14),
    );

    final decoded = MovieSubscription.decodeList(
      MovieSubscription.encodeList(<MovieSubscription>[subscription]),
    ).single;
    expect(decoded.key, subscription.key);
    expect(decoded.seenSessionIds, <String>{'a', 'b'});
  });

  test('persists theme and refresh settings and removes legacy cinema cache',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dark_theme_v1': true,
      'refresh_minutes_v1': 120,
      'custom_cinemas_v1': '[]',
    });
    final snapshot = CinemaSnapshot.fromMaoyan(
      jsonDecode(_fixture) as Map<String, dynamic>,
    );
    final controller = AppController(provider: _FakeProvider(snapshot));
    await controller.initialize();

    expect(controller.darkMode, isTrue);
    expect(controller.refreshInterval.minutes, 120);
    expect(foregroundRefreshInterval, const Duration(minutes: 3));
    expect(refreshIntervalOptions.first.androidBackgroundDuration,
        const Duration(minutes: 15));
    await controller.toggleTheme();
    await controller.setRefreshInterval(refreshIntervalOptions.first);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('dark_theme_v1'), isFalse);
    expect(preferences.getInt('refresh_minutes_v1'), 5);
    expect(preferences.containsKey('custom_cinemas_v1'), isFalse);
    controller.dispose();
  });

  testWidgets('renders the regression cinema, Odyssey and session action',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final snapshot = CinemaSnapshot.fromMaoyan(
      jsonDecode(_fixture) as Map<String, dynamic>,
    );
    final controller = AppController(provider: _FakeProvider(snapshot));
    await controller.initialize();

    await tester.pumpWidget(CinemaRadarApp(
      controller: controller,
      home: CinemaHomePage(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('场次雷达'), findsOneWidget);
    expect(find.text('奥德赛'), findsWidgets);
    expect(find.text('购票 / 选座'), findsWidgets);
    expect(find.text('订阅新场次'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('opens subscription drawer, toggles dark mode, jumps and deletes',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final base = CinemaSnapshot.fromMaoyan(
      jsonDecode(_fixture) as Map<String, dynamic>,
    );
    const otherMovie = MovieSchedule(
      id: 99,
      name: '另一部电影',
      durationMinutes: 90,
      description: '',
      posterUrl: '',
      sessions: <Session>[],
    );
    final snapshot = CinemaSnapshot(
      cinemaId: base.cinemaId,
      cinemaName: base.cinemaName,
      movies: <MovieSchedule>[...base.movies, otherMovie],
      fetchedAt: base.fetchedAt,
    );
    final controller = AppController(provider: _FakeProvider(snapshot));
    await controller.initialize();
    controller.selectMovie(otherMovie);
    controller.subscriptions.add(MovieSubscription(
      cinema: knownCinemas.first,
      movieId: base.movies.single.id,
      movieName: base.movies.single.name,
      seenSessionIds:
          base.movies.single.sessions.map((item) => item.id).toSet(),
      createdAt: DateTime(2026, 8, 14),
    ));

    await tester.pumpWidget(CinemaRadarApp(
      controller: controller,
      home: CinemaHomePage(controller: controller),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('切换深色模式'));
    await tester.pumpAndSettle();
    expect(controller.darkMode, isTrue);
    expect(
      Theme.of(tester.element(find.text('场次雷达'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byTooltip('管理订阅'));
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    expect(drawer, findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.text('奥德赛')),
        findsOneWidget);
    expect(find.text('后台订阅刷新间隔'), findsOneWidget);
    expect(find.textContaining('前台固定每 3 分钟刷新'), findsOneWidget);

    await tester.tap(
      find.descendant(of: drawer, matching: find.text('奥德赛')),
    );
    await tester.pumpAndSettle();
    expect(controller.selectedMovie?.name, '奥德赛');
    expect(find.byType(Drawer), findsNothing);

    await tester.tap(find.byTooltip('管理订阅'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除订阅'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(controller.subscriptions, isEmpty);
    expect(find.text('还没有影片订阅'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('shows, dismisses and shows the next persisted new-session alert',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SubscriptionStore();
    final firstAlert = _newSessionAlert('batch-1', 'new-1');
    await store.saveNewSessionAlert(firstAlert);
    final snapshot = CinemaSnapshot.fromMaoyan(
      jsonDecode(_fixture) as Map<String, dynamic>,
    );
    final controller = AppController(
      provider: _FakeProvider(snapshot),
      store: store,
    );
    await controller.initialize();

    await tester.pumpWidget(CinemaRadarApp(
      controller: controller,
      home: CinemaHomePage(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('发现 1 个新场次'), findsOneWidget);
    expect(find.textContaining('猫眼 8月16日 周日 09:45'), findsOneWidget);
    expect(find.text('查看完整排片'), findsOneWidget);
    expect(find.text('淘票票 App'), findsOneWidget);
    expect(find.byTooltip('展开场次信息'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-session-horizontal-scroll')),
        findsOneWidget);

    await tester.tap(find.byTooltip('展开场次信息'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('收起场次信息'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('expanded-new-session-new-1')),
      findsOneWidget,
    );
    final verticalScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('new-session-vertical-scroll-expanded')),
    );
    expect(verticalScroll.scrollDirection, Axis.vertical);

    await tester.tap(find.byTooltip('收起场次信息'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('展开场次信息'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭本次新场次提醒'));
    await tester.pumpAndSettle();
    expect(find.text('发现 1 个新场次'), findsNothing);
    expect(await store.loadNewSessionAlert(), isNull);

    final nextAlert = _newSessionAlert('batch-2', 'new-2');
    await store.saveNewSessionAlert(nextAlert);
    await controller.reloadNewSessionAlert();
    await tester.pumpAndSettle();
    expect(find.text('发现 1 个新场次'), findsOneWidget);
    expect(controller.newSessionAlert?.id, 'batch-2');

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

NewSessionAlert _newSessionAlert(String id, String sessionId) {
  final subscription = MovieSubscription(
    cinema: knownCinemas.first,
    movieId: 1545360,
    movieName: '奥德赛',
    seenSessionIds: <String>{'old'},
    createdAt: DateTime(2026, 8, 14),
  );
  return NewSessionAlert(
    id: id,
    createdAt: DateTime(2026, 8, 16, 9),
    notices: <NewSessionNotice>[
      NewSessionNotice(
        subscription: subscription,
        sessions: <Session>[
          Session(
            id: sessionId,
            date: '2026-08-16',
            time: '09:45',
            language: '英语',
            format: 'IMAX2D',
            hall: 'IMAX 激光厅',
            ticketStatus: 0,
          ),
        ],
      ),
    ],
  );
}

class _FakeProvider implements ScheduleProvider {
  const _FakeProvider(this.snapshot);
  final CinemaSnapshot snapshot;

  @override
  Future<CinemaSnapshot> fetchCinema(Cinema cinema) async => snapshot;
}

const _fixture = '''
{
  "code": 0,
  "success": true,
  "data": {
    "cinemaId": 37534,
    "cinemaName": "MOViE MOViE 影城（前滩太古里店）",
    "movies": [
      {
        "id": 1545360,
        "nm": "奥德赛",
        "dur": 172,
        "desc": "172分钟 | 动作",
        "img": "https://example.test/poster.jpg",
        "shows": [
          {
            "showDate": "2026-08-14",
            "plist": [
              {
                "seqNo": "202608140033128",
                "tm": "19:30",
                "dt": "2026-08-14",
                "lang": "英语",
                "tp": "IMAX2D",
                "th": "IMAX 激光厅",
                "ticketStatus": 0
              }
            ]
          },
          {
            "showDate": "2026-08-15",
            "plist": [
              {
                "seqNo": "202608150191830",
                "tm": "20:45",
                "dt": "2026-08-15",
                "lang": "英语",
                "tp": "2D",
                "th": "2号厅",
                "ticketStatus": 1
              }
            ]
          }
        ]
      }
    ]
  }
}
''';
