# 04 · 领域模型与本地存储

实现入口：[模型](../lib/domain/models.dart)、[SubscriptionStore](../lib/data/subscription_store.dart)。以下 JSON 是说明结构的示例，不代表实时可购场次。

## 1. 实体及关系

| 模型 | 核心字段 | 用途 |
| --- | --- | --- |
| `CityOption` | `id`、`name`、`pinyin` | 城市目录与本地搜索 |
| `DistrictOption` | `id`、`name`、`cinemaCount` | 行政区选择与数量展示 |
| `RefreshIntervalOption` | `minutes`、`label` | 可选刷新间隔与 Android 下限换算 |
| `Cinema` | 影院 ID、城市 ID、名称、区域、地址 | 查询排片的上下文 |
| `Session` | ID、日期、时间、语言、制式、影厅、售卖状态 | 单场电影放映 |
| `MovieSchedule` | 影片信息及 `sessions` | 某影院中一部影片的场次 |
| `CinemaSnapshot` | 影院 ID、影院名、影片集合、抓取时间 | 一次影院响应快照 |
| `MovieSubscription` | 影院、影片、已见 ID、创建和检查时间 | 新场次比较基线 |
| `NewSessionNotice` | 订阅快照及本次新增场次 | 一条影院/影片变更结果 |
| `NewSessionAlert` | 批次 ID、创建时间、若干 notice | 当前顶部提醒批次 |

这些都是应用中的值对象或数据载体，不是数据库表。当前没有 ORM、SQLite 外键或数据库迁移系统。

## 2. ID 体系

### 2.1 城市与影院

`Cinema.key = '$cityId:$id'`，例如 `10:37534`。即使数据源当前影院 ID 看起来全局唯一，代码仍保留城市上下文。

`CityOption` 和 `DistrictOption` 的相等/哈希按各自 ID 计算。行政区使用时必须结合所选城市，不要将不同城市的行政区对象合并进一个只按区 ID 索引的全局表。

### 2.2 订阅

`MovieSubscription.key = '${cinema.key}:$movieId'`，例如 `10:37534:1545360`。

同一影片在不同影院是不同订阅；同一影院中的同一影片按 key 查找并切换订阅状态。存储层没有数据库唯一约束，唯一性由控制器的查找逻辑和检测器的映射组织维持。

### 2.3 场次

`Session.id` 来自猫眼 `seqNo`，存成字符串。不要转为数字再比较：字符串处理可避免前导零丢失和潜在精度问题。

### 2.4 提醒批次

批次 ID 使用当前时间的微秒时间戳转字符串。它便于区分最近批次，并不是服务端全局唯一 ID；系统时钟调整和并发执行环境仍有理论上的碰撞或顺序问题。

## 3. 日期和时间

- `Session.date` 是数据源日期字符串，通常为 `YYYY-MM-DD`。
- `Session.time` 通常为 `HH:mm`。
- `Session.startsAt` 使用 `DateTime.tryParse('$date $time')`。
- `CinemaSnapshot.fetchedAt` 默认取客户端 `DateTime.now()`，不是电影上架时间或服务器更新时间。
- `createdAt`、`lastCheckedAt` 通过 ISO-8601 字符串序列化。

模型没有显式的影院时区字段。影院业务语义是中国大陆本地排片日期，通知周几按日期字符串计算；排序和格式化没有接入时区数据库，也不进行服务器时钟校正。

## 4. 售卖状态与影厅派生属性

`canBuy` 仅对 `ticketStatus` 为 `0` 或 `5` 返回 true。状态映射为：0 可购、1 满座、2/3 停售、5 特惠，其余未知。

影厅类别从 `format + hall` 归一化后推断，不从正式的厅型枚举字段读取。完整规则见 [排片与购票](06-Schedule-and-Ticketing.md)。

## 5. SharedPreferences 键

| 键 | 类型 | 默认/损坏处理 | 含义 |
| --- | --- | --- | --- |
| `movie_subscriptions_v1` | JSON 字符串 | 缺失、空值或解码异常返回空列表 | 全部影片订阅 |
| `dark_theme_v1` | bool | 默认 false | 是否深色主题 |
| `refresh_minutes_v1` | int | 默认 15；控制器对不支持值回退 15 | 后台间隔分钟数 |
| `new_session_alert_v1` | JSON 字符串 | 缺失返回 null；损坏时删除并返回 null | 最近未关闭提醒批次 |
| `custom_cinemas_v1` | 历史键 | 初始化时删除 | 已移除的影院级留存 |

