import SwiftUI

// What's new, once, after an update.
//
// New features start off, so someone who never opens Settings never meets
// them (a reply on X). The first time a newer version opens, a small card
// shows its new switches, each with a line of what it does and the switch
// itself, and — so nothing gets lost — the switches from earlier versions
// that are still off. Nothing else: few words (Drice). Closed, it
// doesn't come back for that version. Not after a fresh install: the welcome
// is for that. Every version's notes are in Settings › About › What's New…
//
// A release edits `toggles` (its new switches, marked with its version),
// `releases` (that it has a card) and `notes` (what it brought).

enum WhatsNew {
    /// A switch the card offers: the same setting as in Settings.
    struct Toggle {
        let title: String
        let detail: String
        /// The version it came in.
        let since: String
        let get: @MainActor (Preferences) -> Bool
        let set: @MainActor (Preferences, Bool) -> Void
    }

    /// A version that has a card.
    struct Release {
        let version: String
    }

    /// Every switch worth meeting, oldest last. The card shows this
    /// version's, and the older ones still off.
    static let toggles: [Toggle] = [
        Toggle(title: "网页 AI", detail: "总结网页或针对网页提问。在“设置 › AI”中选择运行位置。",
               since: "1.0.5", get: { $0.ai }, set: { $0.ai = $1 }),
        Toggle(title: "分屏浏览", detail: "并排显示两个标签页：拖动标签页到页面边缘，或按 ⌥⌘N。",
               since: "1.0.5", get: { $0.splitView }, set: { $0.splitView = $1 }),
        Toggle(title: "在地址栏搜索网站", detail: "输入网站名称的开头再按 Tab，例如输入 red、按 Tab 后即可在 Reddit 搜索。",
               since: "1.0.5", get: { $0.searchesSites }, set: { $0.searchesSites = $1 }),
        Toggle(title: "启动时打开全新窗口", detail: "保留固定标签页，不恢复上次的其他标签页。",
               since: "1.0.5", get: { $0.startsFresh }, set: { $0.startsFresh = $1 }),

        Toggle(title: "标签页分组", detail: "为标签页创建命名分组，右键点击标签页即可开始。",
               since: "1.0.4", get: { $0.usesTabGroups }, set: { $0.usesTabGroups = $1 }),
        Toggle(title: "右侧侧边栏", detail: "在窗口右侧竖排显示标签页。",
               since: "1.0.4", get: { $0.sidebar && $0.sidePosition == .right },
               set: { prefs, on in
                   if on { prefs.sidebar = true }
                   prefs.sidePosition = on ? .right : .left
               }),
        Toggle(title: "点击后才播放视频", detail: "视频不会自动播放，即使已静音。",
               since: "1.0.4", get: { $0.waitsForPlay }, set: { $0.waitsForPlay = $1 }),
        Toggle(title: "始终显示下载按钮", detail: "在其他按钮旁显示下载按钮，一键查看下载。",
               since: "1.0.4", get: { $0.alwaysShowsDownloads }, set: { $0.alwaysShowsDownloads = $1 }),

        Toggle(title: "空间", detail: "使用独立的标签页和登录状态，按 ⌃1–⌃9 切换。",
               since: "1.0.1", get: { $0.usesSpaces }, set: { $0.usesSpaces = $1 }),
        Toggle(title: "自动隐藏侧边栏", detail: "页面占满窗口，将指针移至边缘即可显示标签页。",
               since: "1.0.1", get: { $0.sidebar && $0.sideHides },
               set: { prefs, on in
                   if on { prefs.sidebar = true }
                   prefs.sideHides = on
               }),
        Toggle(title: "书签栏", detail: "在页面上方显示书签栏。",
               since: "1.0.2", get: { $0.bookmarksBar }, set: { $0.bookmarksBar = $1 }),
        Toggle(title: "切换应用时自动开启画中画", detail: "切换应用时，正在播放的视频会进入画中画窗口。",
               since: "1.0.2", get: { $0.floatsAway }, set: { $0.floatsAway = $1 }),
        Toggle(title: "以 120 Hz 刷新页面", detail: "在支持的屏幕上获得更流畅的滚动和动画，但会增加耗电。",
               since: "1.0.2", get: { $0.fastPages }, set: { $0.fastPages = $1 }),
        Toggle(title: "使用鼠标中键滚动", detail: "单击滚轮后移动鼠标即可滚动，操作与 Windows 类似。",
               since: "1.0.3", get: { $0.autoScroll }, set: { $0.autoScroll = $1 }),
    ]

    static let releases: [Release] = [
        Release(version: "1.0.4"),
    ]

    /// This version's card, when it has one.
    static var current: Release? { releases.first { $0.version == Updater.version } }

