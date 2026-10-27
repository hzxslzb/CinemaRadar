# CinemaRadar 数据源研究与实现说明

本页保留早期调研和实现概览。更完整且按当前源码核对的资料见 [Doc/ 技术文档中心](../Doc/README.md)，尤其是 [接口与搜索](../Doc/05-Data-Providers-and-Cinema-Search.md)、[订阅调度](../Doc/07-Subscriptions-and-Refresh.md) 和 [可靠性边界](../Doc/11-Performance-and-Reliability.md)。历史接口数量和实机记录不代表本次重新联网验证结果。

一个端侧自治的影院排片订阅原型。Android、macOS 与 HarmonyOS 各自请求数据、保存订阅、比较场次和发送本地通知；没有自建后端，也不会依赖另一台设备在线。

面向普通用户的简短介绍与真机界面图见 [CinemaRadar 用户简介](./CinemaRadar-用户简介.md)，下载和项目概览见 [README](../README.md)。

## 已实现

- 用户选中具体影院后才请求该影院排片，不扫描全城。
- 应用在前台固定每 3 分钟刷新；用户可另选 5/10/15/20/25/30 分钟以及 1/2/3/12/24 小时的后台订阅间隔。
- 订阅精确到“影院 + 影片”，以猫眼场次 `seqNo` 做集合差量，只提醒新增场次。
- Android 在用户订阅后默认使用 WorkManager 安排后台检查；仅在联网且电量不低时执行。系统周期任务下限为 15 分钟，因此 5/10 分钟选项在 Android 后台按 15 分钟调度。
- 订阅时会请求通知权限；订阅侧边栏持续显示后台提醒状态。Android 可直达电池优化/应用详情设置，macOS 可直达“登录项与扩展”，鸿蒙可直达 CinemaRadar 的系统应用详情页；新增订阅时如仍需完善设置，应用会弹出引导。
- 同一影院订阅多部影片时合并为一次网络请求，复杂度取决于订阅影院数，而不是订阅影片数。
- macOS 关闭最后一个窗口后继续运行，并按用户选择的后台间隔检查订阅；首次有订阅时尝试将 CinemaRadar 注册为登录项，系统需要确认时提供设置直达。数据和订阅仍只保存在本机。
- HarmonyOS 使用独立 HAP、端侧存储与本地通知。系统 Work Scheduler 对活跃普通应用的执行间隔通常从 2 小时起，也不允许排片轮询冒充长时可感知任务以求常驻。因此鸿蒙版不伪装后台准实时：前台每 3 分钟检查，回到前台后继续比较已保存订阅，并提供通知/应用联网设置直达。
- 城市列表从猫眼移动站动态加载；当前在线回归取得 1173 个城市/县级地域，不再维护少量硬编码城市。
- 切换影院采用“城市搜索 → 行政区 → 本地模糊搜索影院”，用户无需知道猫眼影院 ID。行政区影院列表只请求一次并做内存缓存，输入关键词不会继续发请求；影院切换历史不持久化。
- 右侧订阅栏只保留影片订阅：可删除，也可点击订阅直接回到对应影院与影片排片。
- 检测到新增场次时，系统通知与应用顶部提醒都会显示日期和周几。顶部提醒收起时可横向快速浏览，展开后改为纵向滚动，并补充语言、版本、影厅和购票状态；逐场提供猫眼直达选座及猫眼 App、淘票票 App/网页入口。关闭只清除当前批次，下一批新增场次仍会再次出现。
- 浅色/深色主题可由日月按钮切换并在本机保存。
- 排片支持时间升序/降序，以及普通厅、IMAX、Dolby、其他特效厅筛选。
- 指定场次可跳转猫眼网页选座；另提供猫眼官方唤端页、淘票票 App、支付宝内淘票票和淘票票网页入口。
- 默认回归目标：上海 MOViE MOViE 影城（前滩太古里店，猫眼影院 ID `37534`）的《奥德赛》。

## 数据源结论

当前原型使用猫眼 M 站排片页自己的定向影院 JSON 响应：

```text
GET https://m.maoyan.com/mtrade/cinema/cinema/shows.json
    ?cinemaId={cinemaId}&ci={cityId}&channelId=4
```

