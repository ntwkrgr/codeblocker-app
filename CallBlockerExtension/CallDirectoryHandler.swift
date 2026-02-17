import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        let blockedPrefixes = BlockedAreaCodesManager.shared.blockedPrefixes

        if context.isIncremental {
            context.removeAllBlockingEntries()
        }

        addBlockingEntries(for: blockedPrefixes, to: context)

        context.completeRequest()
    }

    /// Adds blocking entries for all phone numbers matched by the given prefixes.
    /// Numbers are added in ascending order as required by CXCallDirectoryProvider.
    ///
    /// Numbers are streamed directly to the context to avoid exceeding the
    /// extension's memory limit. Because the prefixes are sorted and their
    /// phone-number ranges are non-overlapping, sequential iteration already
    /// produces the required ascending order.
    private func addBlockingEntries(for prefixes: [String], to context: CXCallDirectoryExtensionContext) {
        for prefix in prefixes.sorted() {
            guard let range = BlockedAreaCodesManager.phoneNumberRange(for: prefix) else { continue }
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
