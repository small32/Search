import AppKit
import XCTest
@testable import Search

@MainActor
final class StartPageTests: XCTestCase {
    private var previousPage = ""

    override func setUp() async throws {
        guard Store.testing else { throw XCTSkip("Run browser model tests with SEARCH_PROBE=interface-tests") }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        previousPage = Shared.prefs.startPage
        Shared.prefs.startPage = ""
    }

    override func tearDown() async throws {
        guard Store.testing else { return }
        Shared.prefs.startPage = previousPage
        XCTAssertTrue(NSApp.windows.allSatisfy { !$0.isVisible })
    }

    func testAddressesNormalizeAndRejectNonWebInputs() {
        XCTAssertEqual(StartPage.url(from: " example.com/path?q=1 \n")?.absoluteString, "https://example.com/path?q=1")
        XCTAssertEqual(StartPage.url(from: "localhost:8080/start")?.absoluteString, "http://localhost:8080/start")
        XCTAssertEqual(StartPage.url(from: "http://0.0.0.0:8080/")?.host(), "localhost")
        for input in ["", "   ", "search words", "https://", "javascript:alert(1)", "file:///tmp/start.html", "mailto:a@example.com", "https://example.com/\npath"] {
            XCTAssertNil(StartPage.url(from: input), input)
        }
    }

    func testPreferencePersistsAndClears() {
        Shared.prefs.startPage = "http://127.0.0.1:1/start"
        XCTAssertEqual(Preferences().startPageURL?.absoluteString, Shared.prefs.startPage)
        Shared.prefs.startPage = ""
        XCTAssertNil(Preferences().startPageURL)
    }

    func testFreshWindowAndNormalNewTabUseStartPage() {
        let url = "http://127.0.0.1:1/start"
        Shared.prefs.startPage = url
        let browser = Browser(record: WindowRecord())
        XCTAssertEqual(browser.active?.address?.absoluteString, url)
        let first = browser.activeID
        browser.newTab()
        XCTAssertNotEqual(browser.activeID, first)
        XCTAssertEqual(browser.active?.address?.absoluteString, url)
    }

    func testPrivateTabsStayBlankAndClearingRestoresBlankNewTabs() {
        Shared.prefs.startPage = "http://127.0.0.1:1/start"
        let browser = Browser(record: WindowRecord())
        browser.newShyTab()
        browser.newTab()
        XCTAssertEqual(browser.active?.shy, true)
        XCTAssertEqual(browser.active?.isBlank, true)
        let plain = browser.tabs.first { !$0.shy }!
        browser.select(plain)
        Shared.prefs.startPage = ""
        browser.newTab()
        XCTAssertEqual(browser.active?.shy, false)
        XCTAssertEqual(browser.active?.isBlank, true)
    }

    func testExplicitWindowPagesCanSkipStartPage() {
        Shared.prefs.startPage = "http://127.0.0.1:1/start"
        let browser = Browser(record: WindowRecord(), opensStartPage: false)
        XCTAssertEqual(browser.active?.isBlank, true)
    }

    func testRestoredSessionKeepsItsOriginalPage() {
        Shared.prefs.startPage = "http://127.0.0.1:1/start"
        let restored = "http://127.0.0.1:1/previous"
        var record = WindowRecord()
        record.rows[record.space.uuidString] = Session.Shape(tabs: [
            Session.Entry(url: restored, title: "Previous", pin: nil, name: nil, home: nil)
        ], active: 0)
        let browser = Browser(record: record)
        XCTAssertEqual((browser.active?.pending ?? browser.active?.address)?.absoluteString, restored)
    }
}
