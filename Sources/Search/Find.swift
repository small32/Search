import SwiftUI

/// Looking for a word on the page. A pill in the top corner, the same white and
/// hairline as everything else that floats, and gone the moment it isn't wanted.
struct FindBar: View {
    @ObservedObject var browser: Browser
    var availableWidth: CGFloat? = nil

    @FocusState private var focused: Bool

    private var narrow: Bool { availableWidth.map { $0 < 290 } ?? false }
    private var fieldWidth: CGFloat {
        guard let availableWidth else { return 150 }
        return max(40, min(160, availableWidth - (narrow ? 80 : 130)))
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                if browser.needle.isEmpty {
                    Text("在页面中查找")
                        .foregroundStyle(Palette.ink.opacity(0.3))
                }
                TextField("", text: $browser.needle)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel("在页面中查找")
                    .accessibilityHint("输入文字搜索此页面。按回车查找下一个匹配项。")
                    .focused($focused)
                    .onSubmit { browser.look(forward: true) }
            }
            .font(.system(size: 12.5))
            .frame(width: fieldWidth)

            // "3 of 17", as the page counted it.
            if let status = browser.findStatus {
                Text(status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(browser.missed ? Color.red.opacity(0.8) : Palette.muted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(status)
                    .accessibilityIdentifier("查找结果状态")
            }

            // A pane too narrow for them keeps Return and ⇧Return instead.
            if !narrow {
                step("chevron.up", label: "上一个匹配项", help: "查找上一个匹配项。") {
                    browser.look(forward: false)
                }
                step("chevron.down", label: "下一个匹配项", help: "查找下一个匹配项。") {
                    browser.look(forward: true)
                }
            }

            Menu {
                Toggle("区分大小写", isOn: $browser.matchCase)
                    .help("精确匹配字母的大小写。")
                Toggle("全字匹配", isOn: $browser.wholeWords)
                    .disabled(browser.findResult?.nativeFallback == true && !browser.wholeWords)
                    .help("仅匹配完整单词。PDF 页面不支持此选项。")
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(browser.matchCase || browser.wholeWords ? Palette.ink : Palette.muted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("查找选项")
            .accessibilityHint("选择是否区分大小写或匹配完整单词。")
            .help("查找选项")

            step("xmark", label: "关闭页面查找", help: "关闭查找框并清除选中内容。") {
                browser.closeFind()
            }
        }
        .padding(.leading, narrow ? 10 : 16)
        .padding(.trailing, narrow ? 6 : 8)
        .padding(.vertical, 8)
        .background(Palette.ground, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                browser.missed ? Color.red.opacity(0.35) : Palette.hairline,
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 5)
        .padding(.top, 12)
        .padding(.trailing, 14)
        .animation(Motion.quick, value: browser.missed)
        .onAppear(perform: focus)
        .onChange(of: browser.findFocus) { _, _ in focus() }
    }

    /// Into the field, and once more a moment later if it didn't take: as
    /// the bar comes in, the field may not be in the window yet, and with
    /// the Mac's keyboard navigation on, the keyboard went to the first
    /// button instead — the back button — until ⌘F was pressed again (#172).
    private func focus() {
        focused = true
        DispatchQueue.main.async {
            if !focused { focused = true }
        }
    }

    private func step(
        _ icon: String,
        label: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(help)
        .help(help)
    }
}