它能返回影院、影片、日期和具体场次（`seqNo`、时间、语言、制式、影厅、售卖状态）。这是公开网页使用的接口，但不是猫眼对第三方公开承诺的开发者 API；路径、字段、风控和可用性都可能变化。正式商用前必须取得数据授权，并准备签约数据源适配器。代码把数据源隔离在 `ScheduleProvider` 后面，替换时不需要重写订阅逻辑或 UI。

可选的合规路线是淘票票开放平台或影院/票务系统直连。淘票票文档列出了影院、排期、座位图、锁座、解锁和出票接口，但公共参数仍要求平台分配的 `app_key`、签名密钥，锁座还要求渠道码、真实手机号和幂等用户标识；这些密钥不能放进可反编译的客户端，生产实现需要签约服务端。

国家电影行业标准 DY/T 10—2025 也定义了影院排片查询、场次座位状态、锁座、解锁、确认交易与退票接口；标准描述的是网络代售系统与影院票务系统/上游系统之间的 B2B 接口，并不是面向普通终端的公共 API。

## 购票边界

猫眼网页入口打开具体 `seqNo` 的选座页面。淘票票不接受猫眼场次 ID，所以它的 App/网页入口会明确要求重新选择影片、影院和场次，不会伪造跨平台场次映射。直接在本应用内购买指定座位技术上需要完整的事务链：排期映射 → 实时座位图 → 防隔座校验 → 锁座 → 支付 → 出票 → 超时解锁/退款/重试。未获授权时模拟猫眼 App 的座位或订单请求会涉及账号、风控、支付和真实库存状态，因此本项目没有这样做。

若取得淘票票/影院授权，可新增 `TicketingProvider`，在独立的安全服务端实现：

1. 查询座位图并显示可售状态；
2. 用户选择座位后调用锁座，持久化 `applyKey` 与自动解锁时间；
3. 支付完成后以幂等订单号出票；
4. 对 `DOING` 状态按平台要求重试，并实现解锁、退款和对账。

