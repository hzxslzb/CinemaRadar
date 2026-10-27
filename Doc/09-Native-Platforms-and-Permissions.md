# 09 · 跨平台原生能力与权限

实现入口：[Dart 桥接](../lib/services/background_access_service.dart)、[Android](../android/app/src/main/kotlin/com/cinemaradar/app/MainActivity.kt)、[macOS](../macos/Runner/MainFlutterWindow.swift)、[HarmonyOS](../ohos/entry/src/main/ets/plugins/BackgroundAccessPlugin.ets)。

## 1. 能力查询而非永久常驻授权

本项目没有一项能跨系统保证“永久常驻”的权限。实现分别查询通知/电池/登录项状态，并提供系统设置入口。Android 使用系统后台任务；macOS 依赖应用进程；鸿蒙源码明确不声称存在适用于排片轮询的常驻模式。

用户允许通知、允许后台活动或设置登录项，都不等于系统保证每次网络查询准时完成。

## 2. MethodChannel 协议

通道名：

```text
com.cinemaradar.app/background_access
```

| 方法 | Dart 期待结果 | Android | macOS | HarmonyOS |
| --- | --- | --- | --- | --- |
| `getStatus` | Map | 电池、后台限制等状态 | 登录项和设置能力 | 通知和设置能力 |
| `openBackgroundSettings` | bool | 电池优化设置 | 登录项设置 | 应用详情 |
| `openAppSettings` | bool | 本应用详情 | 当前也指向登录项设置 | 应用详情 |
| `enablePersistentBackground` | bool | Dart 不调用 | 尝试注册登录项 | Dart 不调用 |

协议使用小型 Map 与 bool，不返回 OS 权限对象。未知方法由原生端返回 notImplemented。

## 3. 状态对象

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `notificationsEnabled` | bool? | 可查询平台的通知开关；未知时 null |
| `batteryOptimizationExempt` | bool? | Android 是否忽略电池优化 |
| `backgroundRestricted` | bool? | Android 是否被限制后台运行 |
| `loginItemEnabled` | bool? | macOS 登录项是否 enabled |
| `settingsAvailable` | bool | 是否提供系统设置跳转 |
| `scheduledBackgroundSupported` | bool | 原生报告的调度能力提示 |

`scheduledBackgroundSupported` 当前没有驱动调度器选择，也不能从 true 推断某个系统任务已经成功注册。

状态来自两处：Dart 先调用通知插件查询 `notificationsEnabled`；再读取原生 Map 的电池、登录项等字段。原生 Map 即使包含 `notificationsEnabled`，目前也没有作为备用值合并。

## 4. Dart 端保护

- Web 或不支持平台跳过原生通道；当前工程本身并未因此完成 Web 支持。
- `FLUTTER_TEST=true` 时跳过自定义通道，以避免无原生处理器的 Widget 测试卡住。
- 自定义通道方法设置 1 秒超时。
- 捕获 `PlatformException`、`MissingPluginException`、`TimeoutException`，返回保守的空状态/false。
- 打开后台设置遇到 PlatformException 时尝试 `openAppSettings`；超时或缺插件则返回 false。

该 1 秒约束只包围自定义通道调用，不是所有通知权限弹窗的超时。用户授权流程不能简单按 1 秒结束。

## 5. Android 状态和设置

### 5.1 状态来源

- `NotificationManagerCompat.areNotificationsEnabled()`。
- `PowerManager.isIgnoringBatteryOptimizations(packageName)`。
- Android P 起使用 `ActivityManager.isBackgroundRestricted`，旧系统返回 false。

### 5.2 设置入口

`openBackgroundSettings` 打开 `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`。这是系统电池优化列表入口，不是代码自动替用户授予豁免。

若该入口不可用，回退到 `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`，URI 为 `package:com.cinemaradar.app`。原生 try/catch 避免设置 Activity 不存在时崩溃。

