# Windows + GitHub Actions：构建和安装

你不需要拥有 Mac。GitHub 的 macOS runner 负责运行 Xcode，Windows 负责管理源码、下载构建产物和侧载。此流程不依赖 Pythonista。

## 1. 创建仓库并上传

1. 登录 GitHub，打开 https://github.com/new 。建议使用私人仓库，名称可用 `safee-ios`，勾选创建 README。
2. 解压 `safee-github-ready.zip`。仓库根目录应该直接包含 `.github`、`safee_ios`、`README.md` 和 `.gitignore`。
3. 在仓库选择 Add file → Upload files，上传解压后的内容并提交。不要只上传 ZIP；GitHub 不会自动解压 ZIP，也不会执行 ZIP 里的 workflow。
4. 若 Windows 或浏览器未上传 `.github` 目录，可用 Add file → Create new file，路径输入 `.github/workflows/build-ios.yml`，把本地同名文件内容粘贴进去后提交。

## 2. 构建和下载

1. 进入仓库的 Actions 标签。若 GitHub 请求启用该仓库的 Actions，按页面说明启用。
2. 选择 `Build iPhone IPA` → `Run workflow` → `Run workflow`。
3. 等待任务显示绿色成功。点击该次运行，在 Artifacts 下载 `Safee-unsigned-ipa`。
4. 解压下载文件，得到 `Safee-unsigned.ipa`、校验值、构建信息和这份说明。
5. 若任务失败，下载 `ios-build-diagnostics`，把 `xcodebuild.log` 发回本聊天。未成功前不要把上传源码当作已成功构建。

工作流只手动触发，不会每次提交自动消耗构建时间。私有仓库可能消耗账号的 Actions 额度；macOS runner 的额度和计费以 GitHub 当前账户页面为准。

## 3. 在 Windows 侧载

该工作流生成的 IPA **未签名**，不能通过“文件”App 点击直接安装。

可以使用 Windows 支持的侧载工具，例如从官方网站获取 Sideloadly（https://sideloadly.io/），按官方说明配置 Apple 设备驱动，连接并信任 iPhone，将 IPA 导入工具，再使用自己的 Apple ID 完成签名和安装。Apple ID、密码及验证码由你在官方登录/签名流程里自行输入，不要放进代码、GitHub 仓库或聊天。

免费 Apple ID 通常使用短期个人开发签名，常见有效期为 7 天，需要重新签名；实际期限和设备/应用数量限制以 Apple 与侧载工具返回结果为准。iPhone 可能要求信任开发者并启用开发者模式，按系统提示操作。

此项目没有在你的手机和 Apple ID 下测试过签名、安装或运行，不能保证所有系统版本和侧载工具组合都可用。

如果已有 Apple Developer Program 账号，后续也可以配置证书和 provisioning profile，让 CI 生成开发或 Ad Hoc 签名包；这版工作流不要求上传证书，也没有实现 TestFlight 发布。

## 4. 设备测试和日志反馈

1. 首次启动分别检查相机、麦克风权限。
2. 先录制 10 秒麦克风声音，停止，检查本地文件可播放。
3. 分别测试拍照、前后摄像头录像、黑色界面恢复以及导出。
4. 点击主界面的诊断按钮，导出 JSON。内容包含版本、iOS 版本、权限状态和最近事件，不包含媒体内容。
5. 反馈时提供：iPhone 型号、iOS 版本、复现步骤、预期/实际结果、诊断 JSON。构建失败则提供 GitHub 的构建日志。
6. 修改代码并提交后，重新触发 workflow、下载并重新签名安装。使用相同签名身份和应用标识有助于保留数据，但升级前仍应导出重要媒体。

## 当前能力

当前原生版本只有麦克风录音、拍照录像、前台黑色界面、本地媒体管理及诊断导出。系统电话双方录音尚未实现，也未进行真机验证。完成 IPA 打包不会自动增加录音权限。
