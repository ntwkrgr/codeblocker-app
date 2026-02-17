import XCTest
@testable import CodeBlocker

final class BlockedAreaCodesManagerTests: XCTestCase {

    private var manager: BlockedAreaCodesManager!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.codeblocker.tests")
        testDefaults.removePersistentDomain(forName: "com.codeblocker.tests")
        manager = BlockedAreaCodesManager(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.codeblocker.tests")
        testDefaults = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - Area Code Validation Tests

    func testValidAreaCodes() {
        XCTAssertTrue(BlockedAreaCodesManager.isValidAreaCode("212"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidAreaCode("415"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidAreaCode("800"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidAreaCode("999"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidAreaCode("200"))
    }

    func testInvalidAreaCodes() {
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("21"))
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("2125"))
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("012"))
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("123"))
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("2AB"))
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode(""))
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("000"))
    }

    // MARK: - Prefix Validation Tests

    func testValidPrefixes() {
        XCTAssertTrue(BlockedAreaCodesManager.isValidPrefix("212"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidPrefix("2124"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidPrefix("21245"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidPrefix("212456"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidPrefix("8005"))
        XCTAssertTrue(BlockedAreaCodesManager.isValidPrefix("200000"))
    }

    func testInvalidPrefixes() {
        // Too short
        XCTAssertFalse(BlockedAreaCodesManager.isValidPrefix("21"))
        // Too long
        XCTAssertFalse(BlockedAreaCodesManager.isValidPrefix("2124567"))
        // Starts with 0
        XCTAssertFalse(BlockedAreaCodesManager.isValidPrefix("012"))
        // Starts with 1
        XCTAssertFalse(BlockedAreaCodesManager.isValidPrefix("1234"))
        // Contains letters
        XCTAssertFalse(BlockedAreaCodesManager.isValidPrefix("21AB"))
        // Empty
        XCTAssertFalse(BlockedAreaCodesManager.isValidPrefix(""))
    }

    // MARK: - Add/Remove Prefix Tests

    func testAddPrefix() {
        manager.addPrefix("212")
        XCTAssertEqual(manager.blockedPrefixes, ["212"])
    }

    func testAddMultiplePrefixes() {
        manager.addPrefix("212")
        manager.addPrefix("415")
        manager.addPrefix("800")
        XCTAssertEqual(manager.blockedPrefixes, ["212", "415", "800"])
    }

    func testAddMixedLengthPrefixes() {
        manager.addPrefix("212")
        manager.addPrefix("4155")
        manager.addPrefix("800456")
        XCTAssertEqual(manager.blockedPrefixes, ["212", "4155", "800456"])
    }

    func testAddDuplicatePrefix() {
        manager.addPrefix("212")
        manager.addPrefix("212")
        XCTAssertEqual(manager.blockedPrefixes, ["212"])
    }

    func testRemovePrefix() {
        manager.addPrefix("212")
        manager.addPrefix("415")
        manager.removePrefix("212")
        XCTAssertEqual(manager.blockedPrefixes, ["415"])
    }

    func testRemoveNonexistentPrefix() {
        manager.addPrefix("212")
        manager.removePrefix("415")
        XCTAssertEqual(manager.blockedPrefixes, ["212"])
    }

    func testPrefixesAreSorted() {
        manager.addPrefix("800")
        manager.addPrefix("212")
        manager.addPrefix("415")
        XCTAssertEqual(manager.blockedPrefixes, ["212", "415", "800"])
    }

    func testEmptyBlockedPrefixes() {
        XCTAssertEqual(manager.blockedPrefixes, [])
    }

    // MARK: - Overlap / Conflict Detection Tests

    func testNarrowerPrefixRejectedWhenBroaderExists() {
        manager.addPrefix("212")
        let added = manager.addPrefix("2124")
        XCTAssertFalse(added)
        XCTAssertEqual(manager.blockedPrefixes, ["212"])
    }

    func testBroaderPrefixRejectedWhenNarrowerExists() {
        manager.addPrefix("2124")
        let added = manager.addPrefix("212")
        XCTAssertFalse(added)
        XCTAssertEqual(manager.blockedPrefixes, ["2124"])
    }

    func testNonOverlappingSiblingPrefixesAllowed() {
        manager.addPrefix("2124")
        let added = manager.addPrefix("2125")
        XCTAssertTrue(added)
        XCTAssertEqual(manager.blockedPrefixes, ["2124", "2125"])
    }

    func testConflictingPrefixDetection() {
        manager.addPrefix("212")
        XCTAssertEqual(manager.conflictingPrefix(for: "2124"), "212")
        XCTAssertNil(manager.conflictingPrefix(for: "213"))
    }

    // MARK: - Entry Count & Limit Tests

    func testEntryCountForAreaCode() {
        XCTAssertEqual(BlockedAreaCodesManager.entryCount(for: "212"), 8_000_000)
    }

    func testEntryCountFor4DigitPrefix() {
        XCTAssertEqual(BlockedAreaCodesManager.entryCount(for: "2124"), 1_000_000)
    }

    func testEntryCountFor5DigitPrefix() {
        XCTAssertEqual(BlockedAreaCodesManager.entryCount(for: "21245"), 100_000)
    }

    func testEntryCountFor6DigitPrefix() {
        XCTAssertEqual(BlockedAreaCodesManager.entryCount(for: "212456"), 10_000)
    }

    func testCurrentTotalEntries() {
        manager.addPrefix("212")
        manager.addPrefix("800456")
        XCTAssertEqual(manager.currentTotalEntries, 8_000_000 + 10_000)
    }

    func testAddPrefixRespectsEntryLimit() {
        // 3 full area codes = 24 M entries = exactly at limit
        manager.addPrefix("200")
        manager.addPrefix("300")
        manager.addPrefix("400")
        XCTAssertEqual(manager.currentTotalEntries, 24_000_000)
        // Adding even a small prefix should fail
        let added = manager.addPrefix("500456")
        XCTAssertFalse(added)
    }

    // MARK: - Phone Number Range Tests

    func testPhoneNumberRangeForAreaCode() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "212")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 12122000000)
        XCTAssertEqual(range?.end, 12129999999)
    }

    func testPhoneNumberRangeFor4DigitPrefix() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "2124")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 12124000000)
        XCTAssertEqual(range?.end, 12124999999)
    }

    func testPhoneNumberRangeFor5DigitPrefix() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "21245")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 12124500000)
        XCTAssertEqual(range?.end, 12124599999)
    }

    func testPhoneNumberRangeFor6DigitPrefix() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "212456")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 12124560000)
        XCTAssertEqual(range?.end, 12124569999)
    }

    func testPhoneNumberRangeFor800() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "800")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 18002000000)
        XCTAssertEqual(range?.end, 18009999999)
    }

    func testPhoneNumberRangeForInvalidPrefix() {
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: "123"))
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: ""))
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: "ABC"))
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: "12"))
    }

    func testPhoneNumberRangesAreNonOverlapping() {
        let range212 = BlockedAreaCodesManager.phoneNumberRange(for: "212")!
        let range213 = BlockedAreaCodesManager.phoneNumberRange(for: "213")!
        XCTAssertLessThan(range212.end, range213.start)
    }

    func testPhoneNumberRangeAreaCodeContains8MillionNumbers() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "415")!
        let count = range.end - range.start + 1
        XCTAssertEqual(count, 8_000_000)
    }

    func testPhoneNumberRangeExcludesInvalidExchanges() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "212")!
        XCTAssertEqual(range.start, 12122000000)
        XCTAssertGreaterThan(range.start, 12121999999)
    }

    func testSortedPrefixesProduceAscendingRanges() {
        let prefixes = ["800", "2124", "21245", "415"]
        let sorted = prefixes.sorted()
        let ranges = sorted.compactMap { BlockedAreaCodesManager.phoneNumberRange(for: $0) }

        XCTAssertEqual(ranges.count, sorted.count)
        for i in 1..<ranges.count {
            XCTAssertGreaterThan(ranges[i].start, ranges[i - 1].end,
                "Range for \(sorted[i]) should start after range for \(sorted[i - 1])")
        }
    }

    // MARK: - Display Helper Tests

    func testFormatPrefix3Digits() {
        XCTAssertEqual(BlockedAreaCodesManager.formatPrefix("212"), "(212) XXX-XXXX")
    }

    func testFormatPrefix4Digits() {
        XCTAssertEqual(BlockedAreaCodesManager.formatPrefix("2124"), "(212) 4XX-XXXX")
    }

    func testFormatPrefix5Digits() {
        XCTAssertEqual(BlockedAreaCodesManager.formatPrefix("21245"), "(212) 45X-XXXX")
    }

    func testFormatPrefix6Digits() {
        XCTAssertEqual(BlockedAreaCodesManager.formatPrefix("212456"), "(212) 456-XXXX")
    }

    func testPrefixLabelAreaCode() {
        XCTAssertEqual(BlockedAreaCodesManager.prefixLabel("212"), "Area Code 212")
    }

    func testPrefixLabelExchange() {
        XCTAssertEqual(BlockedAreaCodesManager.prefixLabel("212456"), "Exchange 212-456")
    }
}
