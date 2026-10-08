# SearcheXtra

SearcheXtra 是基于 [Search](https://github.com/driceroland/Search) 的修改版，保留原版轻量、简洁的浏览体验，增加了**简体中文支持和界面语言切换**。原项目由 [Office Commun](https://officecommun.com) 开发，本仓库维护修改版。

支持英文和简体中文，菜单、设置项及说明、弹窗和操作提示均提供两套文案。在 **设置 → 通用 → 界面语言** 中选择“跟随系统”“English”或“简体中文”，点击“重新启动 SearcheXtra”后生效。默认跟随系统，不支持的系统语言使用英文。

![SearcheXtra 浏览器界面，标签页位于左侧，网页占据其余区域](.github/screenshot.png)

**[下载 macOS 版本 →](https://github.com/small32/SearcheXtra/releases/latest)** · macOS 14 或更新版本 · 当前提供 ARM64 安装包，适用于 Apple 芯片 Mac

安装包由 GitHub Actions 构建。下载 Release 中的 ZIP，解压后将 `SearcheXtra.app` 放入“应用程序”文件夹；`SHA256SUMS.txt` 提供安装包的 SHA-256 校验值。应用、安装包和界面均使用 SearcheXtra 名称。

---

为兼容旧版本，数据目录、偏好设置域和密码钥匙串仍沿用 Search 的内部标识；重命名不会清空这些数据。

## 项目介绍

SearcheXtra 将界面留给标签页和网页。标签页可以横排在顶部，也可以竖排在侧边栏。地址栏同时用于输入网址和搜索词，没有推荐内容、账号登录入口或云同步服务。

浏览器使用 macOS 内置的 **WebKit** 引擎，与 Safari 使用同一套底层技术，无需附带 Chromium 引擎。

本分支将界面文案整理为独立的英文和中文翻译表，便于继续维护中文支持。语言设置保存在本机，切换语言不会修改书签、历史记录或快捷键标识。

## 主要功能

在 **设置 → 通用 → 起始页面** 中输入网址并保存，用于新窗口的起始页面；支持省略协议的网址，例如 `example.com`。选择“使用空白页”可恢复空白页面。更改立即生效，已打开和恢复会话的页面保持原样。新建标签页默认使用空白页，不受起始页面设置影响；若已启用自定义新标签页的扩展，则使用扩展页面。无痕标签页仍使用空白页。

- **地址与搜索合一。** 输入网址直接打开，输入文字使用搜索引擎。地址补全来自本机历史记录，按下回车前不会发送输入内容。
- **标签页与固定标签页。** 常用页面可以固定，显示为字母或网站图标。上次会话的标签页会恢复，切换到对应标签页时才创建网页视图。`⌘K` 按名称查找已打开的标签页。
- **分屏浏览。** 在“设置 → 标签页”中启用分屏，将标签页拖到页面边缘，或选择“标签页 → 拆分当前页面”。拖动分隔线调整宽度，带边框的页面接收操作指令。分屏组合和宽度随空间保存，重启后可以恢复。
- **阅读模式。** `⇧⌘R` 提取文章正文，减少页面干扰。
- **隐藏网页元素。** 按下 `⇧⌘H` 后点击 Cookie 提示、订阅浮层或其他元素。隐藏规则按网站保存，下次访问时在页面绘制前生效。
- **广告与跟踪拦截。** 在网络请求阶段拦截第三方跟踪器和广告网络。默认启用，也可以按网站关闭。
- **画中画。** `⇧⌘P` 将视频放入悬浮窗口，切换应用时仍可观看。
- **密码与钥匙串。** 登录成功后提示保存密码，点击登录字段时显示已保存账号。密码保存在 macOS 钥匙串中，由系统加密；支持从 Chrome、Arc、Dia、Brave 或 Edge 导入。系统通行密钥功能需要相应的签名和授权配置。
- **浅色、深色与跟随系统。** 浏览器界面和网页可以随外观设置切换。
- **书签、历史记录与下载。** 各自提供独立面板，支持搜索和快捷键打开。
- **Chrome 扩展。** 在“设置 → 扩展”中粘贴 Chrome 网上应用店链接，或打开扩展页面后点击添加。扩展运行在 WebKit 的扩展引擎上，浏览器补充部分 Chrome API。常用扩展可以固定，也可以加载本地未打包扩展，修改后点击重新载入。此功能需要 macOS 15.4 或更新版本，兼容情况取决于扩展使用的 API。
- **多窗口与空间。** 可以创建多个窗口，并使用空间管理不同的标签页集合。
- **版本更新。** 本分支的安装包从 [GitHub Releases](https://github.com/small32/SearcheXtra/releases) 下载更新。目前代码中的自动更新源仍指向上游，临时签名构建无法完成自动替换；本分支尚未接入自己的自动更新渠道。

## 功能边界

广告拦截、隐藏元素、阅读模式、画中画和密码管理均为内置功能，无需另装扩展。扩展用于补充其他需求。

- 不提供账号、云同步或浏览数据云存储。标签页、历史记录和密码保留在本机。
- 不收集遥测、使用分析或向服务器发送崩溃报告。网络访问主要来自网页、网站图标、扩展下载及更新检查。
- 界面语言设置只影响浏览器自身。网页内容、书签名称及第三方扩展的界面保持原有内容。

## 隐私与数据存储

| 数据 | 存储位置 | 访问方式 |
|---|---|---|
| 密码 | macOS 登录钥匙串，沿用 `Search` 标记保存，兼容旧版数据 | 由 macOS 钥匙串控制访问。不同签名的应用访问时可能需要系统授权。 |
| 历史记录、书签、标签页和隐藏元素 | `~/Library/Application Support/Search/` 中的 JSON 文件 | 本机用户。 |
| Cookie 与网站数据 | WebKit 为应用管理的数据存储 | 对应网站，遵循浏览器权限和隔离规则。 |
| 扩展 | `~/Library/Application Support/Search/Extensions/`；扩展数据位于 WebKit 的扩展存储中 | 扩展按安装时授予的权限访问。 |

**无痕标签页**（`⇧⌘N`）使用独立的 Cookie 存储，关闭后不保留该会话的浏览数据。

在“系统设置 → 隐私与安全性 → 自动化”中获准访问的应用，可以通过 AppleScript 读取普通标签页的网址和标题；无痕标签页不会列出。

## 常用快捷键

在 **设置 → 标签页** 中可启用“紧凑书签栏”，缩小书签、图标与文字的间距。“书签栏打开方式”可选择“默认”（当前标签页）、“新建后台标签页”或“新建前台标签页”，也适用于书签栏文件夹中的书签。设置立即生效并保存在本机；中键点击仍在后台新建标签页，按住 Shift 中键点击则切换到新标签页。

| 操作 | 快捷键 |
|---|---|
| 输入网址、搜索词 | `⌘L` |
| 查找已打开的标签页 | `⌘K` |
| 新建窗口 / 新建标签页 | `⌘N` / `⌘T` |
| 新建无痕标签页 | `⇧⌘N` |
| 关闭标签页 / 恢复关闭的标签页或窗口 | `⌘W` / `⇧⌘T` |
| 后退 / 前进 | `⌘[` / `⌘]` |
| 上一个 / 下一个标签页 | `⇧⌘[` / `⇧⌘]` |
| 跳转到指定标签页 | `⌘1`–`⌘9` |
| 切换顶部标签栏与侧边栏 | `⇧⌘S` |
| 收起侧边栏 | `⌘S` |
| 为当前页面添加书签 | `⇧⌘B` |
| 阅读模式 / 画中画 | `⇧⌘R` / `⇧⌘P` |
| 隐藏元素 / 查看当前网站的隐藏规则 | `⇧⌘H` / `⇧⌘U` |
| 页面内查找 / 复制标签页 | `⌘F` / `⌘D` |
| 复制地址 / 粘贴并打开 | `⇧⌘C` / `⇧⌘V` |
| 历史记录 / 下载面板 | `⌘Y` / `⇧⌘J` |
| 设置 / 密码面板 | `⌘,` / `⌥⌘L` |

`⌘R` 重新载入页面；`⌥⌘R` 从源站重新载入，重新检查网站缓存。

`⌃Tab` 和 `⌃⇧Tab` 切换标签页；`Tab` 保留给网页表单中的焦点切换。`Esc` 关闭当前面板或弹层。

启用分屏后，`⌥⌘N` 拆分当前页面，`⌃⌘←` / `⌃⌘→` 切换操作焦点。`⌘W` 关闭获得焦点的标签页，另一侧页面恢复占满区域。“标签页 → 分离分屏标签页”将两侧页面保留为独立标签页。

---

## 开发说明

### Windows 版本

仓库的 `Windows/` 目录包含使用 C#、WinUI 3 与 WebView2 重建的 Windows x64 版本，最低支持 Windows 10 1809。功能、平台差异、构建与测试方法见 [Windows 开发说明](Windows/README.md)。

### 源码与上游

上游项目为 [driceroland/Search](https://github.com/driceroland/Search)。本仓库在其基础上维护中文支持、语言切换及 GitHub Actions 发布流程。

界面使用 Swift 编写，主要依赖 macOS 自带框架。源码可用于检查浏览器如何处理密码和历史记录，也可以自行编译或提交修改。

### 本地构建

需要 macOS、Swift 6 工具链及对应的 macOS SDK。建议使用完整 Xcode；运行 XCTest 测试需要其中的测试框架。

```bash
# 获取本仓库
git clone https://github.com/small32/SearcheXtra.git
cd SearcheXtra

# 编译 SwiftPM 可执行程序
swift build

# 编译并组装可双击运行的应用
./build.sh

# 明确构建 ARM64 版本
SEARCH_ARCH=arm64 ./build.sh release
```

应用生成在 `build/SearcheXtra.app`。没有 Developer ID 证书时使用临时签名，构建不会自动获得 Apple 公证。当前 GitHub Release 也采用临时签名，首次打开可能需要在 Finder 中右键选择“打开”，或在“系统设置 → 隐私与安全性”中允许打开。

自行构建的应用与上游正式签名版本使用不同签名，访问已有钥匙串项目时由 macOS 决定是否需要授权。

`./build.sh release dmg` 额外生成 `SearcheXtra.dmg` 和 `SearcheXtra.zip`；`./build.sh release ship` 还会提交公证并附加公证票据，需要 Developer ID 证书及 Apple 公证凭据。

### GitHub Actions 发布

将版本写入 `VERSION`，提交后推送对应的 `v版本号` 标签，即可触发 `ARM64 Release` 工作流。也可以在 Actions 页面手动指定标签构建。

工作流检查标签与版本是否一致，构建 ARM64 应用，验证架构、版本号和签名，然后发布 ZIP 安装包与 `SHA256SUMS.txt`。

`Bilingual interface checks` 工作流负责语言选择、英文回退、动态文案格式、双语资源打包及 ARM64 构建检查。

### 界面翻译

- `Sources/SearcheXtra/Resources/Translations.json` 保存英文和简体中文文案，每个翻译键同时提供 `en` 和 `zh-Hans`。
- `Sources/SearcheXtra/Localization.swift` 处理语言选择、文案读取、英文回退及动态内容替换。
- `Localization/en.lproj/InfoPlist.strings` 与 `Localization/zh-Hans.lproj/InfoPlist.strings` 保存系统权限说明。
- 存储键、协议标识、网址、快捷键 ID 和用户输入保持原值。

维护方式见 [界面语言维护说明](docs/LOCALIZATION.md)。

### 实现结构

- **SwiftUI** 绘制界面，**AppKit** 处理窗口标题栏、拖动等 macOS 原生交互，**WKWebView** 显示网页。
- 每个页面对应一个 `Tab`。恢复标签页时延迟创建网页视图，切换到对应标签页后才占用网页进程。网页运行在 WebKit 的内容进程中。
- 广告拦截规则编译为 `WKContentRuleList`，在 WebKit 网络请求阶段执行。
- 隐藏元素按网站保存为选择器，在文档开始加载时注入样式表，避免元素先出现再消失。
- `Design.swift` 集中管理浅色与深色配色，由窗口外观决定实际颜色。
- 扩展基于 `WKWebExtension`（macOS 15.4+）。`Crx.swift` 下载扩展并在解包前校验 CRX3 签名与扩展 ID；`Extensions.swift` 管理标签页、权限和弹出窗口；`ExtensionShims.swift` 补充 WebKit 缺少的部分 Chrome API，并处理两者之间的行为差异。扩展页面使用 `chrome-extension://<id>/` 地址。`ExtensionNative.swift` 支持 Chrome 原生消息通信，可连接 Chrome 的 `NativeMessagingHosts` 目录中注册的宿主。
- `Sources/SearcheXtra/` 按功能组织文件，例如 `Vault.swift` 管理钥匙串，`Shield.swift` 处理广告拦截，`Curtain.swift` 管理隐藏元素，`Session.swift` 恢复会话，`Updater.swift` 处理更新，`Bench.swift` 提供测试接口。

### 在独立测试会话中验证

开启 **设置 → 通用 → 允许脚本控制 SearcheXtra** 后，应用会在自己的数据目录中监听 Unix 套接字，仅当前用户可访问。仓库根目录的 `./bench` 用于发送测试指令：

```bash
./bench open https://example.com     # 新建带烧瓶标记的测试标签页
./bench wait 2e7e7e89                # 等待页面加载完成
./bench text 2e7e7e89                # 获取页面文本
./bench shot 2e7e7e89 out.png        # 保存页面截图
./bench click 2e7e7e89 "button.go"   # 通过网页事件点击元素
./bench probe                       # 查看窗口、面板和弹窗状态
./bench close all                   # 关闭测试标签页
```

测试标签页不会自动成为当前标签页，不写入会话或历史记录，由脚本关闭。`./bench ext-*` 用于扩展相关测试。

完成 `./build.sh` 后，可以运行 `python3 Tests/split_view.py`。它在隐藏的独立测试会话中检查分屏模型，使用单独的设置和文件，并在结束后清理。拖动到页面边缘、分隔线反馈及动画等视觉交互需要手动检查。

### 参与维护

问题反馈和修改建议请提交至 [本仓库 Issues](https://github.com/small32/SearcheXtra/issues) 或 Pull Request。修改应尽量保持范围明确，减少新增依赖，延续本地存储和保护隐私的设计。

上游贡献说明见 [CONTRIBUTING.md](CONTRIBUTING.md)，安全报告说明见 [SECURITY.md](SECURITY.md)。这两份文件保留上游的维护流程和联系方式；上游自身的安全问题可按其中说明报告。

### 许可证与归属

项目采用 **MIT 许可证**，详见 [LICENSE](LICENSE)。修改和分发时保留原有版权及许可声明。

Search 的原始代码和名称来自 Office Commun。本仓库以 SearcheXtra 名称维护修改版，使用新的应用图标，并提供中文支持和语言切换。
