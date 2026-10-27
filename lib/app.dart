import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'data/maoyan_provider.dart';
import 'domain/models.dart';
import 'services/ticket_links.dart';
import 'utils/session_date_format.dart';
import 'widgets/cinema_search_dialog.dart';

bool get _isHarmonyOS => !kIsWeb && Platform.operatingSystem == 'ohos';
bool get _isMacOS => !kIsWeb && Platform.isMacOS;

Future<void> _launchExternalLink(
  BuildContext context,
  Uri uri, {
  Uri? fallback,
}) async {
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && fallback != null) {
      launched = await launchUrl(
        fallback,
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (_) {
    if (fallback != null) {
      try {
        launched = await launchUrl(
          fallback,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }
  }
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开购票入口，请检查浏览器或对应 App')),
    );
  }
}

class CinemaRadarApp extends StatefulWidget {
  const CinemaRadarApp({super.key, this.home, this.controller});

  final Widget? home;
  final AppController? controller;

  @override
  State<CinemaRadarApp> createState() => _CinemaRadarAppState();
}

class _CinemaRadarAppState extends State<CinemaRadarApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? AppController();
    if (widget.controller == null) controller.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CinemaRadar',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: widget.home ?? CinemaHomePage(controller: controller),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    const red = Color(0xFFE6534E);
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      brightness: brightness,
      surface: dark ? const Color(0xFF141414) : const Color(0xFFF6F3ED),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final onSurface = scheme.onSurface;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        displaySmall: TextStyle(
          color: onSurface,
          fontSize: 34,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineSmall: TextStyle(
          color: onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1D1D1D) : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: dark ? const Color(0xFF191919) : scheme.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? scheme.primary : const Color(0xFF151515),
          foregroundColor: dark ? scheme.onPrimary : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: dark,
        fillColor: dark ? scheme.surfaceContainerHighest : null,
        border: const OutlineInputBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF1D1D1D) : Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF1D1D1D) : Colors.white,
      ),
    );
  }
}

class CinemaHomePage extends StatefulWidget {
  const CinemaHomePage({super.key, this.controller, this.directoryProvider});

  final AppController? controller;
  final CinemaDirectoryProvider? directoryProvider;

  @override
  State<CinemaHomePage> createState() => _CinemaHomePageState();
}

