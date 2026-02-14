import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        let blockedAreaCodes = BlockedAreaCodesManager.shared.blockedAreaCodes

        if context.isIncremental {
            context.removeAllBlockingEntries()
        }

        addBlockingEntries(for: blockedAreaCodes, to: context)

        context.completeRequest()
    }

    /// Adds blocking entries for all phone numbers in the given area codes.
    /// Numbers are added in ascending order as required by CXCallDirectoryProvider.
    ///
    /// Note: Each area code covers 10 million phone numbers. The system may impose
    /// time limits on extension execution, so blocking many area codes simultaneously
    /// could cause the extension to be terminated. Consider limiting the number of
    /// blocked area codes for optimal performance.
    private func addBlockingEntries(for areaCodes: [String], to context: CXCallDirectoryExtensionContext) {
        var allNumbers = [Int64]()
        let chunkSize: Int64 = 1_000_000
        for areaCode in areaCodes {
            guard let range = BlockedAreaCodesManager.phoneNumberRange(for: areaCode) else { continue }
            var start = range.start
            // Process blocking in 1-million-number chunks for the entire 10 million range
            while start <= range.end {
                let chunkEnd = min(start + chunkSize - 1, range.end)
                for number in start...chunkEnd {
                    allNumbers.append(number)
                }
                start += chunkSize
            }
        }
        for number in allNumbers.sorted() {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("CodeBlocker: Call directory request failed: \(error.localizedDescription)")
    }
}
