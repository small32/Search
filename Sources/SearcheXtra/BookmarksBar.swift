import SwiftUI

// The bookmarks bar: the top of the bookmarks, in a thin row above the page,
// as Chrome and Safari have one. A folder opens as a menu. More than the row
// holds scrolls sideways.
//
// Off unless asked for — Settings › Tabs, or Bookmarks › Show Bookmarks Bar
// — since the page gives up a strip of its height to it. It goes with the
// tabs when they fold away (⌘S) and when a video takes the screen.

struct BookmarksBar: View {
    @ObservedObject var browser: Browser
    @ObservedObject var bookmarks: Bookmarks

    static let height: CGFloat = 30

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: browser.prefs.compactBookmarksBar ? 0 : 2) {
                ForEach(bookmarks.roots) { node in
                    Item(node: node, compact: browser.prefs.compactBookmarksBar) {
                        if node.isFolder {
                            BookmarkMenu.shared.popUp(node, in: browser)
                        } else if let text = node.url, let url = URL(string: text) {
                            browser.visitBookmarkBar(url)
                        }
                    }
                    .overlay {
                        if let url = node.url.flatMap(URL.init(string:)) {
                            MiddleClick { browser.pickBookmark(url, inNewTab: true) }
                        }
                    }
                }
            }
            .padding(.horizontal, browser.prefs.compactBookmarksBar ? 6 : 10)
        }
        .frame(height: BookmarksBar.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
    }

    private struct Item: View {
        let node: Bookmark
        let compact: Bool
        let act: () -> Void
        @State private var hovering = false

        var body: some View {
            HStack(spacing: compact ? 3 : 6) {
                if node.isFolder {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.muted)
                } else {
                    Mark(icon: Favicons.shared.cached(node.site ?? ""), letter: String((node.host ?? "•").prefix(1)).uppercased(), size: 13)
                }
                Text(node.title)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                if node.isFolder {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                }
            }
            .padding(.horizontal, compact ? 4 : 8)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? Palette.hover : .clear))
            .contentShape(Rectangle())
            .onTapGesture(perform: act)
            .onHover { hovering = $0 }
            .help(node.url ?? node.title)
        }
    }
}