当前没有逐个适配小米、OPPO、vivo 等厂商自启动管理器的私有组件，也没有以无关播放/定位服务进行强行保活。

### 5.3 Manifest

项目自身显式声明 INTERNET、POST_NOTIFICATIONS、VIBRATE。`queries` 中包含 `tbmovie`、`alipays` 和系统文本处理查询。依赖插件还可能通过 Manifest 合并加入其需要的组件，最终权限应以构建后的合并 Manifest/APK 为准。

## 6. macOS 进程与登录项

### 6.1 关闭窗口继续运行

`AppDelegate.applicationShouldTerminateAfterLastWindowClosed` 返回 false。应用可在无窗口时继续保持进程，由 Dart 计时器检查。

当前没有单独的 LaunchDaemon、XPC 后台服务、菜单栏常驻组件或自动防休眠机制。关闭窗口、主动退出和系统休眠是不同状态，不能混为一谈。

### 6.2 登录项注册

在 macOS 13 及以上使用 `SMAppService.mainApp`：

1. `getStatus` 仅当 status 为 `.enabled` 时报告 true。
2. `enablePersistentBackground` 仅在 `.notRegistered` 时调用 `register()`。
3. 注册失败捕获异常并返回 false。
4. 需要审批时由用户在系统“登录项与扩展”处理。

设置跳转调用 `SMAppService.openSystemSettingsLoginItems()`。

macOS 13 以下仍可运行应用，但状态返回登录项 false、设置不可用；Dart `needsAttention` 仍可能据此提示需要处理，属于旧系统体验上的待改进点。

### 6.3 通知与沙盒

通知权限由 Flutter 通知插件申请，当前没有查询 macOS 通知授权状态的实现。登录项已开启不代表通知已开启。

Release entitlements 包含 app sandbox 和出站网络 client；没有让应用突破系统设置的权限。

## 7. HarmonyOS 保留源码

ArkTS 插件实现 `FlutterPlugin`、`AbilityAware` 和 `MethodCallHandler`，引擎附着时注册通道，Ability 附着时保存 UIAbilityContext，分离时清空引用。

状态会调用 `notificationManager.isNotificationEnabled`；`scheduledBackgroundSupported` 返回 false。

设置 Want 当前为：

```text
bundleName: com.huawei.hmos.settings
abilityName: com.huawei.hmos.settings.MainAbility
uri: application_info_entry
parameters.pushParams: com.cinemaradar.app
```

这是已实现的华为系统详情页入口，具有厂商依赖。没有 UIAbilityContext 时返回 false；startAbility 失败时返回 `OPEN_SETTINGS_FAILED`。

`EntryAbility` 在通用插件注册之后加入该插件。当前源码没有注册分钟级 WorkScheduler 任务或 continuous task；1.0.3 的 Android/macOS Release 不能视为鸿蒙重新验证结果。

## 8. 什么时候弹引导

页面新增订阅后查看 `BackgroundAccessStatus.needsAttention`：

- 通知明确 false → 需要注意。
- Android 电池豁免明确 false 或后台受限 true → 需要注意。
- macOS 登录项不为 true → 需要注意。
- HarmonyOS → 保持引导可见。

取消订阅不触发新增引导。引导提供“稍后”“允许通知”（明确未授权时）和“去系统设置”。侧边栏状态卡也提供入口。

Android 空状态中 nullable 字段未知时，`needsAttention` 不一定为 true，而卡片的 ready 又要求电池豁免明确 true，因此可能出现卡片建议完善、却不弹新增引导的差异。它源于不同判断条件，不代表已准确识别权限。

## 9. 平台测试要求

Dart 测试可以验证返回值的消费逻辑，但不能替代真实系统授权和设置跳转。至少验证通知允许/拒绝、系统设置不可达、旧 macOS 登录项、关闭窗口再打开、Android 省电/断网、鸿蒙 Ability 失效等场景。
