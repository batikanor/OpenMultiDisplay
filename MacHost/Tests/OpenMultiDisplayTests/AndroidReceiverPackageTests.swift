import XCTest
@testable import OpenMultiDisplay

final class AndroidReceiverPackageTests: XCTestCase {
    func testFindsDevelopmentAPKFromCurrentDirectory() throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("OpenMultiDisplayPackageTests-\(UUID().uuidString)")
        let apkURL = tempRoot
            .appendingPathComponent(AndroidReceiverPackageManager.developmentAPKPath)

        try fileManager.createDirectory(
            at: apkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0x01, 0x02, 0x03]).write(to: apkURL)

        XCTAssertTrue(fileManager.changeCurrentDirectoryPath(tempRoot.path))
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(at: tempRoot)
        }

        let info = AndroidReceiverPackageManager.currentPackageInfo()

        XCTAssertEqual(info?.url.standardizedFileURL, apkURL.standardizedFileURL)
        XCTAssertEqual(info?.source, .developmentBuild)
        XCTAssertEqual(info?.sizeBytes, 3)
    }

    func testInstallResultRequiresNoFailuresForSuccess() {
        let success = AndroidReceiverInstallResult(
            installedSerials: ["device-a"],
            failures: [],
            adbMissing: false,
            apkMissing: false,
            noDevices: false
        )
        let partialFailure = AndroidReceiverInstallResult(
            installedSerials: ["device-a"],
            failures: [AndroidReceiverInstallFailure(serial: "device-b", output: "failed")],
            adbMissing: false,
            apkMissing: false,
            noDevices: false
        )

        XCTAssertTrue(success.succeeded)
        XCTAssertFalse(partialFailure.succeeded)
    }
}
