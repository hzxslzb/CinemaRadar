# 03 · 目录结构与源码导读

## 1. 仓库目录

```text
CinemaRadar/
├── Doc/                         本技术文档中心
├── docs/                        用户简介、历史截图、快速构建和 Release 文档
├── lib/
│   ├── main.dart                启动和插件初始化
│   ├── app.dart                 主题、主页面、提醒、侧栏、场次卡片和购票弹层
│   ├── app_controller.dart      主页面业务状态和生命周期调度
│   ├── data/
│   │   ├── maoyan_provider.dart HTTP 接口和影院目录缓存
│   │   └── subscription_store.dart 本地键值存储
│   ├── domain/models.dart       地域、影院、影片、场次、订阅和提醒模型
│   ├── services/                检测、通知、后台任务、设置桥接、购票链接
│   ├── utils/                   日期与周几格式化
│   └── widgets/                 城市/行政区/影院搜索弹窗
├── android/                     Gradle 工程、Manifest、Kotlin 桥接、图标
├── macos/                       Xcode/CocoaPods 工程、Swift 桥接、图标
├── ohos/                        保留的 HarmonyOS 工程与 ArkTS 插件
├── test/schedule_test.dart       固定样本与 11 项自动化测试
├── tool/                        构建、签名提取/合并和在线回归脚本
├── assets/branding/              共用应用图标
├── .github/                     CI、手动构建与固定 Flutter SDK 设置
├── pubspec.yaml                 应用版本与依赖声明
├── pubspec.lock                 固定依赖解析结果
├── CHANGELOG.md                 用户可见版本变化
└── CONTRIBUTING.md              贡献与发布约定
```

`build/`、`.dart_tool/`、Android Gradle 缓存、Pods、原生生成物、私有签名和机器路径未纳入 Git。GitHub Release 附件存放安装包，仓库不跟踪编译产物。

## 2. Dart 关键文件

| 文件 | 主要符号 | 维护时优先关注 |
| --- | --- | --- |
| [main.dart](../lib/main.dart) | `main` | 插件初始化顺序、启动异常 |
| [app_controller.dart](../lib/app_controller.dart) | `AppController` | 刷新、订阅、持久化衔接、生命周期 |
| [models.dart](../lib/domain/models.dart) | `Session`、`MovieSubscription`、`NewSessionAlert` | ID、字段兼容、排序和序列化 |
| [maoyan_provider.dart](../lib/data/maoyan_provider.dart) | 两个 Provider、`fuzzyFilterCinemas` | 接口字段、分页、缓存、超时 |
| [subscription_store.dart](../lib/data/subscription_store.dart) | `SubscriptionStore` | 存储键、损坏数据回退、清理语义 |
| [subscription_monitor.dart](../lib/services/subscription_monitor.dart) | `checkAll`、`detectNewSessions` | 请求合并、基线更新与失败传播 |
| [background_monitor.dart](../lib/services/background_monitor.dart) | `callbackDispatcher`、`BackgroundMonitor` | Worker 入口和唯一周期任务 |
| [notification_service.dart](../lib/services/notification_service.dart) | `NotificationService` | 权限、预览文案、通知 ID |
| [background_access_service.dart](../lib/services/background_access_service.dart) | `BackgroundAccessService` | MethodChannel、超时和平台能力差异 |
| [ticket_links.dart](../lib/services/ticket_links.dart) | `TicketLinks` | 外部链接参数、通用入口与具体场次边界 |
| [session_date_format.dart](../lib/utils/session_date_format.dart) | `formatSessionDate` | 日期解析和中文周几 |
| [cinema_search_dialog.dart](../lib/widgets/cinema_search_dialog.dart) | `CinemaSearchDialog` | 搜索局部状态与请求结果归属 |

## 3. `app.dart` 组件地图

`app.dart` 是集中式展示文件，当前没有按页面拆成多个子目录。其 `_` 前缀类为该 Dart library 的私有组件。

| 组件 | 作用 |
| --- | --- |
| `CinemaRadarApp` | 构建 MaterialApp、主题与主页面，创建/接收控制器 |
| `CinemaHomePage` | 固定顶部提醒、头部、影院信息、刷新、主内容和侧边栏 |
| `_NewSessionAlertBar` / State | 提醒批次、横向浏览、展开为纵向明细 |
| `_ExpandedSessionTile` | 展开后的单场次详情与网页跳转 |
| `_BackgroundAccessCard` | 后台状态、允许通知和系统设置入口 |
| `_SubscriptionDrawer` | 订阅列表、自定义后台间隔、跳转与确认删除 |
| `_MovieList` | 按屏幕宽度横排或纵排影片列表，加载海报 |
| `_SchedulePanel` / State | 影片信息、订阅开关、排序筛选和日期分组 |
| `_DateGroup` | 日期标题、周几、场次数和 Wrap 布局 |
| `_SessionCard` | 时间、状态、语言、版本、影厅与购票底部弹层 |
| `_Label` | 图标与文字的轻量展示单元 |

