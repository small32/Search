import Foundation

/// A website to open in fresh windows and ordinary new tabs.
enum StartPage {
    static func url(from input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace),
              let url = Address.url(from: text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), !host.isEmpty else { return nil }
        return Address.reachable(url) ?? url
    }
}
