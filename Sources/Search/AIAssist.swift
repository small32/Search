import SwiftUI

// The AI add-on as you meet it: Summarize Page and Ask About This Page…, and
// the panel the answer comes in. One page at a time, from your click; the
// questions after the first stay in the panel, and close it and they are
// gone — nothing is kept anywhere. The answer is plain text, never a link to
// follow or a picture to fetch, marked for what it is: a model's reading,
// which may be wrong, and where it ran. What the page says goes to the model
// as the page's words to read, never as orders (see AIPage), and anything
// in the answer the page didn't have is pointed out.
//
// A provider off this Mac is shown what it will be sent the first time it is
// used, before anything goes. A private tab uses only what runs on this Mac.

/// One conversation about one page.
@MainActor
final class Assistant: ObservableObject, Identifiable {
    struct Turn: Identifiable, Equatable {
        let id = UUID()
        /// Nil for the summary.
        let question: String?
        var answer = ""
        var done = false
        var failed: String?
        /// Addresses, emails and numbers in the answer the page doesn't have.
        var strays: [String] = []
    }

    let id = UUID()
    let tab: Tab.ID
    let provider: AIProvider
    let model: String
    /// Asked for a summary, rather than opened for a question.
    let summary: Bool

    @Published private(set) var turns: [Turn] = []
    @Published private(set) var reading = true
    @Published var draft = ""
    /// What a provider off this Mac is sent, not yet agreed to.
    @Published private(set) var notice: String?
    @Published private(set) var trouble: String?
    /// The page has words addressed to an AI (see AIPage.addressesAI).
    @Published private(set) var addressed = false

    private var read: AIPage.Read?
    private let fence = AIPage.newFence()
    private var messages: [AIMessage] = []
    private var waiting: AIPage.Ask?
    private var task: Task<Void, Never>?

    init(tab: Tab, provider: AIProvider, model: String, summary: Bool) {
        self.tab = tab.id
        self.provider = provider
        self.model = model
        self.summary = summary
        Task { @MainActor [weak self, weak tab] in
            guard let self, let tab else { return }
            self.read = await AIPage.read(tab)
            self.addressed = self.read?.addressed ?? false
            self.reading = false
            guard self.read != nil else {
                self.trouble = "此页面没有可读取的内容。"
                return
            }
            if summary { self.ask(.summary) }
        }
    }

    var busy: Bool { reading || turns.last.map { !$0.done } ?? false }

    /// Where it ran, for the foot of every answer.
    var place: String {
        provider == .thisMac ? "在此 Mac 上 · \(model)"
            : provider.isLocal ? "在此 Mac 上 · \(provider.name) · \(model)" : "发送至 \(provider.name) · \(model)"
    }

