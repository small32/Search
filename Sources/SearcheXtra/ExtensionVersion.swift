import Foundation

enum ExtensionVersion {
    enum Invalid: Error { case version }
    static func isNewer(_ remote: String, than local: String) throws -> Bool {
        func parts(_ version: String) throws -> [UInt16] {
            let strings = version.split(separator: ".", omittingEmptySubsequences: false)
            guard (1...4).contains(strings.count) else { throw Invalid.version }
            let numbers = try strings.map { value -> UInt16 in
                guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }), let number = UInt16(value) else { throw Invalid.version }
                return number
            }
            return numbers + Array(repeating: 0, count: 4 - numbers.count)
        }
        let newer = try parts(remote), current = try parts(local)
        return current.lexicographicallyPrecedes(newer)
    }
}
