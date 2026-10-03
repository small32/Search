import SwiftUI

/// Everything there is to set. Pages down the left, one page at a time on
/// the right, each a short list of lines with a hairline between them —
/// nothing to scroll through, nothing to hunt for. The same white and
/// hairline as the rest of the app; the same pill for the page you are on
/// as for the tab you are on.
struct SettingsPanel: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    @ObservedObject private var updater = Updater.shared
    @ObservedObject private var shield = Shield.shared
    @State private var isDefault = Links.isDefault
    /// A site shortcut being written, kept out of Preferences until it's saved.
    @State private var draft: Keyword?
    @State private var page: Page = Page(rawValue: Store.settings.string(forKey: "settings.page") ?? "") ?? .general

    enum Page: String, CaseIterable, Identifiable {
        case general, tabs, shortcuts, extensions, passwords, downloads, privacy, ai, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "通用"
            case .tabs: return "标签页"
            case .shortcuts: return "快捷键"
            case .extensions: return "扩展"
            case .passwords: return "密码"
            case .downloads: return "下载"
            case .privacy: return "隐私"
            case .ai: return "AI"
            case .about: return "关于"
            }
        }
        var icon: String {
            switch self {
            case .general: return "macwindow"
            case .tabs: return "rectangle.split.3x1"
            case .shortcuts: return "keyboard"
            case .extensions: return "puzzlepiece.extension"
            case .passwords: return "key"
            case .downloads: return "arrow.down.circle"
            case .privacy: return "hand.raised"
            case .ai: return "sparkles"
            case .about: return "info.circle"
            }
        }
    }

    private static let rail: CGFloat = 168
    private static let width: CGFloat = 660
    private static let height: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            pages
            Rectangle().fill(Palette.hairline).frame(width: 1)
            content
        }
        .frame(width: SettingsPanel.width, height: SettingsPanel.height)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 34, y: 12)
        .onChange(of: page) { _, page in Store.settings.set(page.rawValue, forKey: "settings.page") }
    }

    // MARK: - the rail

    private var pages: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 12)
            ForEach(Page.allCases) { item in
                PageRow(page: item, on: page == item) { page = item }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: SettingsPanel.rail, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.wash.opacity(0.45), in: Rectangle())
    }

    private struct PageRow: View {
        let page: Page
        let on: Bool
        let act: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: act) {
                HStack(spacing: 9) {
                    Image(systemName: page.icon)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 16)
                    Text(page.title)
                        .font(.system(size: 13, weight: on ? .medium : .regular))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(on ? Palette.ink : (hovering ? Palette.ink.opacity(0.75) : Palette.muted))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Palette.ground : (hovering ? Palette.hover : .clear))
                        .shadow(color: .black.opacity(on ? 0.06 : 0), radius: 3, y: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }

    // MARK: - the page

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(page.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Door(icon: "xmark", help: "完成   esc") { browser.tuning = false }
            }
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    switch page {
                    case .general: general
                    case .tabs:
                        tabs
                        if !prefs.sidebar { toolbar }
                    case .shortcuts: ShortcutsPage(browser: browser, store: .shared)
                    case .extensions: ExtensionsPage(browser: browser)
                    case .passwords: passwords
                    case .downloads: downloads
                    case .privacy: privacy
                    case .ai: AISettings(browser: browser, prefs: prefs)
                    case .about: about
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - general

    private var general: some View {
        Card {
            Line(
                "打开其他应用中的链接",
                isDefault ? "Search 已是此 Mac 的默认浏览器" : "邮件、Slack 等应用的链接仍在其他浏览器中打开"
            ) {
                if isDefault {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 24)
                } else {
                    Pill("设为默认", filled: true) {
                        Links.becomeDefault { worked in
                            isDefault = Links.isDefault
                            browser.announce(worked && isDefault ? "链接现在会在 Search 中打开" : "macOS 未更改默认浏览器")
                        }
                    }
                }
            }
            Rule()
            // Coming from another browser, now or any time later: the same
            // sheet as File › Bring Things Over… and the Welcome's.
            Line("导入浏览器数据", "从此 Mac 上的其他浏览器或其导出的文件中导入书签、历史记录、密码和扩展") {
                Pill("导入浏览器数据…") {
                    browser.tuning = false
                    browser.bringingIn = ""
                }
            }
            Rule()
            Line("搜索引擎", searchDetail) {
                Picker("", selection: $prefs.engine) {
                    ForEach(Engine.allCases) { engine in
                        Text(engine.title).tag(engine)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            if prefs.engine == .custom {
                ZStack(alignment: .leading) {
                    if prefs.customEngine.isEmpty {
                        Text("https://example.com/search?q=%s")
                            .foregroundStyle(Palette.muted.opacity(0.8))
                    }
                    TextField("", text: $prefs.customEngine)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                }
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 11)
            }
            Rule()
            Line("网站搜索快捷词", keywordDetail) {
                if draft == nil {
                    Pill("添加") { draft = Keyword() }
                } else {
                    HStack(spacing: 6) {
                        Pill("取消") { draft = nil }
                        Pill("保存", filled: true) { saveDraft() }
                            .disabled(draftProblem != nil)
                            .opacity(draftProblem == nil ? 1 : 0.4)
                    }
                }
            }
            if let current = draft {
                HStack(spacing: 8) {
                    TextField("yt", text: Binding(
                        get: { current.keyword },
                        set: { draft?.keyword = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .frame(width: 50)
                    Text("→").foregroundStyle(Palette.muted)
                    TextField("https://www.youtube.com/results?search_query=%s", text: Binding(
                        get: { current.template },
                        set: { draft?.template = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .onSubmit(saveDraft)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            ForEach(prefs.keywords) { entry in
                HStack(spacing: 8) {
                    Text(entry.keyword)
                        .frame(width: 50, alignment: .leading)
                    Text("→").foregroundStyle(Palette.muted)
                    Text(entry.template)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        prefs.keywords.removeAll { $0.id == entry.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.faint)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            Rule()
            Line("外观", "选择浅色、深色或跟随系统，网页也会采用相同外观") {
                Segmented(options: Look.allCases.map { ($0, $0.title) }, selection: $prefs.look)
            }
            Rule()
            Line("页面缩放", "网站的默认缩放比例。通过 ⌘+ 和 ⌘− 设置的比例仍会按网站单独保存。") {
                // The number itself takes it back to 100%.
                Steps(stops: Preferences.zooms, value: $prefs.pageZoom, home: 1) { "\(Int(($0 * 100).rounded()))%" }
            }
            Rule()
            Line("输入时自动纠正拼写", "在网页中使用 macOS 的自动纠正功能，包括自动大写") {
                Switch(on: $prefs.autocorrect)
            }
            Rule()
            Line("按住 Shift 单击预览链接", "在当前页面上方打开预览面板。按 Esc 关闭，也可将预览保留为标签页") {
                Switch(on: $prefs.peeksLinks)
            }
            Rule()
            Line("在小窗口中打开其他应用的链接", "阅读后关闭，或选择“在 Search 中打开”（⌘O）保留页面") {
                Switch(on: $prefs.littleLinks)
            }
            Rule()
            Line("地址栏命令", "在地址栏单独输入“设置”或“新建标签页”等命令即可执行") {
                Switch(on: $prefs.commandBar)
            }
            Rule()
            Line("显示链接地址", "将指针移到链接上时，在页面底部显示目标地址") {
                Switch(on: $prefs.showsLinks)
            }
            Rule()
            Line("使用鼠标中键滚动", "在页面中单击滚轮，再上下移动鼠标即可滚动。再次单击停止") {
                Switch(on: $prefs.autoScroll)
            }
            Rule()
            Line("以 120 Hz 刷新页面", "在支持的屏幕上，网页动画和滚动最高可达每秒 120 帧，会增加耗电。已打开的标签页重新载入后生效") {
                Switch(on: $prefs.fastPages)
            }
            Rule()
            Line("滑动后按住以选择历史页面", "向后或向前滑动后保持手指按住，显示该方向的历史页面；上下移动选择要打开的页面") {
                Switch(on: $prefs.holdsHistory)
            }
            Rule()
            Line("滑动画中画窗口使其贴边", "在画中画窗口上用双指滑动，可将其移至对应的屏幕边缘或角落。向贴近的边缘快速滑动可收起窗口，点击露出的边缘可恢复。仍可自由拖动") {
                Switch(on: $prefs.floatFlicks)
            }
            Rule()
            Line("点击后才播放视频", "视频不会自动播放，即使已静音。点击播放才开始。已打开的标签页关闭重开或休眠后生效") {
                Switch(on: $prefs.waitsForPlay)
            }
            Rule()
            Line("切换标签页时自动开启画中画", "切换标签页时，YouTube 等网站正在播放的视频会进入画中画；返回时恢复。也可按 ⇧⌘P 手动开启") {
                Switch(on: $prefs.floatsOnLeave)
            }
            Rule()
            Line("切换应用时自动开启画中画", "切换到其他应用时，当前网站正在播放的视频会进入画中画；返回时恢复到标签页") {
                Switch(on: $prefs.floatsAway)
            }
            Rule()
            Line("允许脚本控制 Search", "启用用于测试的本地套接字。脚本标签页带有烧瓶图标，与普通标签页并列显示。详见 ./bench") {
                Switch(on: $prefs.bench)
            }
        }
    }

    /// Checked when it's saved, not as it's typed into the list: a shortcut
    /// only exists once its address is one it's safe to send words to.
    private var draftProblem: String? {
        guard let draft else { return nil }
        return Keyword.problem(word: draft.keyword, template: draft.template, among: prefs.keywords)
    }

    private var keywordDetail: String {
        guard let draft else {
            return "在搜索词前加上快捷词即可搜索指定网站，例如“yt cats”会在 YouTube 搜索"
        }
        if draft.keyword.isEmpty, draft.template.isEmpty {
            return "输入快捷词及网站搜索地址，用 %s 表示搜索词的位置"
        }
        return draftProblem ?? "\(draft.keyword.trimmingCharacters(in: .whitespacesAndNewlines)) 将在 \(draft.name) 搜索"
    }

    private func saveDraft() {
        guard let current = draft, draftProblem == nil else { return }
        prefs.keywords.append(Keyword(
            keyword: current.keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            template: current.template.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        draft = nil
    }

    private var searchDetail: String {
        guard prefs.engine == .custom else { return "非网址的内容会通过此引擎搜索" }
        guard Engine.accepts(prefs.customEngine) else {
            return "请输入含 %s 的 HTTP 或 HTTPS 搜索地址。设置有效前使用 Google"
        }
        return "搜索词将发送至 \(prefs.engine.name(custom: prefs.customEngine))"
    }

    // MARK: - tabs

    /// Where back, forward and reload sit with the tabs across the top. With
    /// the sidebar they are already beside the window's buttons: nothing to
    /// move, and the line isn't shown.
    private var toolbar: some View {
        Card {
            Line("在左侧显示后退、前进和重新载入按钮", "位于窗口按钮旁、标签页之前") {
                Switch(on: $prefs.navigationLeft)
            }
        }
    }

    private var tabs: some View {
        Card {
            Line("在侧边栏显示标签页", "在\(prefs.sidePosition.title)竖排显示标签页。拖动边缘调整宽度，双击边缘恢复默认。") {
                Switch(on: Binding(
                    get: { prefs.sidebar },
                    set: { on in withAnimation(Motion.glide) { prefs.sidebar = on } }
                ))
            }
            if prefs.sidebar {
                Rule()
                Line("侧边栏位置", "标签页显示在窗口\(prefs.sidePosition.title)") {
                    Segmented(options: SidebarPosition.allCases.map { ($0, $0.title) }, selection: $prefs.sidePosition)
                }
                Rule()
                Line("指针移至边缘时才显示侧边栏", "页面占满窗口；将指针移至\(prefs.sidePosition.title)边缘显示标签页。按 ⌘S 保持侧边栏展开。") {
                    Switch(on: $prefs.sideHides)
                }
            }
            Rule()
            Line("标签页显示", "用于标题旁的图标和固定标签页方块") {
                Segmented(options: Glyph.allCases.map { ($0, $0.title) }, selection: $prefs.glyph)
            }
            Rule()
            Line("显示书签栏", "在页面上方显示书签，文件夹以菜单展开。书签栏会随标签栏一起收起") {
                Switch(on: $prefs.bookmarksBar)
            }
            Rule()
            Line("显示阅读进度", "向下滚动时，当前标签页逐渐填充灰色以显示进度") {
                Switch(on: $prefs.showsReading)
            }
            Rule()
            Line("休眠闲置标签页", "闲置半小时后休眠，再次打开时恢复原位置。固定标签页、音频、通话和有输入内容的页面保持活跃。") {
                Switch(on: $prefs.sleepsTabs)
            }
            Rule()
            Line("切换到后台标签页时才加载", "通过 ⌘ 单击、鼠标中键或其他应用批量打开的后台链接，会等到切换到对应标签页时才加载。⇧⌘ 单击仍会立即打开。") {
                Switch(on: $prefs.lazyTabs)
            }
            Rule()
            Line("在地址栏搜索网站", "输入网站名称的开头，如 red 或 yout，再按 Tab，即可在该网站搜索。访问过且支持搜索的网站会加入列表。") {
                Switch(on: $prefs.searchesSites)
            }
            Rule()
            Line("启动时打开全新窗口", "每次启动 Search 时保留固定标签页，不恢复上次的其他标签页。") {
                Switch(on: $prefs.startsFresh)
            }
            Rule()
            Line("空间", "将标签页分为不同空间，可共享登录状态或独立登录。用 ⌃1–⌃9、在侧边栏双指横向滑动或点击空间图标切换。若启用了调度中心的同名快捷键，系统会优先处理。") {
                Switch(on: $prefs.usesSpaces)
            }
            Rule()
            Line("标签页分组", "在侧边栏中按名称分组。右键点击标签页创建分组，点击组标题展开或收起。") {
                Switch(on: $prefs.usesTabGroups)
            }
            if prefs.sidebar {
                Rule()
                Line("以列表显示固定标签页", "类似 Arc：常用网站固定为方块，保留页面固定为下方列表，其余标签页上方显示“清除”。右键点击标签页可将其固定为列表项。") {
                    Switch(on: $prefs.listsPins)
                }
            }
            Rule()
            Line("分屏浏览", "并排显示两个标签页。将标签页拖到页面上即可组合。") {
                Switch(on: $prefs.splitView)
            }
        }
    }

    // MARK: - passwords

    /// Says so when a password manager extension has taken the saving over.
    private var savingDetail: String {
        if #available(macOS 15.4, *), let name = Extensions.shared.passwordSavingTakenBy {
            return "\(name) 正在管理密码，已要求 Search 停止询问保存"
        }
        return "每个网站询问一次；拒绝后不再询问"
    }

    private var passwords: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card {
                Line("已保存的密码", "保存在 macOS 钥匙串中，通过触控 ID 查看") {
                    Pill("打开…") {
                        browser.tuning = false
                        browser.managing = true
                    }
                }
                Rule()
                Line("询问是否保存密码", savingDetail) {
                    Switch(on: $prefs.savesPasswords)
                }
                Rule()
                Line("自动填充登录信息", "点击登录输入框时，显示此网站已保存的账户") {
                    Switch(on: $prefs.fillsPasswords)
                }
                Rule()
                Line(
                    "启用通行密钥",
                    !prefs.passkeysPossible
                        ? "当前构建缺少 Apple 所需的授权；关闭后网站仍使用密码登录"
                        : Passkeys.access == .denied
                        ? "macOS 已拒绝访问；可在“系统设置 › 隐私与安全性 › 网页浏览器的通行密钥访问”中更改"
                        : "在支持的网站上使用触控 ID 或 iCloud 通行密钥"
                ) {
                    Switch(on: $prefs.passkeys)
                }
                if !Vault.never.isEmpty {
                    Rule()
                    Line("不再询问的网站", "已在 \(Vault.never.count) 个网站上停止询问") {
                        Pill("清除") {
                            Vault.never = []
                            browser.announce("所有网站均可再次询问")
                        }
                    }
                }
            }
            Card {
                Line("导入密码", "从此 Mac 上的其他浏览器导入，数据不会离开本机") {
                    Pill("导入…") {
                        browser.tuning = false
                        browser.bringingIn = ""
                    }
                }
            }
        }
    }

    // MARK: - downloads

    private var downloads: some View {
        Card {
            Line("保存位置", prefs.downloads.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) {
                Pill("更改…") { chooseFolder() }
            }
            Rule()
            Line("每次下载时询问保存位置") {
                Switch(on: $prefs.asksWhereToSave)
            }
            Rule()
            Line("始终显示下载按钮", "没有正在下载的文件时也显示下载按钮。关闭后仅在下载过程中显示") {
                Switch(on: $prefs.alwaysShowsDownloads)
            }
        }
    }

    // MARK: - privacy

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card {
                Line("拦截广告和跟踪器", shield.trouble ?? "拦截用于跟踪浏览行为的第三方内容") {
                    Switch(on: $prefs.shielded)
                }
                if let trouble = shield.trouble {
                    Rule()
                    Line(trouble, "问题解决前不会拦截任何内容。请重试或重新启动 Search") {
                        Pill("重试") { shield.compile() }
                    }
                }
                if let host = browser.hereHost, prefs.shielded, shield.trouble == nil {
                    Rule()
                    Line("在 \(host) 上拦截", "若网站异常，可在此关闭拦截；页面会重新载入") {
                        Switch(on: Binding(
                            get: { !Shield.shared.isPaused(on: host) },
                            set: { on in
                                Shield.shared.pause(host, !on)
                                browser.reload()
                            }
                        ))
                    }
                }
                Rule()
                Line("阻止跨网站跟踪", "与 Safari 类似。关闭后，较少访问的网站会保留登录状态，第三方跟踪器也能跨网站跟踪。无痕标签页始终开启此功能") {
                    Switch(on: Binding(get: { !prefs.keepsSignIns }, set: { prefs.keepsSignIns = !$0 }))
                }
                Rule()
                Line("摄像头、麦克风、位置和通知", "各网站的允许或拒绝记录，以及禁用画中画的网站") {
                    Pill("清除权限记录") { browser.forgetCaptureChoices() }
                }
                Rule()
                Line("允许网站请求发送通知", "网站会在页面上方请求权限，只有获准的网站才能发送 Mac 通知。无痕标签页不会询问") {
                    Switch(on: $prefs.siteNotifications)
                }
                NotificationSites()
            }
            Card {
                Line("历史记录", "访问过的所有地址") {
                    Pill("清除") { browser.clearHistory() }
                }
                Rule()
                Line("Cookie 和登录状态", "退出所有网站的登录") {
                    Pill("退出所有网站") { browser.clearSites() }
                }
                Rule()
                Line("缓存", "仅用于显示页面的缓存内容") {
                    Pill("清除") { browser.clearCache() }
                }
            }
        }
    }

    // MARK: - about

    private var about: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Logomark()
                    .fill(Palette.ink, style: FillStyle(eoFill: true))
                    .aspectRatio(Logomark.canvas.width / Logomark.canvas.height, contentMode: .fit)
                    .frame(height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Search")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Office Commun 出品 · 版本 \(Updater.version)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.bottom, 2)

            Card {
                Line(versionTitle, versionDetail) { versionControl }
                Rule()
                Line("自动安装更新", "关闭后，Search 仍会每小时检查并通知更新，点击“安装”后才会安装") {
                    Switch(on: $prefs.installsUpdates)
                }
                Rule()
                Line("发现问题？", "打开已填写版本信息的反馈草稿") {
                    Pill("发送反馈") { Links.writeFeedback() }
                }
                Rule()
                Line("更新内容", "各版本更新说明，最新版本在前") {
                    Pill("更新内容…") { browser.notesShowing = true }
                }
            }

            Card {
                Shortcut("⌘L", "地址栏")
                Rule()
                Shortcut("⌘K", "切换标签页")
                Rule()
                Shortcut("⌘T  ⌘W  ⇧⌘T", "新建、关闭、重新打开标签页")
                Rule()
                Shortcut("⇧⌘V", "粘贴并前往")
                Rule()
                Shortcut("⇧⌘C", "复制地址")
                Rule()
                Shortcut("⌃⇥  ⌘1–9", "切换到下一个标签页，或按位置切换")
                Rule()
                Shortcut("⇧⌘S", "在侧边栏显示标签页")
                Rule()
                Shortcut("⌘S", "收起侧边栏")
                Rule()
                Shortcut("⇧⌘R", "阅读模式")
                Rule()
                Shortcut("⇧⌘H", "隐藏网站元素")
                Rule()
                Shortcut("⇧⌘P", "画中画")
                Rule()
                Shortcut("⇧⌘⌫", "清除浏览数据")
            }
        }
    }

    /// The version line follows the newer build from found to fetched to
    /// in place; with none, it is simply this one.
    private var versionTitle: String {
        switch updater.stage {
        case .none: return "更新"
        case .fetching(let next): return "正在下载 Search \(next.version)…"
        case .ready(let next): return "Search \(next.version) 已准备就绪"
        case .offered(let next), .waiting(let next): return "Search \(next.version) 已发布"
        }
    }

    private var versionDetail: String {
        switch updater.stage {
        case .none:
            return updater.lastChecked.map { "检查时间：\($0.formatted(.relative(presentation: .named)))；每小时自动检查" }
                ?? "每小时自动检查"
        case .fetching(let next):
            return WhatsNew.notes.first(where: { $0.version == next.version })?.headline ?? "在后台下载，不会更改已有设置"
        case .ready(let next):
            return WhatsNew.notes.first(where: { $0.version == next.version })?.headline ?? "下次启动 Search 时生效"
        case .offered(let next):
            return WhatsNew.notes.first(where: { $0.version == next.version })?.headline ?? "打开磁盘映像，按首次安装的方式安装"
        case .waiting(let next):
            return WhatsNew.notes.first(where: { $0.version == next.version })?.headline ?? "点击“安装”后校验并安装"
        }
    }

    @ViewBuilder
    private var versionControl: some View {
        switch updater.stage {
        case .none:
            Pill(updater.checking ? "正在检查…" : "立即检查") {
                updater.check { found in
                    if found == nil { browser.announce("已是最新版本") }
                }
            }
            .disabled(updater.checking)
        case .fetching:
            Ring(size: 12)
        case .ready:
            Pill("立即重新启动", filled: true) { updater.relaunch() }
        case .offered:
            Pill(updater.fetchingDisk ? "正在下载…" : "下载", filled: true) { updater.openDisk() }
                .disabled(updater.fetchingDisk)
        case .waiting:
            Pill("安装", filled: true) { updater.install() }
        }
    }

    // MARK: - doing

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.downloads
        panel.prompt = "使用此文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        prefs.downloads = url
    }

    // MARK: - pieces

    /// A keystroke and what it does.
    private struct Shortcut: View {
        let keys: String
        let does: String
        init(_ keys: String, _ does: String) { self.keys = keys; self.does = does }

        var body: some View {
            HStack {
                Text(does)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(keys)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }
}

/// A row of choices in a grey track, one of them lifted out in white. The
/// white slides to the one you pick rather than appearing there.
struct Segmented<Option: Hashable>: View {
    let options: [(Option, String)]
    @Binding var selection: Option
    /// True when the control has the whole width to itself, so the choices
    /// share it evenly instead of each taking only what its word needs.
    var wide = false

    @Namespace private var slide

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option, title in
                Text(title)
                    .font(.system(size: 11.5, weight: option == selection ? .medium : .regular))
                    .foregroundStyle(option == selection ? Palette.ink : Palette.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: !wide, vertical: false)
                    .frame(maxWidth: wide ? .infinity : nil)
                    .padding(.horizontal, wide ? 4 : 10)
                    .padding(.vertical, 5)
                    .background {
                        if option == selection {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Palette.ground)
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "chosen", in: slide)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .onTapGesture {
                        withAnimation(Motion.settle) { selection = option }
                    }
            }
        }
        .padding(2)
        .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .animation(Motion.settle, value: selection)
    }
}

/// On or off, in ink rather than in blue.
struct Switch: View {
    @Binding var on: Bool

    var body: some View {
        Capsule()
            .fill(on ? Palette.ink : Palette.faint)
            .frame(width: 30, height: 18)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle()
                    .fill(Palette.ground)
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .padding(2)
            }
            .contentShape(Capsule())
            .onTapGesture { withAnimation(Motion.settle) { on.toggle() } }
            .animation(Motion.settle, value: on)
    }
}

/// A value moved one stop at a time: − and + either side of it, in the same
/// outlined capsule as a pill. Pressing the value itself takes it home.
struct Steps: View {
    let stops: [Double]
    @Binding var value: Double
    let home: Double
    let label: (Double) -> String

    /// The nearest stop either way — a value between stops, from before
    /// there were stops, still moves to a round one.
    private var below: Double? { stops.last { $0 < value - 0.001 } }
    private var above: Double? { stops.first { $0 > value + 0.001 } }

    var body: some View {
        HStack(spacing: 0) {
            Step(icon: "minus", to: below) { value = $0 }
            Button { value = home } label: {
                Text(label(value))
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("恢复为 \(label(home))")
            Step(icon: "plus", to: above) { value = $0 }
        }
        .padding(.horizontal, 2)
        .frame(height: 24)
        .background(Palette.ground, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private struct Step: View {
        let icon: String
        let to: Double?
        let act: (Double) -> Void
        @State private var hovering = false

        var body: some View {
            Button { if let to { act(to) } } label: {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(to == nil ? Palette.faint : Palette.ink)
                    .frame(width: 20, height: 20)
                    .background(hovering && to != nil ? Palette.hover : .clear, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(to == nil)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }
}

/// A small capsule that does one thing. Outlined by default; filled in ink
/// when it is the thing you came here to press.
struct Pill: View {
    let title: String
    var filled = false
    var tint: Color = Palette.ink
    let action: () -> Void

    @State private var hovering = false

    init(_ title: String, filled: Bool = false, tint: Color = Palette.ink, action: @escaping () -> Void) {
        self.title = title
        self.filled = filled
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(filled ? Palette.ground : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(filled ? Palette.ink : (hovering ? Palette.hover : Palette.ground), in: Capsule())
                .overlay(Capsule().strokeBorder(filled ? .clear : Palette.hairline, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// Settings › Privacy: the sites allowed to send notifications, each with a
/// way to take it back.
private struct NotificationSites: View {
    @ObservedObject private var notifications = SiteNotifications.shared

    var body: some View {
        let sites = SiteNotifications.allowed
        if !sites.isEmpty {
            ForEach(sites, id: \.self) { site in
                Rule()
                Line(URL(string: site).map(SiteCard.site) ?? site, "允许发送通知") {
                    Pill("移除") { SiteNotifications.forget(site) }
                }
            }
        }
    }
}