## 运行与验证

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/live_regression.dart
```

Android：安装 Android SDK 36、JDK 17，然后运行：

```bash
flutter run -d <android-device-id>
# 或
FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com flutter build apk --release
```

macOS：安装完整 Xcode 与 CocoaPods，然后运行：

```bash
flutter run -d macos
# 或
./tool/build_macos_release.sh
```

HarmonyOS：不在本次 `1.0.3+4` 发布范围；如需自行构建，安装 DevEco Studio、HarmonyOS SDK 与 OpenHarmony-SIG Flutter 后运行：

```bash
./tool/build_ohos_release.sh
hdc -t <device-serial> shell aa start -a EntryAbility -b com.cinemaradar.app
```

DevEco 首次为 `com.cinemaradar.app` 自动生成签名后，运行 `node tool/extract_ohos_signing.mjs ohos/build-profile.json5 ohos/build-profile.local.json5`。私有签名配置会保存在已忽略、权限为 `0600` 的本机文件中；构建脚本只在打包期间临时合并，并在退出时还原无凭据的项目模板。

当前开发机已配置 Android SDK 36、Temurin JDK 17、Gradle 8.9、Xcode 26.6、CocoaPods 1.17.0 与 Flutter `3.41.10-ohos-1.0.0`。已验证 `flutter analyze`、11 项测试以及 Android/macOS Release 构建。本次 `1.0.3+4` 仅发布 Android 与 macOS；此前鸿蒙回归结论仍保留在项目文档中，但不生成本版本 HAP。

本机构建产物：

- `build/app/outputs/flutter-apk/CinemaRadar-1.0.3+4.apk`（SHA-256 `7d41b078c1368c3bfd851db1cd754504e4c84e04ca2c7cf9e8aac184e9b44096`，包名 `com.cinemaradar.app`）。当前使用 Android Debug 证书签名，适合本地安装与回归；商店/正式分发前需配置项目自己的 release keystore。
- `build/macos/CinemaRadar-1.0.3+4.zip`（SHA-256 `e6cc9d80e4cd010636e54b96d95ad8c9911c6179158d22dc8d2c8b3e176e4ff9`，bundle id `com.cinemaradar.app`），包含 arm64 与 x86_64 双架构应用。当前为 ad-hoc 签名，适合本机运行；对外分发前需 Apple Developer ID 签名与公证。
- `build/CinemaRadar-1.0.3+4-android-macos.zip`（SHA-256 `fb8f5a8faead360b24f356942e15b6fbc4e9129028f00ff332a09728c1bb11ee`），仅包含上述 APK 与 macOS ZIP。

发布产物从 `pubspec.yaml` 读取完整版本，名称固定包含 `CinemaRadar-{version}+{build}`；当前版本为 `1.0.3+4`。

## 性能模型

- 定时刷新：当前影院快照会复用于同影院订阅比较，不重复请求；其他订阅按影院各请求 1 次。
- 影院目录：城市和行政区按需缓存；选区后一次取回该区影院，关键词过滤为纯本地计算。
- Android 后台：每个周期每个“有订阅的影院”1 个请求；10 部电影都在同一家影院时仍为 1 个请求。
- macOS 后台：关闭窗口不结束进程；仅在有订阅时按用户选择的间隔运行，同影院订阅仍合并为一次请求。
- 无订阅：取消 Android 周期任务。
- 差量：只保存字符串场次 ID 集合，不缓存座位图或轮询票价。
- 通知批次：仅保存当前未关闭的一批新增场次；关闭后删除该批详情但不修改订阅，下一次差量检测会写入新批次并重新显示顶部栏。
- 后台下限：Android WorkManager 周期任务最短为 15 分钟，系统可能因 Doze、电量和厂商策略延后执行，因此通知是“尽快”而非硬实时。
- HarmonyOS：不注册分钟级后台轮询；前台计时器和同影院请求合并逻辑保持不变，避免以高开销保活换取不可保证的刷新频率。

## 主要代码

- `lib/data/maoyan_provider.dart`：猫眼城市、行政区、影院目录与定向排片响应适配。
- `lib/services/subscription_monitor.dart`：按影院聚合请求与新增场次检测。
- `lib/services/background_monitor.dart`：Android 低开销后台调度。
- `lib/services/background_access_service.dart`：通知、Android 电池优化、macOS 登录项状态与跨平台系统设置入口。
- `lib/domain/models.dart`：影院、影片、场次与订阅模型。
- `lib/widgets/cinema_search_dialog.dart`：按城市和行政区查询后的本地影院模糊搜索。
- `lib/services/ticket_links.dart`：猫眼与淘票票 App/网页入口。
- `lib/app.dart`：响应式界面、订阅侧边栏、主题切换、刷新设置、排片排序与影厅筛选。

## 调研来源

- [猫眼：MOViE MOViE 前滩店影院页](https://www.maoyan.com/cinema/37534?poi=1153113439)
- [猫眼移动站：动态城市目录](https://m.maoyan.com/dianying/cities.json)
- [淘票票当前 H5 一方脚本：原生 `tbmovie` 路由](https://g.alicdn.com/alipay-movie-client/movie-h5-home/2024.10.21/6757.41ceabbd.js)
- [淘宝开放平台：电影票 API 目录](https://developer.alibaba.com/doc2/apiDetail.htm?apiId=47126)
- [淘票票：影院排期查询](https://developer.alibaba.com/docs/api.htm?apiId=29597)
- [淘票票：座位图](https://developer.alibaba.com/docs/api.htm?apiId=30087)
- [淘票票：锁座](https://developer.alibaba.com/docs/api.htm?apiId=30171)
- [淘票票：出票](https://developer.alibaba.com/docs/api.htm?apiId=30441)
- [国家电影局：DY/T 10—2025 行业标准](https://www.chinafilm.gov.cn/xxgk/kjybz/202508/P020250126539559785620.pdf)
- [Android Developers：WorkManager 周期任务最短 15 分钟](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work)
- [Android Developers：Doze 与电池优化设置](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Apple Developer：SMAppService 登录项管理](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [OpenHarmony-SIG Flutter：HarmonyOS/OpenHarmony 平台支持](https://gitee.com/openharmony-sig/flutter_flutter/blob/aa4c189429e6fe602156f9b82e43cf5df854e32f/README.en.md)
- [OpenHarmony：后台任务概览](https://gitee.com/openharmony/docs/blob/5550d107410fd035430936386bce9915b49ec7f8/en/application-dev/task-management/background-task-overview.md)
- [OpenHarmony：Work Scheduler 开发指南](https://gitee.com/openharmony/docs/blob/67df397d4cc7a7952e21b21904dfd906176e10fd/en/application-dev/task-management/work-scheduler-dev-guide.md)
