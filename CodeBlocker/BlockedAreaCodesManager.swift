import Foundation
import CallKit

/// Manages the list of blocked area codes using shared UserDefaults (App Groups).
/// This class is used by both the main app and the Call Directory Extension.
class BlockedAreaCodesManager {
    static let shared = BlockedAreaCodesManager()

    /// The App Group suite name used to share data between the app and extension.
    static let suiteName = "group.com.codeblocker.shared"

    /// Maximum number of area codes that can be blocked simultaneously.
    /// Each area code generates ~8 million blocking entries; CallKit imposes a
    /// system-level cap on the total number of entries a Call Directory extension
    /// may register.  Exceeding this cap triggers error 5
    /// (`maximumEntriesExceeded`).  A limit of 3 area codes (~24 M entries) stays
    /// within the budget on iOS 16+ devices.
    static let maxBlockedAreaCodes = 3

    /// The UserDefaults key for storing blocked area codes.
    private let key = "blockedAreaCodes"

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: BlockedAreaCodesManager.suiteName)) {
        self.userDefaults = userDefaults
    }

    /// Returns the sorted list of currently blocked area codes.
    var blockedAreaCodes: [String] {
        get {
            (userDefaults?.stringArray(forKey: key) ?? []).sorted()
        }
        set {
            userDefaults?.set(newValue.sorted(), forKey: key)
        }
    }

    /// Adds an area code to the blocked list.
    /// - Parameter code: A 3-digit area code string.
    /// - Returns: `true` if the code was added, `false` if it was a duplicate
    ///   or the maximum number of blocked area codes has been reached.
    @discardableResult
    func addAreaCode(_ code: String) -> Bool {
        var codes = blockedAreaCodes
        guard !codes.contains(code) else { return false }
        guard codes.count < BlockedAreaCodesManager.maxBlockedAreaCodes else { return false }
        codes.append(code)
        blockedAreaCodes = codes
        return true
    }

    /// Removes an area code from the blocked list.
    /// - Parameter code: The area code to remove.
    func removeAreaCode(_ code: String) {
        var codes = blockedAreaCodes
        codes.removeAll { $0 == code }
        blockedAreaCodes = codes
    }

    /// Validates that a string is a valid North American area code.
    /// Valid area codes are 3 digits with the first digit between 2-9.
    static func isValidAreaCode(_ code: String) -> Bool {
        guard code.count == 3,
              let firstChar = code.first,
              firstChar >= "2", firstChar <= "9",
              code.allSatisfy({ $0.isNumber }) else {
            return false
        }
        return true
    }

    /// Reloads the Call Directory Extension to apply blocking changes.
    func reloadExtension(completion: @escaping (Error?) -> Void) {
        CXCallDirectoryManager.sharedInstance.reloadExtension(
            withIdentifier: "com.codeblocker.app.CallBlockerExtension",
            completionHandler: completion
        )
    }

    /// Returns the phone number range for a given area code in E.164 format.
    /// North American numbers: +1AAANXXXXXX where AAA is the area code and
    /// the exchange (NXX) starts with digits 2-9 per the North American
    /// Numbering Plan.  Exchanges 000-199 are invalid and excluded.
    static func phoneNumberRange(for areaCode: String) -> (start: Int64, end: Int64)? {
        guard isValidAreaCode(areaCode), let areaCodeNum = Int64(areaCode) else {
            return nil
        }
        // E.164 format: +1 AAA NXX XXXX → stored as Int64
        // Country code 1 base: 10_000_000_000, area code multiplier: 10_000_000
        // Valid exchanges start at 200 (offset 2_000_000)
        let base: Int64 = 10_000_000_000 + (areaCodeNum * 10_000_000)
        let start: Int64 = base + 2_000_000
        let end: Int64 = base + 9_999_999
        return (start, end)
    }
}