页面中的 `_launchExternalLink` 与 `_SessionCard._launch` 都实现外部 URL 打开/回退/错误提示，存在重复逻辑；目前不能假定它们已统一为全局导航服务。

## 4. 原生入口

### Android

- [Manifest](../android/app/src/main/AndroidManifest.xml)：网络、通知、震动权限，主 Activity，淘票票/支付宝 scheme 查询。
- [MainActivity](../android/app/src/main/kotlin/com/cinemaradar/app/MainActivity.kt)：注册后台设置通道，查询省电/后台限制，打开设置。
- [app/build.gradle](../android/app/build.gradle)：SDK、Java/Kotlin、包 ID、版本和品牌化 APK 复制任务。
- [settings.gradle](../android/settings.gradle)：Flutter Gradle loader、AGP 和 Kotlin 插件版本。
- [Gradle Wrapper](../android/gradle/wrapper/gradle-wrapper.properties)：Gradle 版本与下载源。

### macOS

- [AppDelegate](../macos/Runner/AppDelegate.swift)：关闭最后窗口后不自动退出。
- [MainFlutterWindow](../macos/Runner/MainFlutterWindow.swift)：创建 Flutter 引擎、注册插件与登录项通道。
- [AppInfo.xcconfig](../macos/Runner/Configs/AppInfo.xcconfig)：产品名 `CinemaRadar`、bundle ID。
- [Release.entitlements](../macos/Runner/Release.entitlements)：沙盒与出站网络权限。
- [Podfile](../macos/Podfile) / [Podfile.lock](../macos/Podfile.lock)：CocoaPods 配置和锁定结果。

### HarmonyOS

- [EntryAbility](../ohos/entry/src/main/ets/entryability/EntryAbility.ets)：注册 Flutter 插件和自定义后台设置插件。
- [BackgroundAccessPlugin](../ohos/entry/src/main/ets/plugins/BackgroundAccessPlugin.ets)：通知状态与设置跳转。
- [build-profile.json5](../ohos/build-profile.json5)：不带凭据的公开工程模板。
- [AppScope/app.json5](../ohos/AppScope/app.json5)：保留的原生应用版本信息，不代表本次 APK/macOS 版本。

## 5. 推荐源码阅读顺序

1. 从 `models.dart` 理解影院键、影片 ID、场次 ID 与通知批次。
2. 阅读 `maoyan_provider.dart`，理解一个 HTTP 响应如何形成 `CinemaSnapshot`。
3. 阅读 `subscription_store.dart` 与 `subscription_monitor.dart`，理解旧基线与新响应的差量。
4. 阅读 `AppController.initialize`、`refresh`、`_scheduledRefresh`、`toggleSubscription`。
5. 阅读 UI 的订阅按钮、侧边栏和顶部消息组件，核对调用关系。
6. 阅读 `background_monitor.dart` 和三端原生桥接，理解平台边界。
7. 最后阅读测试和工作流，知道哪些假设有自动化覆盖。

## 6. 按问题找源码

| 现象/需求 | 优先文件 |
| --- | --- |
| 城市或影院搜不到 | `maoyan_provider.dart`、`cinema_search_dialog.dart` |
| 排片解析报错 | `models.dart`、`MaoyanScheduleProvider.fetchCinema` |
| 为什么重复提醒或不提醒 | `subscription_monitor.dart`、`subscription_store.dart` |
| 想调整提醒展开高度 | `_NewSessionAlertBarState.build` |
| 提醒周几不对 | `session_date_format.dart`、原始 `Session.date` |
| 通知被拒绝后入口异常 | `notification_service.dart`、`background_access_service.dart` |
| 关闭 macOS 窗口即停止/退出 | `AppDelegate.swift`、控制器生命周期 |
| Android 后台间隔不准 | `background_monitor.dart`、设备系统策略 |
| 构建后文件名不对 | Gradle `copyCinemaRadarReleaseApk`、`build_macos_release.sh` |
| CI 报缺少鸿蒙 SDK | `.github/actions/setup-flutter/action.yml` |

## 7. 搜索命令

在项目根目录执行：

```bash
rg -n 'class |abstract interface|enum ' lib
rg -n 'checkAll|seenSessionIds|prefetched' lib
rg -n 'new_session_alert_v1|saveNewSessionAlert|clearNewSessionAlert' lib
rg -n 'getStatus|openBackgroundSettings|enablePersistentBackground' lib android macos ohos
```

这些命令仅查找源码，不需要连接票务接口或真机。
