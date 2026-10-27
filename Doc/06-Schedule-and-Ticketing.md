# 06 · 排片浏览、筛选与购票

实现入口：[模型解析与排序](../lib/domain/models.dart)、[页面和购票弹层](../lib/app.dart)、[链接构造](../lib/services/ticket_links.dart)。

## 1. 响应如何变成页面

`CinemaSnapshot.fromMaoyan` 从 `data.movies` 创建影片列表。每个影片的 `shows[]` 下遍历 `plist[]`，将场次展平为一个 `List<Session>`。

外层日期节点的 `showDate` 没有被用于回填场次日期，`Session.date` 直接来自场次的 `dt`。若上游只有 `showDate` 而省略 `dt`，当前代码不会自动推断日期。

| 上游字段 | 应用字段 | 处理 |
| --- | --- | --- |
| `movies[].id` | `MovieSchedule.id` | 必需数值，转 int |
| `nm` | `name` | 缺失时为“未知影片” |
| `dur` | `durationMinutes` | 缺失时为 0 |
| `desc` | `description` | 缺失时为空字符串 |
| `img` | `posterUrl` | 将 `w.h` 替换为 `260.360` |
| `seqNo` | `Session.id` | 转字符串；空 ID 场次被移除 |
| `dt/tm` | `date/time` | 缺失时为空字符串 |
| `lang/tp/th` | `language/format/hall` | 缺失时为空字符串 |
| `ticketStatus` | `ticketStatus` | 缺失时为 -1 |

没有任何有效场次的影片被过滤。影片列表按场次数量从多到少排序，而不是按评分、上映日期或片名字母排序。

## 2. 选中影片规则

刷新成功后按以下优先级选择影片：

1. 若调用提供 `preferredMovieId` 且快照中存在该影片，选中它。
2. 当前没有选中影片，或原选中 ID 已消失时：默认回归影院优先选择《奥德赛》，否则取影片列表第一部。
3. 原影片仍存在时，替换成这次快照内同 ID 的新对象，保持用户选择。

订阅跳转在当前影院/影片已存在于快照时直接选中，不额外请求网络。目标影院不同或目标影片不在当前快照时，刷新并尝试按订阅影片 ID 选中。

若订阅影片不再返回，控制器会回退到默认/第一部可用影片；当前没有“已下映的目标影片占位页”。因此点击订阅后出现另一部影片，不应直接认定订阅存储损坏。

## 3. 排序和日期分组

`MovieSchedule.visibleSessions(category:, order:)`：先按影厅类别过滤，复制为新列表，再排序。

- 两个 `startsAt` 均可解析：比较 `DateTime`。
- 只要一方无法解析：回退比较 `'date time'` 字符串。
- 降序是把比较结果取反。

排片面板之后按 `Session.date` 插入分组 Map。Map 保留插入顺序，因此时间降序也会自然使日期分组呈倒序。

`sessionsByDate` 则只是原始分组 getter，不自动进行时间排序。调用者不能把这个 getter 与 UI 的“排序后分组”视为相同契约。

## 4. 影厅分类规则

待判定文本为 `'$format $hall'.toUpperCase().replaceAll(' ', '')`，按下列优先级匹配：

| 顺序 | 条件 | 分类 |
| --- | --- | --- |
| 1 | 包含 `IMAX` | `imax` / IMAX |
| 2 | 包含 `DOLBY`、`杜比` 或 `ATMOS` | `dolby` / Dolby |
| 3 | 包含 `CINITY`、`中国巨幕`、`CGS`、`SCREENX`、`4DX`、`MX4D`、`LUXE`、`LED厅`、`激光厅` | `otherSpecial` / 其他特效厅 |
| 4 | 其余 | `standard` / 普通厅 |

同一文本同时命中多个条件时以前面的规则为准。`ATMOS` 被当前 UI 统一归为 Dolby，但这不等同于“Dolby Cinema 认证影厅”；“激光厅”也被归为其他特效。这些是产品筛选规则，不能作为影院设备的权威认证。

只有 `3D` 字样而没有其他特殊关键词时会归普通厅。默认“全部影厅”对应 `category == null`。

## 5. 场次卡片和售卖状态

卡片显示时间、状态、语言/制式和影厅。固定宽度 210，以 Wrap 进行换行；这是流式卡片布局，不是独立计算列高的 masonry 瀑布流。

| 状态值 | 文案 | 允许点击购票 |
| --- | --- | --- |
| 0 | 可购 | 是 |
| 1 | 满座 | 否 |
| 2、3 | 停售 | 否 |
| 5 | 特惠 | 是 |
| 其他 | 未知 | 否 |

该状态来自抓取瞬间，未再次查询库存。通知中的场次也可能在用户点击前售罄或停售。

## 6. 购票入口协议

| 入口 | URL / Scheme | 是否携带具体场次 |
| --- | --- | --- |
| 猫眼网页 | `https://m.maoyan.com/mtrade/cinema/seat` | 是 |
| 猫眼 App | `https://deeplink.maoyan.com/maoyan-app/app?channel=CinemaRadar` | 否，官方通用唤端页 |
| 淘票票 App | `tbmovie://taobao.com/` | 否 |
| 支付宝淘票票 | `alipays://platformapi/startapp?appId=20000131` | 否 |
| 淘票票网页 | `https://h5.m.taopiaopiao.com/` | 否 |

猫眼网页参数：

```text
seqNo = session.id
cinemaId = cinema.id
movieId = movie.id
ci = cinema.cityId
```

链接由 `Uri.https` 构造并编码，避免人工拼接参数转义错误。`maoyanWeb` 接收完整影片，内部委托 `maoyanWebForSession`；后者便于提醒组件只持有影片 ID 时使用。

猫眼 App 按钮不是“自动定位当前影院当前场次的原生选座深链”。真正保留具体场次参数的是猫眼网页按钮。淘票票场次 ID 不与猫眼互通，用户需要在淘票票重新搜索和确认。

## 7. 打开与回退

所有入口使用 `LaunchMode.externalApplication`。淘票票 App 和支付宝入口配置了网页 fallback：唤起返回 false 或抛异常时尝试网页。

猫眼 App 本身为官方 HTTPS 唤端页面，当前调用没有额外指定 fallback。所有尝试失败且页面仍 mounted 时显示 SnackBar。

底部弹层先关闭，再调用外部链接。当前没有保存“外部购票成功”“选了哪个座位”“最终订单”回执，也没有从票务 App 返回后自动核对订单。

## 8. 日期显示的差异

- 排片日期组用 `_DateGroup._dateLabel`，显示“8月16日 · 周日”。
- 系统通知和顶部提醒共用 `formatSessionDate`。
- 购票弹层副标题目前仍直接显示 `session.date session.time`，不是所有日期位置都使用同一个格式函数。

这说明 1.0.3 的“周几”更新针对提醒及既有日期分组，并不是全项目所有日期文案都完成统一。

## 9. 未接入的直接票务交易

当前不会请求实时座位图、锁座、支付或出票接口。若未来接入，至少需要数据源场次映射、座位状态、防隔座校验、锁座超时、支付回调、幂等出票、解锁、退款及对账；仅给客户端拼一个 URL 不构成完整票务功能。

后续路线见 [扩展方案](14-Extension-and-Technical-Debt.md)。
