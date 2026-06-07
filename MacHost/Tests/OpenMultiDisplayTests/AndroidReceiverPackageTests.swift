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

    func testPackagePathDetectsInstalledPackage() {
        XCTAssertTrue(AndroidReceiverPackageManager.packagePathIndicatesInstalled(
            AndroidReceiverADBResult(status: 0, output: "package:/data/app/base.apk")
        ))
        XCTAssertFalse(AndroidReceiverPackageManager.packagePathIndicatesInstalled(
            AndroidReceiverADBResult(status: 1, output: "")
        ))
        XCTAssertFalse(AndroidReceiverPackageManager.packagePathIndicatesInstalled(
            AndroidReceiverADBResult(status: 0, output: "No package found")
        ))
    }

    func testParsesPackageVersionFromDumpsysOutput() {
        let output = """
        Package [com.batikanor.openmultidisplay] (af2bb88):
          versionCode=1000 minSdk=26 targetSdk=34
          versionName=0.10.0
        """

        let version = AndroidReceiverPackageManager.parsePackageVersion(from: output)

        XCTAssertEqual(version?.versionName, "0.10.0")
        XCTAssertEqual(version?.versionCode, 1000)
    }

    func testReceiverStatusMarksMissingWhenPackageIsAbsent() {
        let device = USBDeviceInfo(serial: "missing", model: "Pixel")
        let script = ScriptedADB()

        let status = AndroidReceiverPackageManager.receiverStatus(
            for: device,
            adbPath: "/fake/adb",
            runner: { adbPath, arguments in
                script.run(adbPath: adbPath, arguments: arguments)
            }
        )

        XCTAssertEqual(status.installState, .missing)
        XCTAssertFalse(status.isInstalled)
        XCTAssertFalse(status.isRunning)
    }

    func testPrepareInstallsMissingAndStaleReceiversThenLaunchesAll() async throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("OpenMultiDisplayPrepareTests-\(UUID().uuidString)")
        let apkURL = tempRoot.appendingPathComponent("OpenMultiDisplay-android.apk")
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try Data([0xCA, 0xFE]).write(to: apkURL)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let missing = USBDeviceInfo(serial: "missing", model: "Pixel")
        let stale = USBDeviceInfo(serial: "stale", model: "Galaxy Tab")
        let current = USBDeviceInfo(serial: "current", model: "Galaxy Fold")
        let script = ScriptedADB()
        script.setInstalled(serial: stale.serial, versionName: "0.9.0")
        script.setInstalled(serial: current.serial, versionName: "0.10.0")

        let result = await AndroidReceiverPackageManager.prepareAndLaunchReceiverOnAuthorizedUSBDevices(
            apkURL: apkURL,
            devices: [missing, stale, current],
            expectedVersionName: "0.10.0",
            adbPath: "/fake/adb",
            runner: { adbPath, arguments in
                script.run(adbPath: adbPath, arguments: arguments)
            }
        )

        XCTAssertEqual(result.installedSerials, ["missing", "stale"])
        XCTAssertEqual(result.launchedSerials, ["missing", "stale", "current"])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.statuses.filter(\.isInstalled).count, 3)
        XCTAssertEqual(result.statuses.filter(\.isRunning).count, 3)

        let commands = script.capturedCommands
        XCTAssertEqual(commands.filter { $0.contains("install") }.count, 2)
        XCTAssertEqual(commands.filter { $0.contains("am") && $0.contains("start") }.count, 3)
    }
}

private final class ScriptedADB: @unchecked Sendable {
    private let lock = NSLock()
    private var installedVersions: [String: String] = [:]
    private var runningSerials: Set<String> = []
    private var commands: [[String]] = []

    var capturedCommands: [[String]] {
        locked { commands }
    }

    func setInstalled(serial: String, versionName: String) {
        locked {
            installedVersions[serial] = versionName
        }
    }

    func run(adbPath: String, arguments: [String]) -> AndroidReceiverADBResult {
        locked {
            commands.append(arguments)

            guard let serial = serial(from: arguments) else {
                return AndroidReceiverADBResult(status: 1, output: "missing serial")
            }

            if arguments.contains("install") {
                installedVersions[serial] = "0.10.0"
                return AndroidReceiverADBResult(status: 0, output: "Success")
            }

            if arguments.contains("pm"), arguments.contains("path") {
                guard installedVersions[serial] != nil else {
                    return AndroidReceiverADBResult(status: 1, output: "")
                }
                return AndroidReceiverADBResult(status: 0, output: "package:/data/app/base.apk")
            }

            if arguments.contains("dumpsys"), arguments.contains("package"),
               let versionName = installedVersions[serial] {
                return AndroidReceiverADBResult(
                    status: 0,
                    output: """
                    Package [com.batikanor.openmultidisplay] (af2bb88):
                      versionCode=1000 minSdk=26 targetSdk=34
                      versionName=\(versionName)
                    """
                )
            }

            if arguments.contains("pidof") {
                guard runningSerials.contains(serial) else {
                    return AndroidReceiverADBResult(status: 1, output: "")
                }
                return AndroidReceiverADBResult(status: 0, output: "12345")
            }

            if arguments.contains("am"), arguments.contains("start") {
                guard installedVersions[serial] != nil else {
                    return AndroidReceiverADBResult(status: 1, output: "Error: package not found")
                }
                runningSerials.insert(serial)
                return AndroidReceiverADBResult(status: 0, output: "Starting: Intent")
            }

            return AndroidReceiverADBResult(status: 0, output: "")
        }
    }

    private func serial(from arguments: [String]) -> String? {
        guard let serialFlagIndex = arguments.firstIndex(of: "-s"),
              arguments.indices.contains(serialFlagIndex + 1) else {
            return nil
        }
        return arguments[serialFlagIndex + 1]
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
