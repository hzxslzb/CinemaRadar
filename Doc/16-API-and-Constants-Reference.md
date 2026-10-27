# 16 · 关键 API 与常量速查

本章是源码导航索引，不是承诺长期稳定的第三方 SDK API。以下签名以当前 Dart 代码为准，私有 `_` 方法只供内部实现理解。

## 1. AppController

来源：[app_controller.dart](../lib/app_controller.dart)。

| 方法 | 返回 | 主要作用/副作用 |
| --- | --- | --- |
| `initialize()` | `Future<void>` | 恢复状态、初次查询/检测、权限状态、计时器和后台任务 |
| `switchCinema(Cinema)` | `Future<void>` | 切换影院并刷新；同 key 时只更新对象 |
| `openSubscription(MovieSubscription)` | `Future<void>` | 导航到影院影片，必要时查询 |
| `selectMovie(MovieSchedule)` | void | 更改内存选片并通知监听 |
| `refresh({int? preferredMovieId})` | `Future<void>` | 当前影院查询，捕获错误，设置选片 |
| `refreshAndCheckSubscriptions()` | `Future<void>` | 统一手动/周期刷新入口 |
| `isSubscribed(MovieSchedule)` | bool | 查询当前影院下是否订阅该影片 |
| `toggleSubscription(MovieSchedule)` | `Future<bool>` | 添加/取消；true 表示新增 |
| `deleteSubscription(MovieSubscription)` | `Future<void>` | 删除并同步后台任务 |
| `dismissNewSessionAlert()` | `Future<void>` | 清内存并按当前 ID 清持久化批次 |
| `reloadNewSessionAlert()` | `Future<void>` | 重读批次，ID 变化才更新页面 |
| `openNewSessionNotice(NewSessionNotice)` | `Future<void>` | 委托订阅上下文导航 |
| `toggleTheme()` | `Future<void>` | 手动主题切换并保存 |
| `setRefreshInterval(RefreshIntervalOption)` | `Future<void>` | 保存间隔、同步系统任务和 Timer |
| `refreshBackgroundAccessStatus({bool notify = true})` | `Future<void>` | 更新后台状态，可跳过 notify |
| `requestNotificationAccess()` | `Future<void>` | 请求权限并重读状态 |
| `openBackgroundSettings()` | `Future<bool>` | 打开平台后台设置 |
| `openAppSettings()` | `Future<bool>` | 打开平台实现的应用设置入口 |
| `didChangeAppLifecycleState(AppLifecycleState)` | void | 重配计时器，恢复时读取提醒/权限 |
| `dispose()` | void | 释放计时器和观察者 |

重要私有方法：`_scheduledRefresh`（防重入）、`_checkSubscriptions`（prefetched 复用）、`_configureTimerForLifecycle`（平台周期选择）、`_regressionMovie`（默认影片偏好）。

## 2. 数据 Provider 与纯函数

来源：[maoyan_provider.dart](../lib/data/maoyan_provider.dart)。

| API | 说明 |
| --- | --- |
| `ScheduleProvider.fetchCinema(Cinema)` | 返回指定影院 `CinemaSnapshot` |
| `CinemaDirectoryProvider.fetchCities()` | 返回 `List<CityOption>` |
| `CinemaDirectoryProvider.fetchDistricts(CityOption)` | 返回 `List<DistrictOption>` |
| `CinemaDirectoryProvider.fetchCinemas({city, district})` | 返回地域内 `List<Cinema>` |
| `MaoyanScheduleProvider({http.Client? client})` | 默认排片实现，支持注入 Client |
| `MaoyanCinemaDirectoryProvider({http.Client? client})` | 带 Future 缓存的目录实现 |
| `fuzzyFilterCinemas(List<Cinema>, String)` | 纯本地多关键词匹配和排序 |
| `ScheduleProviderException(String message)` | 数据源错误文案封装 |

## 3. 检测与后台任务

| API | 说明 |
| --- | --- |
| `SubscriptionMonitor({provider, store, notifications})` | 构造检测服务 |
| `checkAll({Map<String, CinemaSnapshot> prefetched = const {}})` | 返回 `Future<MonitorResult>`；检查、通知并保存 |
| `MonitorResult.checked` | 处理结果中的订阅条数，不是影院数 |
| `MonitorResult.notices` | 本轮新增条目 |
| `MonitorResult.alert` | 本轮有新增时生成的批次，否则 null |
| `MonitorResult.newSessions` | 各 notice 新增场次总数 |
| `detectNewSessions(List<Session>, Set<String>)` | 只保留旧集合外的 ID |
| `BackgroundMonitor.initialize()` | Android 初始化 WorkManager，其他平台直接返回 |
| `BackgroundMonitor.syncSchedule({RefreshIntervalOption? interval})` | 根据存储注册/取消唯一任务 |
| `callbackDispatcher()` | 后台入口，必须保留 entry-point 注解 |