主题和间隔是独立键。订阅和提醒不是同一事务，因此不能保证崩溃后两者总是同步提交。

## 6. 订阅 JSON 示例

```json
[
  {
    "cinema": {
      "id": 37534,
      "name": "MOViE MOViE 影城（前滩太古里店）",
      "cityId": 10,
      "cityName": "上海",
      "district": "浦东新区 · 前滩",
      "address": "示例地址"
    },
    "movieId": 1545360,
    "movieName": "奥德赛",
    "seenSessionIds": ["session-A", "session-B"],
    "createdAt": "2026-08-14T10:00:00.000",
    "lastCheckedAt": "2026-08-14T10:03:00.000"
  }
]
```

订阅中保存影院名称和地域，是为了在不保留影院浏览历史的情况下恢复查询上下文。存储范围是用户订阅所需数据，而不是完整城市/影院目录。

`seenSessionIds` 在内存中是 `Set<String>`，JSON 中是字符串数组；反序列化后重新构造集合。模型的集合字段是 `final` 引用，但没有全部封装为不可变集合，因此并不等于深层不可变。

## 7. 提醒批次 JSON 示例

```json
{
  "id": "batch-example",
  "createdAt": "2026-08-16T09:00:00.000",
  "notices": [
    {
      "subscription": {
        "cinema": {
          "id": 37534,
          "name": "MOViE MOViE 影城（前滩太古里店）",
          "cityId": 10,
          "cityName": "上海",
          "district": "浦东新区"
        },
        "movieId": 1545360,
        "movieName": "奥德赛",
        "seenSessionIds": ["session-A"],
        "createdAt": "2026-08-14T10:00:00.000",
        "lastCheckedAt": null
      },
      "sessions": [
        {
          "id": "session-C",
          "date": "2026-08-16",
          "time": "09:45",
          "language": "英语",
          "format": "IMAX2D",
          "hall": "IMAX 激光厅",
          "ticketStatus": 0
        }
      ]
    }
  ]
}
```

`notice.subscription` 是生成提醒时的订阅对象快照，可能含更新前的旧基线；最新比较基线保存在订阅列表中。提醒展示不应将这个订阅快照写回替代最新存储。

## 8. 更新、读取与清理

### 8.1 更新订阅

检测后使用 `copyWith(seenSessionIds: currentIds, lastCheckedAt: fetchedAt)`。这里保存的是本次可见场次集合，**不是所有历史场次 ID 的永久并集**。

因此，场次消失一轮后再次出现，会再次被视为新增；影片本次未出现在响应中时，该订阅基线会变为空集合。相关后果见第 07、11 章。

### 8.2 清理提醒

`clearNewSessionAlert(expectedId:)` 在删除前读取当前批次：若当前 ID 与预期 ID 不同就返回，尽量避免关闭旧提醒时删除新提醒。

这一检查是“先读再删”，不是存储引擎的 compare-and-swap。另一个执行环境在读取后写入新批次时，仍存在跨环境竞态可能。

### 8.3 损坏数据

- 订阅解码失败：返回空列表，不主动删除原始键；之后若有保存操作，可能覆盖旧内容。
- 提醒解码失败：删除损坏键。
- 当前没有逐条抢救损坏订阅、备份、数据导出或迁移报告。

## 9. 多执行环境一致性

Android Worker 和前台控制器可能使用各自的 SharedPreferences 缓存。当前没有显式 `reload()`、跨执行环境互斥锁、订阅版本号或事务。

因此，前后台并发保存、用户删除订阅与后台写回、提醒批次与基线不同步等情况需要作为维护风险考虑。不能把当前存储描述为强一致数据库。

## 10. 结构演进建议

未来若增加多批次历史、通知投递状态或多数据源，需要显式 schemaVersion、可回滚迁移和逐记录损坏恢复。先定义迁移，再调整模型；不要仅重命名键后丢弃用户订阅。
