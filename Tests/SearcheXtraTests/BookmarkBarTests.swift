import AppKit
import XCTest
@testable import SearcheXtra

@MainActor
final class BookmarkBarTests: XCTestCase {
    private var previousOpening: BookmarkBarOpening = .standard
    private var previousCompact = false
    private var previousLazy = false

    override func setUp() async throws {
        guard Store.testing else { throw XCTSkip("Run with SEARCH_PROBE=interface-tests") }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        previousOpening = Shared.prefs.bookmarkBarOpening
        previousCompact = Shared.prefs.compactBookmarksBar
        previousLazy = Shared.prefs.lazyTabs
    }

    override func tearDown() async throws {
        guard Store.testing else { return }
        Shared.prefs.bookmarkBarOpening = previousOpening
        Shared.prefs.compactBookmarksBar = previousCompact
        Shared.prefs.lazyTabs = previousLazy
    }

    func testOpeningModesPreserveOrChangeTheActiveTab() {
        let original = URL(string: "http://127.0.0.1:1/original")!
        let bookmark = URL(string: "http://127.0.0.1:1/bookmark")!
        for mode in BookmarkBarOpening.allCases {
            let browser = Browser(record: WindowRecord(), opensStartPage: false)
            defer { for tab in browser.tabs { tab.close() } }
            browser.visit(original)
            let first = browser.active!
            let count = browser.tabs.count
            Shared.prefs.bookmarkBarOpening = mode
            Shared.prefs.lazyTabs = true
            browser.visitBookmarkBar(bookmark)
            switch mode {
            case .standard:
                XCTAssertEqual(browser.tabs.count, count)
                XCTAssertEqual(browser.activeID, first.id)
                XCTAssertEqual(first.address, bookmark)
            case .background:
                XCTAssertEqual(browser.tabs.count, count + 1)
                XCTAssertEqual(browser.activeID, first.id)
                XCTAssertEqual(first.address, original)
                XCTAssertEqual(browser.tabs.first { $0.id != first.id }?.pending, bookmark)
            case .foreground:
                XCTAssertEqual(browser.tabs.count, count + 1)
                XCTAssertNotEqual(browser.activeID, first.id)
                XCTAssertEqual(first.address, original)
                XCTAssertEqual(browser.active?.address, bookmark)
            }
        }
    }

    func testSettingsPersist() {
        Shared.prefs.compactBookmarksBar = true
        XCTAssertTrue(Preferences().compactBookmarksBar)
        Shared.prefs.compactBookmarksBar = false
        XCTAssertFalse(Preferences().compactBookmarksBar)
        for mode in BookmarkBarOpening.allCases {
            Shared.prefs.bookmarkBarOpening = mode
            XCTAssertEqual(Preferences().bookmarkBarOpening, mode)
        }
    }
}
