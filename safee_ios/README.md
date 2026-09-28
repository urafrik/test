# Safee Studio · iPhone 原型

独立的原生 SwiftUI / AVFoundation 工程，目标 iOS 16+，无第三方依赖。并非 Safee 官方软件，也没有使用其代码或素材。

只有 Windows 也可以开发：使用仓库中的 GitHub Actions 工作流，在 macOS 云端构建未签名 IPA，再在 Windows 上签名侧载。完整流程见 [Windows 安装说明](INSTALL_WINDOWS.md)。不需要先购买 Pythonista。

## 当前功能

- 麦克风录音，AAC / M4A 文件。
- 前后摄像头切换、JPEG 拍照、有声 MOV 录像。
- 前台黑色界面，双击退出；拍照模式下单击拍照。
- 本地文件列表、图片预览、音视频播放、系统分享导出、删除确认。
- 相机与麦克风权限请求、错误提示。
- 最近 200 条事件持久日志，以及可分享的诊断 JSON。
- App 进入后台或锁屏时停止采集；录制期间禁用自动锁屏。

黑色界面不是系统息屏，不隐藏系统相机或麦克风使用指示。录音功能仅采集麦克风，不代表系统电话、微信或 FaceTime 双方通话录音。没有后台相机、电话中转服务、账户、云同步、文件密码锁或 App Store 发布素材。文件位于 App Documents，卸载会删除；重要文件需主动导出。

## 在 iPhone 运行

1. 将整个 safee_ios 目录复制到 Mac。
2. 用 Xcode 15 或更新版本打开 Safee.xcodeproj。
3. 选择 Safee target，在 Signing & Capabilities 中选择你的 Team，修改 Bundle Identifier 为唯一值。
4. 连接 iPhone，信任 Mac，根据系统要求启用开发者模式。
5. 选择手机作为运行目标，点击 Run。第一次使用时授权相机与麦克风。

2026-09-28 已在 GitHub Actions 的 macOS 环境中通过 Xcode 16.4 编译，生成未签名 IPA，并验证下载文件的 SHA-256 与包结构。[构建记录](https://github.com/urafrik/test/actions/runs/36416033912)。尚未完成 Apple ID 签名、手机安装或真机功能验证。

## Mac 编译检查

```sh
xcodebuild -project Safee.xcodeproj -scheme Safee -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

模拟器不能替代相机和麦克风真机验证。

## 真机验收

1. 分别允许、拒绝相机与麦克风权限，检查错误提示；拒绝麦克风时录像应可无声保存。
2. 录音 10 秒，停止，进入本地文件播放并导出；检查时长和声音。
3. 使用前后摄像头分别拍照与录像，检查画面方向、声音、播放及导出。
4. 录像中打开黑色界面，再双击恢复、停止录像，确认文件有效。
5. 黑色拍照模式单击拍照，双击退出，检查手势不误触。
6. 录制时锁屏、切后台、接电话，确认录制停止且已有文件可播放。
7. 测试低存储空间、相机被其他 App 占用、快速切换模式和重复开始/停止。
8. 删除取消时文件应保留，确认删除后列表应更新。

完成上述测试并修复发现的问题后，才能考虑正式打包或上架。
