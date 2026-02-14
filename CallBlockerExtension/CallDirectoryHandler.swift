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
    /// Numbers are streamed directly to the context to avoid exceeding the
    /// extension's memory limit. Because the area codes are sorted and their
    /// phone-number ranges are non-overlapping, sequential iteration already
    /// produces the required ascending order.
    private func addBlockingEntries(for areaCodes: [String], to context: CXCallDirectoryExtensionContext) {
        for areaCode in areaCodes.sorted() {
            guard let range = BlockedAreaCodesManager.phoneNumberRange(for: areaCode) else { continue }
            for number in range.start...range.end {
                context.addBlockingEntry(withNextSequentialPhoneNumber: number)
            }
        }
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("CodeBlocker: Call directory request failed: \(error.localizedDescription)")
    }
}