    /// Version strings in order: 1.0.10 after 1.0.9.
    static func older(_ one: String, than other: String) -> Bool {
        let a = one.split(separator: ".").compactMap { Int($0) }
        let b = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    private static let seenKey = "whatsnew.seen"

    /// At launch, once: whether the card is due. Not on a fresh install (the
    /// welcome is up, and this version counts as seen), nor in a test world
    /// unless the bench asks; otherwise once per version that has a card.
    @MainActor static func due(prefs: Preferences, welcoming: Bool) -> Bool {
        let store = Store.settings
        guard let current, !Store.testing else { return false }
        if welcoming {
            store.set(current.version, forKey: seenKey)
            return false
        }
        guard store.string(forKey: seenKey) != current.version else { return false }
        store.set(current.version, forKey: seenKey)
        return true
    }

    // MARK: - every version's notes

    /// What a version brought, for Settings › About › What's New…
    struct Notes {
        let version: String
        let date: String
        /// A sentence or two: what the version is about.
        let headline: String
        let new: [String]
        let better: [String]
        let fixed: [String]
    }

    /// Newest first.
    static let notes: [Notes] = [
        Notes(
            version: "1.0.4", date: "2026 年 9 月 27 日",
            headline: "支持多窗口并新增多项功能。多数新功能默认关闭，可通过更新后的提示卡启用。",
            new: [
                "支持多窗口。⌘N 打开独立窗口；将标签页拖出标签栏，或在菜单中选择“移至窗口”，即可连同页面一起移动。所有窗口共享固定标签页。",
                "新增标签页分组和右侧侧边栏。",
                "⌃Tab 以缩略图显示最近使用的标签页，最近使用的排在前面；快速按 ⌃Tab 可返回上一个标签页。",
                "可在“设置 › 快捷键”中自定义快捷键。",
                "下载时在按钮旁显示圆形进度，访达和程序坞也会显示进度。下载按钮可设置为始终显示。",
                "支持从 Firefox、Zen、Helium、Comet、Opera、Chrome 的其他版本及 Arc 导入数据，包括 Arc 的空间和固定标签页，也可导入已导出的文件。",
                "网站搜索快捷词：在搜索前加上自定义词即可搜索指定网站，例如用 yt cats 搜索 YouTube。",
                "支持书签排序、自建文件夹，添加书签时可在卡片中命名。",
                "视频可设置为点击后播放，网站可使用自定义的默认缩放比例。",
                "双击固定标签页可返回最初固定的页面。",
                "向后或向前滑动后按住，可从历史记录中选择页面。",
            ],
            better: [
                "降低滚动时的窗口开销，正在加载的标签页也不再让 Mac 持续忙碌。",
                "默认开启链接地址显示、Shift 单击预览链接和滑动画中画窗口贴边。",
                "标签页管理器等扩展可查看所有窗口中的标签页。",
                "支持“窗口 › 移动与调整大小”和 Mac 的窗口平铺功能。",
                "无论当前页面是什么，⌘K 都会打开标签页列表。",
            ],
            fixed: [
                "恢复 ⌘← 和 ⌘→ 后退、前进功能。",
                "从 Notion 等应用打开链接时，Search 会切换到前台。",
                "支持打开开发服务器输出的地址，如 0.0.0.0:3000。",
                "重启后恢复退出时的标签页。",
                "修复用 ⌘S 收起标签栏后，× 按钮关闭标签页的问题。",
                "修复 1Password、Bitwarden、NordPass、Passbolt、iCloud 密码和 Claude 扩展的相关问题。",
                "以及多项细节修复。",
            ]
        ),
        Notes(
            version: "1.0.3", date: "2026 年 9 月 24 日",
            headline: "安全性和鼠标滚轮改进。",
            new: [
                "复制已保存密码时要求触控 ID 验证。",
            ],
            better: [
                "恢复 x.com 等页面上的流畅滚轮滚动。",
                "加快历史记录面板的打开速度。",
                "切换空间时音乐继续播放。",
                "弹出窗口需要用户点击才能打开。",
            ],
            fixed: [
                "修复本周审查发现的漏洞：扩展可读取自身目录以外的文件，网页或广告可未经确认打开其他应用。",
                "支持 Bitwarden 登录自托管服务器，扩展弹出窗口可在打开期间接收状态变化。",
                "邮件中的链接会让 Search 切换到前台，修复全屏视频黑屏问题。",
                "扩展下次更新时，可能会再次请求权限确认。",
            ]
        ),
        Notes(
            version: "1.0.2", date: "2026 年 9 月 24 日",
            headline: "通行密钥、密码管理器及 Google 兼容性改进。",
            new: [
                "网站的通行密钥按钮可调起 Mac 的系统面板，支持触控 ID、iPhone 和安全密钥。",
                "Search 可设为 Mac 的默认浏览器。",
                "新增书签栏、Shift 单击预览链接、切换应用时自动画中画、120 Hz 页面刷新和链接地址显示，可在设置中开启。",
                "支持标签页静音、共享页面、复制 Markdown 链接、鼠标前进后退按钮，以及在顶部标签栏中显示空间。",
            ],
            better: [
                "加快启动速度，新建标签页约需 10 毫秒。",
                "网页能读取的浏览器信息与 Safari 保持一致，已保存密码仅在对应网站上提供。",
            ],
            fixed: [
                "改进 1Password、Bitwarden 和 Proton Pass 的兼容性。",
                "更新后若通行密钥仍无法使用，请重启 Mac。",
            ]
        ),
        Notes(
            version: "1.0.1", date: "2026 年 9 月 23 日",
            headline: "首次更新，根据一天内收到的反馈和拉取请求改进。",
            new: [
                "新增空间、指针移至边缘才显示的侧边栏和自选搜索引擎，可在设置中启用。",
                "⌘S 可收起侧边栏，中键可关闭标签页，支持重命名标签页，并在“显示”菜单中加入网页检查器。",
            ],
            better: [],
            fixed: [
                "恢复 macOS 14 上的启动支持。",
                "修复安装 iCloud 密码扩展后，登录 Google 时页面反复重载的问题。",
                "修复不同键盘布局下的 ⌘1–⌘9、表单 Tab 切换、拖动标签页、双击顶部填满屏幕，以及输入时的系统提示音问题。",
            ]
        ),
        Notes(
            version: "1.0", date: "2026 年 9 月 23 日",
            headline: "首个版本。为 Mac 打造的简洁浏览器。",
            new: [
                "标签页可横排或竖排，固定标签页保留位置，一个输入框同时用于网址和搜索。",
                "加载前拦截广告，密码和通行密钥保存在钥匙串中。",
                "可隐藏网页元素，文章支持阅读模式，视频支持画中画。",
                "在 macOS 15.4 或更新版本上支持 Chrome 应用商店扩展。",
                "半小时未查看的标签页会休眠并释放内存。",
                "使用 macOS 内置引擎，体积仅 2.9 MB。",
            ],
            better: [],
            fixed: []
        ),
    ]
}

/// The card: what's new in this version, its switches right there, and
/// the earlier ones still off.
struct WhatsNewCard: View {
    let release: WhatsNew.Release
    @ObservedObject var prefs: Preferences
    let close: () -> Void
    let notes: () -> Void

