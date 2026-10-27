# 10 · 页面状态、布局与主题

实现入口：[app.dart](../lib/app.dart)、[AppController](../lib/app_controller.dart)、[搜索弹窗](../lib/widgets/cinema_search_dialog.dart)。

## 1. 状态管理方式

项目使用 Flutter `ChangeNotifier` + `ListenableBuilder`。没有额外引入 Provider、Riverpod、GetX 或 BLoC。

`AppController` 修改字段后调用 `notifyListeners()`，根 MaterialApp 和主页面分别监听。主题变化可更新整个 App；选片、刷新和订阅变更主要通过页面监听刷新。

这是一种轻量做法，但依赖整个控制器的监听器可能在任意字段变化时重建。当前没有按属性选择监听或细粒度状态切片。

## 2. 控制器所有权

### 正常应用

`CinemaRadarApp` 未收到 controller 时创建并初始化，在自身销毁时释放。它将 controller 传给 `CinemaHomePage`，后者不重复创建/释放。

### 独立页面或测试

`CinemaHomePage` 自己没有收到 controller 时，也可以自行创建并初始化，并在页面销毁时释放。

外部注入的控制器由外部负责 dispose；Widget 测试显式移除页面后再释放控制器。否则计时器和生命周期观察者可能留存。

控制器的 dispose 会取消 Timer，并在注册过观察者时移除 `WidgetsBindingObserver`。

## 3. 主页面组件结构

```text
Scaffold
├── endDrawer: SubscriptionDrawer
└── SafeArea
    └── Center + 最大宽 1180
        └── Column
            ├── NewSessionAlertBar（有批次时）
            └── Expanded + CustomScrollView
                ├── Header（图标、标题、订阅、日月、说明）
                ├── CinemaPicker（当前影院、切换、立即刷新）
                ├── Error（有错误时）
                └── Content（影片列表 + 排片面板）
```

顶部消息位于主滚动容器外，因此主排片滚动时消息保持在页面顶部。消息自己的内容有独立滚动，而不是系统 overlay。

## 4. 布局参数

| 区域 | 参数与行为 |
| --- | --- |
| 页面内容 | 最大宽度 1180 |
| 主内容双列 | LayoutBuilder 可用宽度 ≥ 840 |
| 宽屏影片列表 | 左侧宽 330、高 700 |
| 窄屏影片列表 | 高 182，影片横向排列 |
| 影片方向判断 | `_MovieList` 按整个 MediaQuery 宽度 < 840 决定横向 |
| 普通场次卡 | 宽 210，Wrap 自动换行 |
| 侧栏 | 屏幕宽 < 460 时占 92%，否则宽 420 |
| 搜索弹窗 | 内容宽 560，高度为屏高 72%，限制 420～620 |
| 购票底部弹层 | 可滚动，高度比例 0.78 |

主内容和影片列表使用的断点来源略有不同（可用内容宽 vs 整屏宽）。桌面窗口尺寸、边距或嵌套容器特殊时，需要验证两者是否保持一致。

## 5. 主要页面状态

| 状态 | 当前展示 |
| --- | --- |
| `snapshot == null` | 加载占位 CircularProgressIndicator |
| `snapshot.movies.isEmpty` | “该影院目前没有可展示的排片” |
| `error != null` | 显示错误条，已有快照可能继续保留 |
| 刷新中 | “立即刷新”按钮禁用并显示小进度指示 |
| 影厅筛选无结果 | 独立的“没有符合条件场次”文案 |
| 订阅为空 | 侧栏显示空态引导 |
| `newSessionAlert != null` | 顶部批次卡片 |

首次请求失败且没有快照时，错误条出现但内容区仍为加载占位，因为 UI 用 snapshot 是否为空而非 loading 来选择占位。它可能看起来一直转圈；当前没有独立的“初始加载失败”内容组件。

## 6. 影院、影片与历史

当前影院只是控制器字段。重启后默认回到 `knownCinemas.first`，不会自动恢复最后浏览影院。

订阅条目保留了影院上下文，所以用户可以通过侧栏返回过去关注的影院，而无需保留独立的影院历史列表。初始化还会删除旧版 `custom_cinemas_v1`。

影片选择在刷新同影院时尽量保持；切换影院会清空快照和选中影片后重新加载。

## 7. 局部状态的持续时间

| 状态 | 归属 | 是否持久化 |
| --- | --- | --- |
| 深色主题 | AppController + Store | 是 |
| 后台间隔 | AppController + Store | 是 |
| 当前影院/影片 | AppController | 否 |
| 排序/筛选 | `_SchedulePanelState` | 否 |
| 提醒展开 | `_NewSessionAlertBarState` | 否，新批次重置 |
| 城市、区、搜索词 | 搜索弹窗 State | 否 |
| 地域请求结果 | 主页面持有的目录 Provider | 仅内存 |

排片面板未按电影 ID 重新设置 key，也没有 `didUpdateWidget` 主动清空排序/筛选，因此 Widget State 被复用时，切片后的筛选条件可能继续生效。页面显示空场次时应先看是否保留了筛选，而非直接判断接口为空。

## 8. 主题和字体

主题使用 Material 3 和 `ColorScheme.fromSeed`，种子色 `#E6534E`。浅色背景 `#F6F3ED`，深色背景 `#141414`，卡片使用对应明暗表面色。

`darkMode` 默认 false，从 SharedPreferences 读取。日月按钮调用 `toggleTheme`，立即通知 UI 后保存。当前没有“跟随系统”第三种模式，也不会在系统夜间切换时自动改设置。

字体没有自定义 `fontFamily`、字体资产或 Google Fonts 依赖；基础字体来自 Flutter ThemeData 及系统回退。应用对标题字号、字重、行高、字距做了覆盖，如大标题 34、w800、letterSpacing -1.2。

因此，“未新增字体文件”不等于升级 Flutter 后文字渲染完全相同。SDK 版本、平台默认字体、系统缩放和 fallback 都可能改变视觉表现。

## 9. 图片与图标

- 共用图标资产为 `assets/branding/cinema_radar_icon.png`，设计为包豪斯风格的荧幕与雷达元素。
- Android mipmap、macOS AppIcon 和鸿蒙资源分别保留平台尺寸。
- 影片海报使用 `Image.network`，没有持久化离线海报缓存；失败时显示电影图标。
- 未按平台提供独立的完整页面实现，主要使用同一 Flutter UI 配合平台条件文案。

## 10. 交互与可访问性现状

主要图标提供 tooltip（订阅管理、主题、关闭、展开等），列表和按钮采用 Flutter 标准控件。长影院/影片文案在部分位置使用省略号或 Wrap。

当前没有完整的键盘快捷键映射、读屏人工审计、超大字号矩阵或专门的桌面菜单导航测试。极窄宽度、低高度、2 倍文字缩放和大量场次应列入后续 UI 验证，而不是默认认为标准控件已覆盖所有场景。
