# 从源码构建 CinemaRadar

本页是快速构建指南；工具链设计、脚本行为、CI 故障与发布流程详见 [Doc/ 构建、CI 与发布](../Doc/12-Build-CI-and-Releases.md)。

当前发布版本为 `1.0.3+4`，发布范围为 Android 和 macOS。源码中的 HarmonyOS 目录保留，未在本版本重新构建验证。

## Flutter SDK 与依赖

本版本使用 OpenHarmony-SIG Flutter `3.41.10-ohos-1.0.0` / Dart `3.11.5`。为复现现有安装包的源码环境，使用下面的确切提交；不要直接跟随分支最新版本：

```bash
git clone https://github.com/hzxslzb/CinemaRadar.git
git init cinema-radar-flutter
git -C cinema-radar-flutter remote add origin https://gitcode.com/openharmony-sig/flutter_flutter.git
git -C cinema-radar-flutter fetch --depth=1 origin refs/tags/3.41.10-ohos-1.0.0:refs/tags/3.41.10-ohos-1.0.0
git -C cinema-radar-flutter checkout --detach 244a0e8abb3085e8675589b13e219af8c41cb7aa
export PATH="$PWD/cinema-radar-flutter/bin:$PATH"
cd CinemaRadar
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
flutter --version
flutter config --no-enable-ohos
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

`pubspec.yaml` 中的三个 Git 插件用于保留 HarmonyOS 适配，同时提供 Android/macOS 实现。解析依赖需要访问 GitCode 和包镜像。保留 `pubspec.lock`；只有计划升级依赖时才重新生成锁文件。

仅开发 Android/macOS 时，`flutter config --no-enable-ohos` 避免依赖解析额外要求鸿蒙 SDK；该设置只影响 Flutter 工具的平台处理。需要开发鸿蒙时重新运行 `flutter config --enable-ohos` 并配置 SDK。

当前自动化测试覆盖场次响应解析、新场次检测、排序筛选、城市/行政区目录缓存、购票链接、订阅持久化、主题与刷新设置、顶部通知关闭/再次出现及周几/展开交互。

## Android

需要 JDK 17、Android SDK Platform 36、Android SDK Command-line Tools。项目携带 Gradle Wrapper，使用 Gradle `8.9`、AGP `8.7.3`、Kotlin `2.1.0`；Flutter 按需下载 NDK。先运行 `flutter doctor -v`，完成 Android SDK 许可与环境配置。

```bash
flutter build apk --release --no-pub
```

会生成：

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/flutter-apk/CinemaRadar-1.0.3+4.apk
```

品牌化文件名自动读取 `pubspec.yaml`。当前最低 Android API 为 24，compile/target SDK 为 36。

当前 `release` 构建使用本机的 Android debug keystore。GitHub Actions 也会生成自己的临时 debug keystore，因此 Actions APK 与已经分发的 APK 通常不能直接覆盖升级。维护稳定分发时应单独配置持久化 release keystore、使用 GitHub Secrets，并保证每次使用同一个签名；不要将私钥或密码提交到仓库。

## macOS

在 Mac 上安装完整 Xcode、Command Line Tools 和 CocoaPods。确保已完成 Xcode 首次启动与许可确认，`flutter doctor -v` 能识别工具链。

```bash
./tool/build_macos_release.sh
```

会生成 Apple Silicon / Intel 通用二进制：

```text
build/macos/Build/Products/Release/CinemaRadar.app
build/macos/CinemaRadar-1.0.3+4.zip
```

应用最低系统版本为 macOS 10.15；登录项管理使用 macOS 13 起提供的系统接口。现有包采用 ad-hoc 签名，没有 Apple 公证。面向正式外部分发时，在自己的 Apple Developer 账号中配置 Developer ID 签名与公证。

## 版本与发布

`pubspec.yaml` 的 `version: 1.0.3+4` 中，`1.0.3` 对应用户版本，`4` 对应 Android versionCode / macOS CFBundleVersion。文件名保留二者，Git 标签使用 `v1.0.3`。

更新版本后构建两个平台，更新 `CHANGELOG.md`，对最终 APK、macOS ZIP 及二合一压缩包运行 `shasum -a 256`，并将校验清单与二进制作为 Release 附件上传。GitHub 自动提供与标签一致的源码 ZIP / tar.gz，不需要把编译产物提交到 Git。

首次公开发布复用此前已验证的 `1.0.3+4` 二进制；本次上传仓库没有另行更改应用版本或编译安装包。

## GitHub Actions

- `CI`：主分支提交和 Pull Request 自动运行依赖锁校验、静态分析、单元及界面测试。
- `Build Android and macOS`：在 Actions 页面选择该工作流，点击 Run workflow，完成后下载对应构建附件。不会自动创建 Release，也不使用维护者的签名私钥。
- CI 与手动构建均读取 `.github/actions/setup-flutter/action.yml` 内的固定 SDK 提交。

## HarmonyOS 源码

`ohos/`、相关插件依赖和构建脚本随仓库保留。需要 DevEco Studio、对应 HarmonyOS SDK 和独立的本机签名，历史目标 SDK 为 API 24。平台配置仍保留上次鸿蒙发布的版本信息，不能视为本次 `1.0.3+4` 的已验证发行版。

首次由 DevEco 生成签名后，可运行：

```bash
node tool/extract_ohos_signing.mjs ohos/build-profile.json5 ohos/build-profile.local.json5
./tool/build_ohos_release.sh
```

提取脚本将私有签名保存到已忽略的 `ohos/build-profile.local.json5`，并清除公共模板内的签名信息；构建脚本只在构建期间临时合并。请在每次提交前检查模板中 `signingConfigs` 仍为空。