class _CinemaHomePageState extends State<CinemaHomePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final AppController controller;
  late final CinemaDirectoryProvider directoryProvider;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? (AppController()..initialize());
    directoryProvider =
        widget.directoryProvider ?? MaoyanCinemaDirectoryProvider();
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final alert = controller.newSessionAlert;
        return Scaffold(
          key: scaffoldKey,
          endDrawer: _SubscriptionDrawer(controller: controller),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  children: <Widget>[
                    if (alert != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: _NewSessionAlertBar(
                          alert: alert,
                          onDismiss: controller.dismissNewSessionAlert,
                          onOpenNotice: controller.openNewSessionNotice,
                        ),
                      ),
                    Expanded(
                      child: CustomScrollView(
                        slivers: <Widget>[
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              alert == null ? 24 : 14,
                              20,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                                child: _buildHeader(context)),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                            sliver:
                                SliverToBoxAdapter(child: _buildCinemaPicker()),
                          ),
                          if (controller.error != null)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              sliver: SliverToBoxAdapter(child: _buildError()),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 42),
                            sliver: SliverToBoxAdapter(child: _buildContent()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final snapshot = controller.snapshot;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Image.asset(
            'assets/branding/cinema_radar_icon.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('场次雷达', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 5),
              Text(
                snapshot == null
                    ? '端侧运行 · 正在连接数据源'
                    : '端侧运行 · ${_time(snapshot.fetchedAt)} 更新 · 前台每 3 分钟刷新',
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '管理订阅',
          onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
          icon: Badge.count(
            count: controller.subscriptions.length,
            isLabelVisible: controller.subscriptions.isNotEmpty,
            child: const Icon(Icons.subscriptions_outlined),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: controller.darkMode ? '切换浅色模式' : '切换深色模式',
          onPressed: controller.toggleTheme,
          icon: Icon(
            controller.darkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: '数据与购票说明',
          onPressed: () => _showAbout(context),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    );
  }

  Widget _buildCinemaPicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _Label(
              icon: Icons.location_on_outlined,
              text: controller.cinema.cityName,
            ),
            SizedBox(
              width: 390,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '当前临时查看影院',
                  isDense: true,
                ),
                child: Text(
                  controller.cinema.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _Label(icon: Icons.map_outlined, text: controller.cinema.district),
            OutlinedButton.icon(
              onPressed: () => _showSwitchCinema(context),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('切换影院'),
            ),
            FilledButton.icon(
              onPressed: controller.loading
                  ? null
                  : controller.refreshAndCheckSubscriptions,
              icon: controller.loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('立即刷新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSwitchCinema(BuildContext context) async {
    final cinema = await showDialog<Cinema>(
      context: context,
      builder: (context) => CinemaSearchDialog(provider: directoryProvider),
    );
    if (cinema != null) await controller.switchCinema(cinema);
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '刷新失败：${controller.error}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final snapshot = controller.snapshot;
    if (snapshot == null) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.movies.isEmpty) {
      return const SizedBox(
        height: 320,
        child: Center(child: Text('该影院目前没有可展示的排片')),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final movies = _MovieList(
          movies: snapshot.movies,
          selected: controller.selectedMovie,
          onSelected: controller.selectMovie,
        );
        final schedule = _SchedulePanel(
          cinema: controller.cinema,
          movie: controller.selectedMovie!,
          subscribed: controller.isSubscribed(controller.selectedMovie!),
          refreshInterval: controller.refreshInterval,
          onSubscriptionChanged: _toggleSelectedMovieSubscription,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 330, height: 700, child: movies),
              const SizedBox(width: 18),
              Expanded(child: schedule),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 182, child: movies),
            const SizedBox(height: 16),
            schedule,
          ],
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    final refreshBoundary = _isHarmonyOS
        ? '鸿蒙版在前台固定每 3 分钟刷新。由于系统 Work Scheduler 不提供分钟级准实时保证，当前不启用后台轮询；应用回到前台后会继续检查已保存订阅。'
        : _isMacOS
            ? '应用在前台时固定每 3 分钟刷新；关闭窗口后进程保持运行，并按 ${controller.refreshInterval.label} 检查订阅。存在订阅时会尝试注册登录时启动，若需用户批准可从后台设置直达系统登录项。'
            : '应用在前台时固定每 3 分钟刷新；当前选择的 Android 后台订阅间隔为 ${controller.refreshInterval.label}。Android 周期后台任务受系统限制，最短为 15 分钟且可能被省电策略延后。';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据与购票边界'),
        content: SizedBox(
          width: 520,
          child: Text(
            '当前版本直接读取猫眼公开移动网页使用的定向影院排片数据，接口并非猫眼公开承诺的开发者 API，可能随时变更或触发风控。应用不会全城扫描：只刷新当前影院，并按影院合并后台订阅请求。\n\n'
            '$refreshBoundary 影院切换不留历史，只持久化影片订阅所需的影院信息。\n\n'
            '购票菜单保留猫眼具体场次网页，并提供猫眼官方唤端页、支付宝内淘票票和淘票票网页。猫眼与淘票票场次编号不互通，因此淘票票入口需要重新选场。\n\n'
            '本应用不保存账号或支付信息，也不会调用未授权的锁座/出票接口。正式商用应接入猫眼、淘票票或影院票务系统的签约能力。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSelectedMovieSubscription() async {
    final movie = controller.selectedMovie;
    if (movie == null) return;
    final added = await controller.toggleSubscription(movie);
    if (!added ||
        !mounted ||
        !controller.backgroundAccessStatus.needsAttention) {
      return;
    }
    await _showBackgroundAccessDialog();
  }

  Future<void> _showBackgroundAccessDialog() async {
    final status = controller.backgroundAccessStatus;
    final harmony = _isHarmonyOS;
    final macOS = _isMacOS;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(harmony
            ? '完善后台提醒设置'
            : macOS
                ? '允许登录时启动'
                : '允许后台排片检查'),
        content: SizedBox(
          width: 480,
          child: Text(
            harmony
                ? '订阅已保存，通知提醒默认开启。鸿蒙手机不允许排片工具申请真正的长期常驻；系统会按省电策略决定后台活动。建议在应用设置中允许通知和后台活动。回到应用时会立即补查。'
                : macOS
                    ? '订阅已保存。关闭 CinemaRadar 窗口后应用会继续在后台检查；同时已尝试注册“登录时启动”。如果 macOS 需要批准，请在系统设置的登录项中允许 CinemaRadar。'
                    : '订阅已保存，Android 周期后台检查也已默认安排。为降低被省电策略延后的概率，建议允许通知，并在系统的电池优化页中允许 CinemaRadar 后台运行。系统仍可因 Doze、低电量或无网络延后执行。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后'),
          ),
          if (status.notificationsEnabled == false)
            TextButton(
              onPressed: () async {
                await controller.requestNotificationAccess();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('允许通知'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final opened = await controller.openBackgroundSettings();
              if (!opened && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('无法打开系统设置，请手动打开 CinemaRadar 的应用设置')),
                );
              }
            },
            child: const Text('去系统设置'),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _NewSessionAlertBar extends StatefulWidget {
  const _NewSessionAlertBar({
    required this.alert,
    required this.onDismiss,
    required this.onOpenNotice,
  });

  final NewSessionAlert alert;
  final Future<void> Function() onDismiss;
  final Future<void> Function(NewSessionNotice notice) onOpenNotice;

  @override
  State<_NewSessionAlertBar> createState() => _NewSessionAlertBarState();
}

class _NewSessionAlertBarState extends State<_NewSessionAlertBar> {
  bool expanded = false;

  @override
  void didUpdateWidget(covariant _NewSessionAlertBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert.id != widget.alert.id) expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heightFactor = expanded ? 0.68 : 0.42;
    final minHeight = expanded ? 360.0 : 240.0;
    final maxAllowedHeight = expanded ? 680.0 : 420.0;
    final maxHeight = (MediaQuery.sizeOf(context).height * heightFactor)
        .clamp(minHeight, maxAllowedHeight)
        .toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Card(
        color: colors.tertiaryContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.notifications_active_rounded,
                    color: colors.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '发现 ${widget.alert.sessionCount} 个新场次',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.onTertiaryContainer,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expanded
                              ? '已展开，可上下滑动查看语言、版本、影厅与购票状态。'
                              : '左右滑动查看场次，也可展开显示完整排片信息。',
                          style: TextStyle(color: colors.onTertiaryContainer),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: expanded ? '收起场次信息' : '展开场次信息',
                    onPressed: () => setState(() => expanded = !expanded),
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭本次新场次提醒',
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: ValueKey<String>(
                  expanded
                      ? 'new-session-vertical-scroll-expanded'
                      : 'new-session-vertical-scroll-collapsed',
                ),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ...widget.alert.notices.map(
                      (notice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Text(
                                  '${notice.subscription.movieName} · ${notice.subscription.cinema.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => widget.onOpenNotice(notice),
                                  icon: const Icon(Icons.movie_filter_outlined),
                                  label: const Text('查看完整排片'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            if (expanded)
                              ...notice.sessions.map(
                                (session) => _ExpandedSessionTile(
                                  key: ValueKey<String>(
                                    'expanded-new-session-${session.id}',
                                  ),
                                  notice: notice,
                                  session: session,
                                ),
                              )
                            else
                              SingleChildScrollView(
                                key: const ValueKey<String>(
                                  'new-session-horizontal-scroll',
                                ),
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: notice.sessions
                                      .map(
                                        (session) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: OutlinedButton.icon(
                                            key: ValueKey<String>(
                                              'new-session-${session.id}',
                                            ),
                                            onPressed: session.canBuy
                                                ? () => _openSession(
                                                      context,
                                                      notice,
                                                      session,
                                                    )
                                                : null,
                                            icon: const Icon(
                                              Icons.event_seat_outlined,
                                            ),
                                            label: Text(
                                              '猫眼 ${formatSessionDate(session.date, short: true)} ${session.time} · ${session.hall}',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => _launchExternalLink(
                            context,
                            TicketLinks.maoyanApp,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('猫眼 App'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _launchExternalLink(
                            context,
                            TicketLinks.taopiaopiaoApp,
                            fallback: TicketLinks.taopiaopiaoWeb,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('淘票票 App'),
                        ),
                        TextButton.icon(
                          onPressed: () => _launchExternalLink(
                            context,
                            TicketLinks.taopiaopiaoWeb,
                          ),
                          icon: const Icon(Icons.language_rounded),
                          label: const Text('淘票票网页'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openSession(
    BuildContext context,
    NewSessionNotice notice,
    Session session,
  ) {
    return _launchExternalLink(
      context,
      TicketLinks.maoyanWebForSession(
        cinema: notice.subscription.cinema,
        movieId: notice.subscription.movieId,
        session: session,
      ),
    );
  }
}

class _ExpandedSessionTile extends StatelessWidget {
  const _ExpandedSessionTile({
    super.key,
    required this.notice,
    required this.session,
  });

  final NewSessionNotice notice;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: session.canBuy
              ? () => _NewSessionAlertBarState._openSession(
                    context,
                    notice,
                    session,
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.event_seat_outlined,
                  color: colors.primary,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${formatSessionDate(session.date, short: true)} · ${session.time}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text('${session.language} · ${session.format}'),
                      const SizedBox(height: 2),
                      Text(session.hall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      session.statusLabel,
                      style: TextStyle(
                        color: session.canBuy ? colors.primary : colors.outline,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (session.canBuy) ...<Widget>[
                      const SizedBox(height: 5),
                      const Icon(Icons.open_in_new_rounded, size: 18),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundAccessCard extends StatelessWidget {
  const _BackgroundAccessCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.backgroundAccessStatus;
    final android = !kIsWeb && Platform.isAndroid;
    final harmony = _isHarmonyOS;
    final macOS = _isMacOS;
    final ready = (android &&
            status.notificationsEnabled != false &&
            status.batteryOptimizationExempt == true &&
            status.backgroundRestricted != true) ||
        (macOS && status.loginItemEnabled == true);
    final title = harmony
        ? '后台提醒由系统管理'
        : android
            ? (ready ? '后台提醒已就绪' : '建议完善后台权限')
            : macOS
                ? (ready ? '登录时启动已开启' : '需要批准登录项')
                : '应用运行时持续检查';
    final detail = harmony
        ? '已默认保留订阅并在回到前台时补查。允许通知和后台活动可提高提醒到达率，但系统不允许此类应用保证永久常驻。'
        : android
            ? '订阅后会自动安排低开销周期任务。${status.notificationsEnabled == false ? '通知尚未允许；' : ''}${status.batteryOptimizationExempt == false ? '当前受电池优化限制。' : '系统仍可按省电策略延后。'}'
            : macOS
                ? '关闭窗口后仍按 ${controller.refreshInterval.label} 检查订阅。启用登录项后，macOS 登录时会自动启动 CinemaRadar。'
                : '前台每 3 分钟检查订阅；关闭应用后不会以本机作为其他设备的后端。';

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ready
                      ? Icons.check_circle_outline_rounded
                      : Icons.battery_saver_rounded,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(detail, style: const TextStyle(fontSize: 12)),
            if (status.notificationsEnabled == false ||
                status.settingsAvailable) ...<Widget>[
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (status.notificationsEnabled == false)
                    TextButton.icon(
                      onPressed: controller.requestNotificationAccess,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('允许通知'),
                    ),
                  if (status.settingsAvailable)
                    TextButton.icon(
                      onPressed: controller.openBackgroundSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('后台设置'),
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

class _SubscriptionDrawer extends StatelessWidget {
  const _SubscriptionDrawer({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width < 460
        ? MediaQuery.sizeOf(context).width * 0.92
        : 420.0;
    return Drawer(
      width: width,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('订阅管理',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 3),
                        Text('${controller.subscriptions.length} 个影片订阅'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭侧边栏',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (!_isHarmonyOS)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DropdownButtonFormField<RefreshIntervalOption>(
                  key: ValueKey<int>(controller.refreshInterval.minutes),
                  initialValue: controller.refreshInterval,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '后台订阅刷新间隔',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: refreshIntervalOptions
                      .map((option) => DropdownMenuItem(
                            value: option,
                            child: Text(option.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.setRefreshInterval(value);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Text(
                _isHarmonyOS
                    ? '鸿蒙版前台固定每 3 分钟刷新；系统后台任务不保证分钟级执行，当前不做后台轮询。'
                    : _isMacOS
                        ? '前台固定每 3 分钟刷新；关闭窗口后按所选间隔继续检查订阅。'
                        : controller.refreshInterval.minutes < 15
                            ? '前台固定每 3 分钟刷新；Android 系统后台最短按 15 分钟调度。'
                            : '前台固定每 3 分钟刷新；Android 后台按所选间隔，系统省电策略可能延后执行。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: _BackgroundAccessCard(controller: controller),
            ),
            const Divider(height: 1),
            if (controller.subscriptions.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text('还没有影片订阅'),
                        const SizedBox(height: 5),
                        const Text(
                          '切换到影院与影片后点击“订阅新场次”，这里会成为以后直达排片的入口。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: controller.subscriptions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final subscription = controller.subscriptions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 9, 8, 9),
                      leading: const CircleAvatar(
                        child: Icon(Icons.movie_filter_outlined),
                      ),
                      title: Text(
                        subscription.movieName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${subscription.cinema.name}\n'
                        '${subscription.cinema.cityName} · ${subscription.cinema.district}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: '删除订阅',
                        onPressed: () => _confirmDelete(context, subscription),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await controller.openSubscription(subscription);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MovieSubscription subscription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除订阅？'),
        content: Text(
          '将停止监控 ${subscription.cinema.name} 的《${subscription.movieName}》。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteSubscription(subscription);
  }
}

class _MovieList extends StatelessWidget {
  const _MovieList({
    required this.movies,
    required this.selected,
    required this.onSelected,
  });

  final List<MovieSchedule> movies;
  final MovieSchedule? selected;
  final ValueChanged<MovieSchedule> onSelected;

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width < 840;
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 11),
            child: Row(
              children: <Widget>[
                Text('正在排片', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${movies.length} 部'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final active = movie.id == selected?.id;
                return InkWell(
                  onTap: () => onSelected(movie),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: horizontal ? 210 : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          active ? colors.primaryContainer : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 54,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: movie.posterUrl.isEmpty
                              ? const Icon(Icons.movie_outlined)
                              : Image.network(
                                  movie.posterUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.movie_outlined),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                movie.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: active
                                      ? colors.primary
                                      : colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '${movie.sessions.length} 场 · ${movie.durationMinutes} 分钟'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulePanel extends StatefulWidget {
  const _SchedulePanel({
    required this.cinema,
    required this.movie,
    required this.subscribed,
    required this.refreshInterval,
    required this.onSubscriptionChanged,
  });

  final Cinema cinema;
  final MovieSchedule movie;
  final bool subscribed;
  final RefreshIntervalOption refreshInterval;
  final VoidCallback onSubscriptionChanged;

  @override
  State<_SchedulePanel> createState() => _SchedulePanelState();
}

class _SchedulePanelState extends State<_SchedulePanel> {
  SessionSortOrder order = SessionSortOrder.ascending;
  SessionHallCategory? category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = widget.movie.visibleSessions(
      category: category,
      order: order,
    );
    final grouped = <String, List<Session>>{};
    for (final session in visible) {
      grouped.putIfAbsent(session.date, () => <Session>[]).add(session);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 330,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.movie.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 5),
                      Text(widget.movie.description.isEmpty
                          ? '${widget.movie.durationMinutes} 分钟'
                          : widget.movie.description),
                    ],
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    widget.subscribed
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    size: 19,
                  ),
                  label: Text(widget.subscribed ? '已订阅新场次' : '订阅新场次'),
                  onPressed: widget.onSubscriptionChanged,
                  backgroundColor: widget.subscribed
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.subscribed
                  ? _isHarmonyOS
                      ? '前台每 3 分钟检查；回到前台后继续比较；同影院多部影片合并请求。'
                      : _isMacOS
                          ? '前台每 3 分钟检查；关闭窗口后每 ${widget.refreshInterval.label}检查；同影院多部影片合并请求。'
                          : '前台每 3 分钟检查；Android 后台每 ${widget.refreshInterval.label}检查；同影院多部影片合并请求。'
                              '${widget.refreshInterval.minutes < 15 ? ' Android 后台最短 15 分钟。' : ''}'
                  : '开启后只比较这家影院与这部影片的场次编号。',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 154,
                  child: DropdownButtonFormField<SessionSortOrder>(
                    initialValue: order,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      border: OutlineInputBorder(),
                    ),
                    items: SessionSortOrder.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => order = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 172,
                  child: DropdownButtonFormField<String>(
                    initialValue: category?.name ?? 'all',
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '影厅筛选',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem(value: 'all', child: Text('全部影厅')),
                      ...SessionHallCategory.values.map(
                        (value) => DropdownMenuItem(
                          value: value.name,
                          child: Text(value.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      category = value == null || value == 'all'
                          ? null
                          : SessionHallCategory.values.byName(value);
                    }),
                  ),
                ),
                Text(
                    '显示 ${visible.length} / ${widget.movie.sessions.length} 场'),
              ],
            ),
            const SizedBox(height: 18),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 44),
                child: Center(child: Text('当前影片没有符合该影厅条件的场次')),
              )
            else
              ...grouped.entries.map((entry) => _DateGroup(
                    cinema: widget.cinema,
                    movie: widget.movie,
                    date: entry.key,
                    sessions: entry.value,
                  )),
          ],
        ),
      ),
    );
  }
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.cinema,
    required this.movie,
    required this.date,
    required this.sessions,
  });

  final Cinema cinema;
  final MovieSchedule movie;
  final String date;
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(_dateLabel(date),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Text('${sessions.length} 场'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sessions
                .map((session) => _SessionCard(
                      cinema: cinema,
                      movie: movie,
                      session: session,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(String source) {
    final date = DateTime.tryParse(source);
    if (date == null) return source;
    const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
    return '${date.month}月${date.day}日 · 周${weekdays[date.weekday - 1]}';
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.cinema,
    required this.movie,
    required this.session,
  });

  final Cinema cinema;
  final MovieSchedule movie;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                session.time,
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                session.statusLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: session.canBuy
                      ? (dark
                          ? const Color(0xFF65D3A0)
                          : const Color(0xFF25845A))
                      : colors.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text('${session.language} · ${session.format}'),
          Text(
            session.hall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  session.canBuy ? () => _showTicketLinks(context) : null,
              child: const Text('购票 / 选座'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTicketLinks(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('选择购票入口',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('${movie.name} · ${session.date} ${session.time}'),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('猫眼 App'),
                  subtitle: const Text('官方唤端页；未安装时显示下载页'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launch(context, TicketLinks.maoyanApp);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('猫眼网页 · 当前场次'),
                  subtitle: const Text('保留影院、影片与场次参数，直接进入选座'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launch(
                      context,
                      TicketLinks.maoyanWeb(
                        cinema: cinema,
                        movie: movie,
                        session: session,
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('淘票票 App'),
                  subtitle: const Text('直接唤起淘票票；未安装时转到网页'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launch(
                      context,
                      TicketLinks.taopiaopiaoApp,
                      fallback: TicketLinks.taopiaopiaoWeb,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('淘票票 · 支付宝 App'),
                  subtitle: const Text('打开支付宝内淘票票；需重新搜索本片与影院'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launch(
                      context,
                      TicketLinks.taopiaopiaoAlipay,
                      fallback: TicketLinks.taopiaopiaoWeb,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('淘票票网页'),
                  subtitle: const Text('猫眼场次编号不能跨平台使用，需重新选场'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launch(context, TicketLinks.taopiaopiaoWeb);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launch(
    BuildContext context,
    Uri uri, {
    Uri? fallback,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && fallback != null) {
        launched = await launchUrl(
          fallback,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (fallback != null) {
        try {
          launched = await launchUrl(
            fallback,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          launched = false;
        }
      }
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开购票入口，请检查浏览器或对应 App')),
      );
    }
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 19, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
