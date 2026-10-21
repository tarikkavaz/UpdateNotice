import Foundation

/// A dotted numeric version such as `2.0.10`. Compared per component, so 2.0.10 is newer than
/// 2.0.9, and a missing component counts as zero (`2.0` equals `2.0.0`).
public struct Version: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let components: [Int]

    /// Returns nil for anything that is not dot-separated digits. A leading `v` is allowed.
    public init?(_ string: String) {
        var body = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("v") { body.removeFirst() }
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        guard !numbers.isEmpty else { return nil }
        components = numbers
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    private var trimmed: [Int] {
        var result = components
        while result.count > 1, result.last == 0 { result.removeLast() }
        return result
    }

    public static func == (lhs: Version, rhs: Version) -> Bool { lhs.trimmed == rhs.trimmed }

    public func hash(into hasher: inout Hasher) { hasher.combine(trimmed) }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}
