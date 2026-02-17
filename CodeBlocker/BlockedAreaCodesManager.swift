import Foundation
import CallKit

/// Manages the list of blocked number prefixes using shared UserDefaults (App Groups).
/// This class is used by both the main app and the Call Directory Extension.
///
/// A prefix is a 3–6 digit string whose first three digits form a valid North
/// American area code (first digit 2-9).  Longer prefixes narrow the blocked
/// range:
///   - 3 digits → entire area code  (~8 M numbers)
///   - 4 digits → area code + first exchange digit  (~1 M numbers)
///   - 5 digits → area code + first two exchange digits (~100 K numbers)
///   - 6 digits → area code + full exchange            (~10 K numbers)
class BlockedAreaCodesManager {
    static let shared = BlockedAreaCodesManager()

    /// The App Group suite name used to share data between the app and extension.
    static let suiteName = "group.com.codeblocker.shared"

    /// Maximum total blocking entries across all prefixes.
    /// CallKit imposes a system-level cap; 24 M stays within budget on iOS 16+.
    static let maxTotalEntries: Int64 = 24_000_000

    /// The UserDefaults key for storing blocked prefixes.
    private let key = "blockedAreaCodes"

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: BlockedAreaCodesManager.suiteName)) {
        self.userDefaults = userDefaults
    }

    /// Returns the sorted list of currently blocked prefixes.
    var blockedPrefixes: [String] {
        get {
            (userDefaults?.stringArray(forKey: key) ?? []).sorted()
        }
        set {
            userDefaults?.set(newValue.sorted(), forKey: key)
        }
    }

    /// Total number of Call Directory entries that the current prefix list generates.
    var currentTotalEntries: Int64 {
        blockedPrefixes.compactMap { BlockedAreaCodesManager.entryCount(for: $0) }.reduce(0, +)
    }

    /// Adds a prefix to the blocked list.
    /// - Parameter prefix: A 3–6 digit prefix string.
    /// - Returns: `true` if the prefix was added, `false` if it was a duplicate,
    ///   conflicts with an existing prefix, or would exceed the entry limit.
    @discardableResult
    func addPrefix(_ prefix: String) -> Bool {
        var prefixes = blockedPrefixes
        guard !prefixes.contains(prefix) else { return false }
        guard conflictingPrefix(for: prefix) == nil else { return false }
        let newEntries = BlockedAreaCodesManager.entryCount(for: prefix) ?? 0
        guard currentTotalEntries + newEntries <= BlockedAreaCodesManager.maxTotalEntries else { return false }
        prefixes.append(prefix)
        blockedPrefixes = prefixes
        return true
    }

    /// Removes a prefix from the blocked list.
    /// - Parameter prefix: The prefix to remove.
    func removePrefix(_ prefix: String) {
        var prefixes = blockedPrefixes
        prefixes.removeAll { $0 == prefix }
        blockedPrefixes = prefixes
    }

    /// Returns the existing prefix that conflicts (overlaps) with `newPrefix`,
    /// or `nil` if there is no conflict.
    func conflictingPrefix(for newPrefix: String) -> String? {
        for existing in blockedPrefixes {
            // New prefix is already covered by a broader existing prefix
            if newPrefix.hasPrefix(existing) { return existing }
            // Existing narrower prefix would overlap with new broader prefix
            if existing.hasPrefix(newPrefix) { return existing }
        }
        return nil
    }

    // MARK: - Validation

    /// Validates that a string is a valid blocking prefix (3–6 digits, first digit 2-9).
    static func isValidPrefix(_ prefix: String) -> Bool {
        guard prefix.count >= 3, prefix.count <= 6,
              let firstChar = prefix.first,
              firstChar >= "2", firstChar <= "9",
              prefix.allSatisfy({ $0.isNumber }) else {
            return false
        }
        return true
    }

    /// Validates that a string is a valid 3-digit North American area code.
    static func isValidAreaCode(_ code: String) -> Bool {
        code.count == 3 && isValidPrefix(code)
    }

    // MARK: - Extension Reload

    /// Reloads the Call Directory Extension to apply blocking changes.
    func reloadExtension(completion: @escaping (Error?) -> Void) {
        CXCallDirectoryManager.sharedInstance.reloadExtension(
            withIdentifier: "com.codeblocker.app.CallBlockerExtension",
            completionHandler: completion
        )
    }

    // MARK: - Phone Number Ranges

    /// Returns the phone number range for a given prefix in E.164 format.
    ///
    /// For a 3-digit area code, invalid NANP exchanges 000-199 are excluded.
    /// For 4–6 digit prefixes the exact specified range is returned.
    static func phoneNumberRange(for prefix: String) -> (start: Int64, end: Int64)? {
        guard isValidPrefix(prefix) else { return nil }
        let areaCode = String(prefix.prefix(3))
        guard let areaCodeNum = Int64(areaCode) else { return nil }

        let base: Int64 = 10_000_000_000 + (areaCodeNum * 10_000_000)

        switch prefix.count {
        case 3:
            // Full area code — skip invalid exchanges 000-199
            return (base + 2_000_000, base + 9_999_999)
        case 4, 5, 6:
            let suffix = String(prefix.dropFirst(3))
            guard let suffixNum = Int64(suffix) else { return nil }
            let multiplier: Int64 = [1_000_000, 100_000, 10_000][prefix.count - 4]
            let start = base + suffixNum * multiplier
            let end = start + multiplier - 1
            return (start, end)
        default:
            return nil
        }
    }

    /// Returns the number of Call Directory entries a prefix would generate.
    static func entryCount(for prefix: String) -> Int64? {
        guard let range = phoneNumberRange(for: prefix) else { return nil }
        return range.end - range.start + 1
    }

    // MARK: - Display Helpers

    /// Formats a prefix as a human-readable phone pattern.
    ///   - "212"    → "(212) XXX-XXXX"
    ///   - "2124"   → "(212) 4XX-XXXX"
    ///   - "21245"  → "(212) 45X-XXXX"
    ///   - "212456" → "(212) 456-XXXX"
    static func formatPrefix(_ prefix: String) -> String {
        guard prefix.count >= 3 else { return prefix }
        let area = String(prefix.prefix(3))
        let rest = String(prefix.dropFirst(3))
        let exchange: String
        switch rest.count {
        case 0: exchange = "XXX"
        case 1: exchange = "\(rest)XX"
        case 2: exchange = "\(rest)X"
        case 3: exchange = rest
        default: exchange = "XXX"
        }
        return "(\(area)) \(exchange)-XXXX"
    }

    /// Returns a short label for a prefix.
    static func prefixLabel(_ prefix: String) -> String {
        switch prefix.count {
        case 3: return "Area Code \(prefix)"
        case 4: return "Prefix \(String(prefix.prefix(3)))-\(String(prefix.dropFirst(3)))"
        case 5: return "Prefix \(String(prefix.prefix(3)))-\(String(prefix.dropFirst(3)))"
        case 6: return "Exchange \(String(prefix.prefix(3)))-\(String(prefix.dropFirst(3)))"
        default: return prefix
        }
    }
}
