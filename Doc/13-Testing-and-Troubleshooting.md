# 13 · 测试、回归与故障定位

实现入口：[自动化测试](../test/schedule_test.dart)、[在线回归脚本](../tool/live_regression.dart)、[CI](../.github/workflows/ci.yml)。

## 1. 测试分层

| 层级 | 当前覆盖 | 不能据此证明 |
| --- | --- | --- |
| 纯函数/模型 | 解析、差量、分类、日期、链接、序列化 | 上游接口实时可用 |
| Mock HTTP | 城市/区/影院与目录缓存 | 所有真实分页与风控场景 |
| Widget 测试 | 主页面、主题、侧栏、提醒展开/关闭/再次出现 | 系统通知实际送达、原生设置可达 |
| 在线脚本 | 历史指定影院和影片响应 | 影片永久上映或服务 SLA |
| 手动真机 | 历史平台回归记录 | 所有厂商/系统版本都兼容 |

## 2. 11 项自动化测试对应关系

| 序号 | 测试名 | 核心断言 |
| --- | --- | --- |
| 1 | `formats session dates with Chinese weekdays` | 长短日期、周日/周一、无效日期回退、通知正文周几 |
| 2 | `parses Maoyan cinema response and groups Odyssey sessions` | 影院与影片 ID、场次数、日期分组、可购状态 |
| 3 | `detects only unseen seqNo values as new sessions` | 只返回不在旧 ID 集合中的场次 |
| 4 | `sorts sessions by start time and groups normal versus special halls` | 时间升序、普通厅过滤、Dolby/IMAX 分类 |
| 5 | `loads and caches city, district and district-scoped cinema directories` | 城市/行政区解析、关键词匹配、重复读取只产生三次 Mock 请求 |
| 6 | `keeps exact Maoyan seat URL and separate Taopiaopiao routes` | seqNo/影院参数、淘票票/支付宝 scheme、网页域名 |
| 7 | `subscription serialization preserves the baseline session set` | key 和已见 ID 集合往返一致 |
| 8 | `persists theme and refresh settings and removes legacy cinema cache` | 主题、间隔、前台 3 分钟、Android 15 分钟下限、旧键清理 |
| 9 | `renders the regression cinema, Odyssey and session action` | 主页面、影片、订阅和购票入口存在 |
| 10 | `opens subscription drawer, toggles dark mode, jumps and deletes` | 主题切换、侧栏、跳转目标影片、确认删除及空态 |
| 11 | `shows, dismisses and shows the next persisted new-session alert` | 周几、展开/收起、纵向滚动方向、清除当前批次和显示下一批 |

测试总数不是测试充分性的度量。部分测试一次覆盖多个行为，但通知权限、真实网络、并发存储等仍未覆盖。

## 3. 运行命令

在固定 Flutter SDK 环境中：

```bash
flutter config --no-enable-ohos
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

只运行提醒回归：

```bash
flutter test --no-pub test/schedule_test.dart \
  --plain-name 'shows, dismisses and shows the next persisted new-session alert'