    /// Read once, as the card opens: a switch turned on here stays in the
    /// list rather than vanishing under the hand.
    @State private var earlier: [WhatsNew.Toggle]?

    private var fresh: [WhatsNew.Toggle] { WhatsNew.toggles.filter { $0.since == release.version } }

    var body: some View {
        Plate("Search \(release.version) 的新功能", width: 460, close: close) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    rows(fresh)
                    if let earlier, !earlier.isEmpty {
                        Caption("此前版本的功能")
                            .padding(.top, 6)
                        rows(earlier)
                    }
                }
            }
            .frame(maxHeight: 470)
            .fixedSize(horizontal: false, vertical: true)
        } foot: {
            HStack {
                Button(action: notes) {
                    Text("查看全部更新内容…")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                Spacer()
                Pill("关闭", filled: true, action: close)
            }
        }
        .onAppear {
            if earlier == nil {
                earlier = WhatsNew.toggles.filter { WhatsNew.older($0.since, than: release.version) && !$0.get(prefs) }
            }
        }
    }

    private func rows(_ toggles: [WhatsNew.Toggle]) -> some View {
        Card {
            ForEach(Array(toggles.enumerated()), id: \.offset) { index, toggle in
                if index > 0 { Rule() }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(toggle.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                        Text(toggle.detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Switch(on: Binding(get: { toggle.get(prefs) }, set: { toggle.set(prefs, $0) }))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }
}

/// Every version's notes, newest first: Settings › About › What's New…
struct ReleaseNotesPanel: View {
    let close: () -> Void

    var body: some View {
        Plate("更新内容", width: 560, close: close) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(WhatsNew.notes, id: \.version) { note in
                        version(note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(maxHeight: 480)
        }
    }

    private func version(_ note: WhatsNew.Notes) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Search \(note.version)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if !note.date.isEmpty {
                    Text(note.date)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                }
            }
            Text(note.headline)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            list("新增", note.new)
            list("改进", note.better)
            list("修复", note.fixed)
        }
    }

    @ViewBuilder
    private func list(_ title: String, _ lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.muted)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Palette.faint)
                        Text(line)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12.5))
                }
            }
        }
    }
}
