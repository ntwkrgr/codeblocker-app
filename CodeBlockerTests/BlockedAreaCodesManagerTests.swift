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
        // Too short
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("21"))
        // Too long
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("2125"))
        // Starts with 0
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("012"))
        // Starts with 1
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("123"))
        // Contains letters
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("2AB"))
        // Empty
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode(""))
        // All zeros
        XCTAssertFalse(BlockedAreaCodesManager.isValidAreaCode("000"))
    }

    // MARK: - Add/Remove Area Code Tests

    func testAddAreaCode() {
        manager.addAreaCode("212")
        XCTAssertEqual(manager.blockedAreaCodes, ["212"])
    }

    func testAddMultipleAreaCodes() {
        manager.addAreaCode("212")
        manager.addAreaCode("415")
        manager.addAreaCode("800")
        XCTAssertEqual(manager.blockedAreaCodes, ["212", "415", "800"])
    }

    func testAddDuplicateAreaCode() {
        manager.addAreaCode("212")
        manager.addAreaCode("212")
        XCTAssertEqual(manager.blockedAreaCodes, ["212"])
    }

    func testRemoveAreaCode() {
        manager.addAreaCode("212")
        manager.addAreaCode("415")
        manager.removeAreaCode("212")
        XCTAssertEqual(manager.blockedAreaCodes, ["415"])
    }

    func testRemoveNonexistentAreaCode() {
        manager.addAreaCode("212")
        manager.removeAreaCode("415")
        XCTAssertEqual(manager.blockedAreaCodes, ["212"])
    }

    func testAreaCodesAreSorted() {
        manager.addAreaCode("800")
        manager.addAreaCode("212")
        manager.addAreaCode("415")
        XCTAssertEqual(manager.blockedAreaCodes, ["212", "415", "800"])
    }

    func testEmptyBlockedAreaCodes() {
        XCTAssertEqual(manager.blockedAreaCodes, [])
    }

    // MARK: - Phone Number Range Tests

    func testPhoneNumberRangeForValidAreaCode() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "212")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 12120000000)
        XCTAssertEqual(range?.end, 12129999999)
    }

    func testPhoneNumberRangeFor800() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "800")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 18000000000)
        XCTAssertEqual(range?.end, 18009999999)
    }

    func testPhoneNumberRangeForInvalidAreaCode() {
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: "123"))
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: ""))
        XCTAssertNil(BlockedAreaCodesManager.phoneNumberRange(for: "ABC"))
    }

    func testPhoneNumberRangesAreNonOverlapping() {
        let range212 = BlockedAreaCodesManager.phoneNumberRange(for: "212")!
        let range213 = BlockedAreaCodesManager.phoneNumberRange(for: "213")!
        XCTAssertLessThan(range212.end, range213.start)
    }

    func testPhoneNumberRangeContains10MillionNumbers() {
        let range = BlockedAreaCodesManager.phoneNumberRange(for: "415")!
        let count = range.end - range.start + 1
        XCTAssertEqual(count, 10_000_000)
    }
}