来源：[检测器](../lib/services/subscription_monitor.dart)、[后台任务](../lib/services/background_monitor.dart)。

## 4. SubscriptionStore

来源：[subscription_store.dart](../lib/data/subscription_store.dart)。

| 方法 | 说明 |
| --- | --- |
| `load()` / `save(List<MovieSubscription>)` | 全列表订阅读写 |
| `loadDarkTheme()` / `saveDarkTheme(bool)` | 主题 |
| `loadRefreshMinutes()` / `saveRefreshMinutes(int)` | 后台分钟数 |
| `removeLegacyCinemaCache()` | 删除旧影院留存键 |
| `loadNewSessionAlert()` | 加载批次，损坏时清理 |
| `saveNewSessionAlert(NewSessionAlert)` | 覆盖最近批次 |
| `clearNewSessionAlert({String? expectedId})` | 按预期 ID 尝试清理 |

## 5. 通知与后台设置服务

| API | 返回/行为 |
| --- | --- |
| `NotificationService.instance` | 通知单例 |
| `initialize({bool requestPermission = false})` | 初始化插件；已初始化则直接返回 |
| `requestPermissions()` | `Future<bool?>`，平台权限申请 |
| `areNotificationsEnabled()` | `Future<bool?>`，macOS 当前为 null |
| `showNewSessions(subscription, sessions)` | 显示一个订阅对应的系统通知 |
| `buildNewSessionNotificationPreview(List<Session>)` | 最多三场日期周几摘要 |
| `BackgroundAccessService.instance` | 原生设置桥接单例 |
| `status()` | `Future<BackgroundAccessStatus>` |
| `openBackgroundSettings()` / `openAppSettings()` | `Future<bool>` |
| `enablePersistentBackground()` | 仅 macOS 尝试注册登录项 |
| `BackgroundAccessStatus.needsAttention` | 按平台计算是否提示 |

来源：[通知](../lib/services/notification_service.dart)、[后台设置](../lib/services/background_access_service.dart)。

## 6. 模型派生属性

| 属性/方法 | 语义 |
| --- | --- |
| `CityOption.searchText` | 名称、拼音、ID 组合的小写文本 |
| `Cinema.key` | `城市ID:影院ID` |
| `MovieSubscription.key` | `城市ID:影院ID:影片ID` |
| `Session.canBuy` | 状态 0 或 5 |
| `Session.startsAt` | 日期和时间尝试解析 |
| `Session.hallCategory` | 按优先级关键词判厅型 |
| `Session.statusLabel` | 售卖状态中文映射 |
| `MovieSchedule.sessionsByDate` | 原始顺序分组 |
| `MovieSchedule.visibleSessions({category, order})` | 过滤后排序的新列表 |
| `NewSessionAlert.sessionCount` | 批次内新增总数 |
| `RefreshIntervalOption.duration` | 原样分钟转 Duration |
| `RefreshIntervalOption.androidBackgroundDuration` | 小于 15 提升至 15 |

`fromMaoyan`、`fromJson`、`toJson` 以及订阅/批次 encode/decode 的具体字段见 [模型与存储](04-Domain-Models-and-Storage.md)。

## 7. 常量表

| 名称/含义 | 当前值 |
| --- | --- |
| 应用完整版本 | `1.0.3+4` |
| 产品名称 | `CinemaRadar` |
| Android applicationId / macOS bundle ID | `com.cinemaradar.app` |
| 前台周期 | 3 分钟 |
| 默认后台周期 | 15 分钟 |
| 后台选项分钟 | 5、10、15、20、25、30、60、120、180、720、1440 |
| Android 周期下限 | 15 分钟 |
| HTTP 等待超时 | 单次 12 秒 |
| 自定义通道超时 | 单次 1 秒 |
| 影院分页 limit | 100 |
| 影院分页 offset 保护 | `< 2000` |
| 城市搜索展示上限 | 100 条 |
| 系统通知摘要 | 最多 3 个场次 |
| 通知 channel ID | `schedule_changes` |
| 唯一后台任务名 | `cinema_schedule_monitor_v1` |
| 后台任务类型名 | `cinema_schedule_subscription_check` |
| MethodChannel | `com.cinemaradar.app/background_access` |
| 默认回归影院 | 城市 10，影院 37534 |
| 单场次卡片宽度 | 210 |
| 页面最大宽度 | 1180 |
| 主布局断点 | 840 |

## 8. 存储键与通道方法

```text
movie_subscriptions_v1
dark_theme_v1
refresh_minutes_v1
new_session_alert_v1
custom_cinemas_v1          # 历史键，初始化删除
```

```text
getStatus
openBackgroundSettings
openAppSettings
enablePersistentBackground
```

## 9. 维护检查

修改上述值时，除代码外还应检查：第 01 章功能承诺、第 07 章刷新表、第 08 章通知、第 12 章构建与根 README。不要在多篇说明里保留互相矛盾的默认时间或发布平台。