    func submit() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !busy, notice == nil, read != nil else { return }
        draft = ""
        ask(.question(String(question.prefix(2000))))
    }

    private func ask(_ ask: AIPage.Ask) {
        if !provider.isLocal, !Store.settings.bool(forKey: "ai.told.\(provider.rawValue)") {
            waiting = ask
            notice = AIAssist.notice(for: provider)
            return
        }
        send(ask)
    }

    /// The notice read and agreed to: what was asked goes.
    func agree() {
        Store.settings.set(true, forKey: "ai.told.\(provider.rawValue)")
        notice = nil
        if let waiting { send(waiting) }
        waiting = nil
    }

    private func send(_ ask: AIPage.Ask) {
        guard let read else { return }
        switch ask {
        case .summary:
            messages = [AIMessage(role: .user, text: AIPage.opening(read, .summary, fence: fence))]
            turns.append(Turn(question: nil))
        case .question(let question):
            messages.append(AIMessage(role: .user, text: messages.isEmpty ? AIPage.opening(read, ask, fence: fence) : question))
            turns.append(Turn(question: question))
        }
        // The key, read now and let go with the request.
        let key = provider.isLocal ? nil : AIKeys.key(for: provider)
        let stream = provider == .thisMac
            ? AIEngine.shared.stream(system: AIPage.system(fence: fence), messages: messages)
            : AIClient.shared.stream(provider, model: model, system: AIPage.system(fence: fence), messages: messages, key: key)
        task = Task { @MainActor [weak self] in
            do {
                for try await piece in stream {
                    guard let self, !self.turns.isEmpty else { return }
                    self.turns[self.turns.count - 1].answer += piece
                    // Longer than any answer about a page needs: a model
                    // talked into writing on and on is stopped.
                    if self.turns[self.turns.count - 1].answer.count > Assistant.longest { break }
                }
                self?.finish(nil)
            } catch {
                self?.finish(error.localizedDescription)
            }
        }
    }

    static let longest = 16_000

    private func finish(_ failed: String?) {
        guard !turns.isEmpty, let read else { return }
        var turn = turns[turns.count - 1]
        turn.done = true
        turn.failed = failed
        turns[turns.count - 1] = turn
        // Checked away from the window's thread: a long answer is a long look.
        let id = turn.id, answer = turn.answer
        Task.detached(priority: .userInitiated) { [weak self] in
            let strays = AIPage.strays(in: answer, from: read)
            await MainActor.run {
                guard let self, let index = self.turns.firstIndex(where: { $0.id == id }) else { return }
                self.turns[index].strays = strays
            }
        }
        if failed == nil, !turn.answer.isEmpty {
            messages.append(AIMessage(role: .assistant, text: turn.answer))
        } else if !messages.isEmpty {
            // A question that got no answer isn't part of what follows; the
            // page goes again with the next one if it was the first.
            messages.removeLast()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

enum AIAssist {
    /// What a provider off this Mac is sent, said once, the first time it is
    /// used — and a word on what it does with it where that matters.
    static func notice(for provider: AIProvider) -> String {
        var text = "提问时，Search 会将页面文本、地址和你的问题发送至 \(provider.host)"
        text += provider == .openRouter ? "，再由其转交给模型提供商。" : "."
        text += "适用其服务条款和隐私政策。仅在你提问时发送，无痕标签页不会发送，Search 也不会保留副本。"
        switch provider {
        case .gemini:
            text += "\n\n在欧洲经济区、瑞士和英国以外使用 Gemini 免费服务时，Google 可能用这些内容改进产品，人工也可能查看。请勿用于含敏感信息的页面。"
        case .openRouter:
            text += "\n\nSearch 要求 OpenRouter 仅使用不保留数据的提供商（零数据保留）。"
        default:
            break
        }
        return text
    }
}

extension Browser {
    func summarizePage() { startAssistant(summary: true) }
    func askAboutPage() { startAssistant(summary: false) }

    private func startAssistant(summary: Bool) {
        guard let tab = active, !tab.isBlank else { return }
        guard prefs.ai, let provider = prefs.aiProvider else {
            settingsPage = .ai
            tuning = true
            announce(prefs.ai ? "选择 AI 运行位置" : "在“设置 › AI”中启用 AI")
            return
        }
        // A web page, nothing else: not a file, not an extension's page.
        guard let scheme = tab.pageAddress?.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            announce("AI 仅适用于网页")
            return
        }
        // A private tab leaves nothing behind anywhere, a provider included.
        let shy = tab.shy || tab.built.map { !$0.configuration.websiteDataStore.isPersistent } == true
        guard !shy || provider.isLocal else {
            announce("无痕标签页仅可使用本机 AI")
            return
        }
        if provider == .thisMac, AIEngine.shared.state != .ready {
            settingsPage = .ai
            tuning = true
            announce("此 Mac 尚未安装模型")
            return
        }
        let model = prefs.aiModel(for: provider)
        guard !model.isEmpty else {
            settingsPage = .ai
            tuning = true
            announce("为 \(provider.name) 选择模型")
            return
        }
        guard provider.isLocal || AIKeys.hint(for: provider) != nil else {
            settingsPage = .ai
            tuning = true
            announce("尚未设置 \(provider.name) 的密钥")
            return
        }
        // Asked again on the page the panel is already about: the same
        // conversation goes on.
        if !summary, let open = assisting, open.tab == tab.id, open.provider == provider { return }
        assisting?.stop()
        assisting = Assistant(tab: tab, provider: provider, model: model, summary: summary)
    }

    func closeAssistant() {
        assisting?.stop()
        assisting = nil
    }
}

// MARK: - the panel

struct AssistantPanel: View {
    @ObservedObject var browser: Browser
    @ObservedObject var assistant: Assistant
    /// Drawn off screen, for a picture (bench ai picture): what an image
    /// renderer can't draw — a scroll view, a field — stood in for.
    var drawn = false
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                Text(assistant.summary ? "摘要" : "关于此页面")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Door(icon: "xmark", help: "关闭   esc") { browser.closeAssistant() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if drawn {
                conversation.padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                scrolling
            }

            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 8) {
                if drawn {
                    Text("询问此页面…").font(.system(size: 12.5)).foregroundStyle(Palette.faint)
                } else {
                    TextField("", text: $assistant.draft, prompt: Text("询问此页面…").foregroundStyle(Palette.faint))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.ink)
                        .focused($typing)
                        .onSubmit { assistant.submit() }
                        .disabled(assistant.notice != nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Text("AI 可能出错 · \(assistant.place)")
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.faint)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .frame(width: 380, alignment: .leading)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 8)
        .onAppear { if !assistant.summary, !drawn { typing = true } }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let notice = assistant.notice {
                noticeCard(notice)
            } else if let trouble = assistant.trouble {
                Text(trouble).font(.system(size: 12.5)).foregroundStyle(Palette.muted)
            } else if assistant.reading {
                Text("正在读取页面…").font(.system(size: 12.5)).foregroundStyle(Palette.muted)
            }
            if assistant.addressed, assistant.notice == nil {
                caution("此页面包含针对 AI 的指令，回答可能受到这些内容的影响。")
            }
            ForEach(assistant.turns) { turn in
                TurnView(turn: turn).id(turn.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caution(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 10, weight: .medium))
            Text(verbatim: text).font(.system(size: 11.5)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.muted)
        .padding(8)
        .background(Palette.wash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var scrolling: some View {
            ScrollViewReader { scroller in
                ScrollView(showsIndicators: false) {
                    conversation
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                .onChange(of: assistant.turns.last?.answer) { _, _ in
                    if let last = assistant.turns.last { scroller.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .frame(maxHeight: 420)
    }

    private func noticeCard(_ notice: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("由 \(assistant.provider.name) 回答")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.ink)
            Text(verbatim: notice)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Pill("继续", filled: true) { assistant.agree() }
                Pill("取消") { browser.closeAssistant() }
            }
        }
        .padding(12)
        .background(Palette.wash.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private struct TurnView: View {
        let turn: Assistant.Turn

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                if let question = turn.question {
                    Text(verbatim: question)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
                if turn.answer.isEmpty, !turn.done {
                    Text("…").font(.system(size: 13)).foregroundStyle(Palette.faint)
                }
                // As written, and never as markdown: no link to follow, no
                // picture to fetch.
                if !turn.answer.isEmpty {
                    Text(verbatim: turn.answer)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(2.5)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let failed = turn.failed {
                    Text(verbatim: failed).font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                if !turn.strays.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10, weight: .medium))
                        Text(verbatim: "页面中未提及：" + turn.strays.joined(separator: ", "))
                            .font(.system(size: 11.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Palette.muted)
                    .padding(8)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Settings › AI

struct AISettings: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    /// Drawn off screen, for a picture: menus and fields stood in for.
    var drawn = false
    @State private var pasted = ""
    @State private var hint: String?
    @State private var models: [String] = []
    @State private var looking = false
    @ObservedObject private var engine = AIEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Card {
                Line("在网页中使用 AI", "通过“显示”菜单总结页面或提问。仅在你发起请求时发送内容") {
                    Switch(on: $prefs.ai)
                }
            }
            if prefs.ai {
                Card {
                    Line("运行位置", place) {
                        if drawn {
                            Stand(prefs.aiProvider.map { $0.isLocal ? "\($0.name)，在此 Mac 上" : $0.name } ?? "选择…", menu: true)
                        } else {
                        Picker("", selection: Binding(get: { prefs.aiProvider }, set: { prefs.aiProvider = $0 })) {
                            Text("选择…").tag(AIProvider?.none)
                            ForEach(AIProvider.allCases.filter { $0 != .thisMac || engine.available || prefs.aiProvider == .thisMac }) { provider in
                                Text(provider == .thisMac ? provider.name : provider.isLocal ? "\(provider.name)，在此 Mac 上" : provider.name)
                                    .tag(AIProvider?.some(provider))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        }
                    }
                    if let provider = prefs.aiProvider {
                        Rule()
                        if provider == .thisMac { onThisMac } else if provider.isLocal { localModel(provider) } else { key(provider); Rule(); cloudModel(provider) }
                    }
                }
                .onChange(of: prefs.aiProvider) { _, _ in
                    // A key typed for one provider is never saved for another.
                    pasted = ""
                    refresh()
                }
                .onAppear(perform: refresh)
                Card {
                    Line("清除所有密钥", "从此 Mac 的钥匙串删除密钥。通过 OpenRouter 登录生成的密钥仍有效，需到 openrouter.ai 删除才能撤销") {
                        Pill("清除") {
                            AIKeys.forgetAll()
                            refresh()
                            browser.announce("密钥已清除")
                        }
                    }
                }
            }
        }
    }

    /// The model here: downloaded when you say, checked, prepared once.
    @ViewBuilder
    private var onThisMac: some View {
        let size = ByteCountFormatter.string(fromByteCount: engine.downloadSize, countStyle: .file)
        if AIEngine.translated {
            Line("模型", "需要 Apple 芯片版 Search；当前版本正通过转译运行") { EmptyView() }
        } else {
            switch engine.state {
            case .absent:
                Line("模型", "\(AIEngine.model.name)，一次下载并校验（\(size)），数据不会离开此 Mac") {
                    Pill("下载", filled: true) { engine.install() }
                }
            case .downloading(let done):
                Line("模型", "正在下载… \(Int(done * 100))%") {
                    Pill("取消") { engine.cancelInstall() }
                }
            case .preparing:
                Line("模型", "正在为此 Mac 准备模型，首次约需 20 秒") { EmptyView() }
            case .ready:
                Line("模型", "\(AIEngine.model.name)，在此 Mac 上运行，数据不会离开本机") {
                    Pill("移除") { engine.remove() }
                }
            case .failed(let why):
                Line("模型", why) {
                    Pill("重试") { engine.install() }
                }
            }
        }
    }

    private var place: String {
        guard let provider = prefs.aiProvider else { return "选择已有密钥的服务提供商，或本机应用" }
        return provider.isLocal
            ? "数据不会离开此 Mac，也可用于无痕标签页"
            : "密钥保存在此 Mac 的钥匙串，仅发送至 \(provider.host)。无痕标签页不会发送"
    }

    @ViewBuilder
    private func key(_ provider: AIProvider) -> some View {
        if let hint {
            Line("密钥", "\(hint)，保存在此 Mac 的钥匙串中") {
                Pill("清除") {
                    AIKeys.forget(provider)
                    refresh()
                }
            }
        } else if !AIKeys.available {
            Line("密钥", "此 Search 版本不是签名发行版，无法安全保存密钥。仍可使用本机应用") { EmptyView() }
        } else {
            Line("密钥", provider == .openRouter ? "粘贴密钥，或登录 OpenRouter 自动创建" : "粘贴 API 密钥") {
                HStack(spacing: 6) {
                    SecureField("", text: $pasted, prompt: Text("密钥").foregroundStyle(Palette.faint))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(width: 130)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Palette.wash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .onSubmit { save(provider) }
                    Pill("保存") { save(provider) }
                    if provider == .openRouter {
                        Pill("登录…") {
                            browser.tuning = false
                            AISignIn.start(in: browser)
                        }
                    }
                }
            }
        }
    }

    private func cloudModel(_ provider: AIProvider) -> some View {
        Line("模型", "留空则使用 \(provider.defaultModel)") {
            if drawn {
                Stand(prefs.aiModels[provider.rawValue].flatMap { $0.isEmpty ? nil : $0 } ?? provider.defaultModel, width: 170)
            } else {
            TextField("", text: Binding(get: { prefs.aiModels[provider.rawValue] ?? "" },
                                        set: { prefs.setAIModel($0, for: provider) }),
                      prompt: Text(provider.defaultModel).foregroundStyle(Palette.faint))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 170)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Palette.wash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
    }

    /// A menu or a field, as a picture shows it.
    private struct Stand: View {
        let text: String
        var menu = false
        var width: CGFloat?
        init(_ text: String, menu: Bool = false, width: CGFloat? = nil) { self.text = text; self.menu = menu; self.width = width }
        var body: some View {
            HStack(spacing: 5) {
                Text(text).font(.system(size: 12)).foregroundStyle(menu ? Palette.ink : Palette.faint)
                if menu { Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(Palette.muted) }
            }
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(menu ? Palette.ground : Palette.wash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(menu ? Palette.hairline : .clear, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func localModel(_ provider: AIProvider) -> some View {
        if models.isEmpty {
            Line("模型", looking ? "正在查询 \(provider.name)…" : "\(provider.name) 未运行或尚未安装模型") {
                Pill("重新检查") { refresh() }
            }
        } else {
            Line("模型", "来自此 Mac 上的 \(provider.name)") {
                Picker("", selection: Binding(get: { prefs.aiModel(for: provider) }, set: { prefs.setAIModel($0, for: provider) })) {
                    Text("选择…").tag("")
                    ForEach(models, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }

    private func save(_ provider: AIProvider) {
        let key = pasted
        pasted = ""
        switch AIKeys.save(key, for: provider) {
        case .kept: browser.announce("密钥已保存到钥匙串")
        case .unavailable: browser.announce("此 Search 版本无法保存密钥")
        case .failed: browser.announce("密钥未保存")
        }
        refresh()
    }

    /// Looked at when the page is: a local app is asked for its models only
    /// now, never in the background.
    private func refresh() {
        guard let provider = prefs.aiProvider else { return }
        hint = provider.isLocal ? nil : AIKeys.hint(for: provider)
        models = []
        guard provider.isLocal else { return }
        looking = true
        Task { @MainActor in
            models = await AIClient.shared.localModels(provider)
            looking = false
        }
    }
}