```

如果只修改 Markdown，应优先验证链接、代码块、图和源码对应关系，不需要为文档重新构建所有安装包。当前 Actions 对 main 的文档提交仍会自动跑既有 CI。

## 4. 测试中的替身

- `MockClient` 根据 URL path 返回固定 JSON，不访问猫眼。
- `_FakeProvider` 直接返回固定 `CinemaSnapshot`。
- `SharedPreferences.setMockInitialValues` 隔离本地配置。
- 外部注入控制器避免 Widget 再次初始化真实 Provider。
- `BackgroundAccessService` 在 `FLUTTER_TEST=true` 时跳过原生 MethodChannel。

测试不应依赖本机已有订阅、真实影院此刻排片或系统权限弹窗，否则很难稳定复现。

## 5. 当前重要缺失测试

1. `checkAll` 完整调用链中的多影院聚合、通知失败容错和保存顺序。
2. 分页边界、重复影院 ID、无效影院、HTTP 非 200 和超时。
3. 快速切城市/区/影院导致的请求交错。
4. 前台与 Worker 同时更新或删除订阅。
5. 影片消失一轮再恢复导致的重复新增语义。
6. 真正系统通知点击与冷启动路由。
7. 小屏、大字号、很多新增场次的滚动和渲染性能。
8. macOS 删除最后订阅后的 Timer 状态。

新增测试应验证真实业务风险，而不只是逐行重复代码实现。

## 6. 在线回归脚本的历史假设

```bash
dart run tool/live_regression.dart
```

该脚本会真实请求：城市列表、上海行政区、浦东影院列表、默认影院排片。要求城市数量至少 1000、影院 ID 37534 存在，以及影院响应中包含《奥德赛》。

最后一项随上映周期变化，因此在 2026-10-27 之后运行可能因影片不再排片而失败。这不是足以判定 Provider 整体损坏的证据。在线回归不在当前 CI 中自动执行，也不是持续监控。

建议后续将目标影院/影片参数化，并将“接口结构有效”与“指定影片恰好存在”分开判断；这是待实现建议。

## 7. 手动验收矩阵

| 场景 | 操作 | 应观察结果 |
| --- | --- | --- |
| 首次启动 | 清空测试数据后启动 | 默认影院加载，浅色主题，无订阅 |
| 切换影院 | 城市 → 区 → 关键词 → 确认 | 只查询选定影院排片 |
| 多关键词 | 输入品牌与商圈 | 本地 AND 匹配，无逐字网络请求 |
| 初次订阅 | 订阅已有多场次影片 | 记录基线，不立即全部提醒 |
| 新增场次 | 使用受控测试数据产生新 ID | 系统通知尝试、顶部显示新批次 |
| 周几 | 选定已知星期的日期 | 通知与顶部文字一致 |
| 展开 | 点击展开并上下滚动 | 看见日期/时间/语言/版本/影厅/状态 |
| 关闭 | 关闭后再生成下一批 | 当前批次清除，下一批重新显示 |
| 通知拒绝 | 拒绝系统通知 | 订阅仍可保存、应用内批次可见 |
| 外部购票 | 点具体猫眼场次 | URL 含场次/影院/影片/城市 |
| 未装淘票票 | 点淘票票 App | 尝试网页 fallback |
| 主题 | 切换并重启 | 保存的模式恢复 |
| Android 后台 | 选 5 分钟，观察系统任务 | 以 15 分钟下限调度，不承诺准点 |
| macOS 关窗口 | 保留订阅后关闭窗口 | 进程仍可运行；主动退出后停止 |
| 无网络 | 断网刷新 | 显示错误，已有快照可能仍展示 |

真实新增场次通常无法在几分钟内人为控制，因此应先用受控样本验证业务，再单独做真实权限/网络/通知验证。

## 8. 故障定位速查

### 8.1 CI 失败

先查看最新 main 的提交 SHA 和 Actions 运行结果。历史某次失败不等于最新分支失败。

`No Hmos SDK found`：检查固定 SDK 初始化中是否执行 `flutter config --no-enable-ohos`。不要在 Android/macOS CI 上随意填一个不存在的 `HOS_SDK_HOME` 来绕过检查。

SDK 显示未知版本：检查是否拉取了 tag 元数据以及 HEAD 是否为指定 commit。

锁文件失败：确认 SDK、镜像环境与 Git 依赖可访问，避免直接删除锁文件升级所有包。

### 8.2 城市或影院太少

区分“接口返回少”与“搜索页面最多显示 100 个城市结果”。影院目录还受所选区、接口分页和 2000 偏移保护影响。查原始响应字段，不要立即改成全城高频爬取。

### 8.3 一直加载或旧排片

检查 controller.error、snapshot 和 loading。首屏失败可能显示错误条同时保留加载占位；快速切影院还可能存在旧响应竞态。记录请求影院 key 与响应影院 ID。

### 8.4 没有新增通知

按顺序确认：订阅是否保存 → 当前响应有目标影片 → seqNo 是否确实新增 → 检测是否运行成功 → 系统通知是否授权 → 顶部是否有持久化批次。

仅时间变化、已有 ID 的可售状态变化、当前筛选条件变化都不属于新增。macOS 登录项开启也不能证明通知权限开启。

### 8.5 后台不准时

检查网络、电量、系统通知、省电与后台限制；确认进程是否被主动结束。Android WorkManager 不是精准闹钟；macOS Timer 不能在主动退出或休眠时继续执行。

### 8.6 macOS Swift 模块缓存失效

更换 Flutter 后，历史构建缓存可能引用旧头文件。优先使用 Xcode 的项目级 clean；仍有冲突时仅处理已确认的本项目构建中间目录，并保留原始安装包。不要用删除整个用户目录或所有项目缓存的办法解决。

### 8.7 Android 无法覆盖安装

检查新旧 APK 签名是否一致，尤其是本机与 CI debug keystore。不要直接卸载覆盖问题而忽略本地订阅丢失风险；先告知数据影响并确认处理方式。

## 9. 建议收集的最小证据

应用版本、平台/系统版本、城市影院与影片、操作步骤、发生时间、前后台状态、刷新选项、错误文案、脱敏响应结构及相关 Actions 链接即可。不要上传凭据、证书密码、支付信息或其他应用的私人通知。
