# 开发与反馈

请先阅读 [README](README.md)、[构建说明](docs/BUILDING.md) 和 [数据源说明](docs/DATA_SOURCES.md)。

完整架构和实现资料位于 [Doc/ 技术文档中心](Doc/README.md)。修改功能时同步维护对应专题、API/常量速查和必要的测试；尚未实现的方案应明确标记，不能直接写成已有能力。

## 问题反馈

在 [Issues](https://github.com/hzxslzb/CinemaRadar/issues) 中提供应用版本、设备/系统版本、复现步骤、期望结果和实际结果。排片相关问题请附城市、影院名称、影片及发生时间；截图请先移除个人信息。

后台提醒可能被系统延迟。报告这类问题时请说明通知权限、电池优化设置、后台刷新间隔和是否主动结束过应用。

## 修改代码

1. Fork 仓库并创建分支。
2. 按构建说明安装固定版本的 Flutter SDK。
3. 修改后运行 `flutter analyze` 和 `flutter test`。
4. 提交 Pull Request，说明用户可观察到的变化和验证结果。

请保留按影院合并请求、按需加载和差量场次检测；无需查询全城、座位图或实时票价来完成订阅。

不要提交 `.env`、签名证书、密钥、`local.properties`、私有 HarmonyOS 签名配置和个人订阅数据。安装包作为 GitHub Release 附件分发，不提交到 Git 历史。

## 发布约定

- `pubspec.yaml` 是 Android/macOS 版本来源，版本形式为 `1.0.3+4`。
- 用户版本变更时更新版本号，发布时递增构建号，并更新 `CHANGELOG.md`。
- 文件名包含完整版本，如 `CinemaRadar-1.0.3+4.apk`。
- Release 使用 `v1.0.3` 形式的标签，并附安装包和 SHA-256 校验清单。
- GitHub Actions 手动构建使用临时调试签名；不能当作现有 Android 安装包的同签名升级。正式稳定升级需要维护者自己的持久化签名密钥。
