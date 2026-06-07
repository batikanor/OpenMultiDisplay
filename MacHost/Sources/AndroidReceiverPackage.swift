import Foundation
import AppKit

enum AndroidReceiverPackageSource: String {
    case bundled = "Bundled"
    case developmentBuild = "Development"
}

struct AndroidReceiverPackageInfo: Equatable, Sendable {
    let url: URL
    let source: AndroidReceiverPackageSource
    let sizeBytes: Int64

    var fileName: String {
        url.lastPathComponent
    }

    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct AndroidReceiverInstallFailure: Equatable, Sendable {
    let serial: String
    let output: String
}

struct AndroidReceiverInstallResult: Equatable, Sendable {
    let installedSerials: [String]
    let failures: [AndroidReceiverInstallFailure]
    let adbMissing: Bool
    let apkMissing: Bool
    let noDevices: Bool

    var succeeded: Bool {
        !installedSerials.isEmpty && failures.isEmpty && !adbMissing && !apkMissing && !noDevices
    }
}

struct AndroidReceiverADBResult: Equatable, Sendable {
    let status: Int32
    let output: String
}

typealias AndroidReceiverADBRunner = @Sendable (_ adbPath: String, _ arguments: [String]) -> AndroidReceiverADBResult

struct AndroidReceiverPackageVersion: Equatable, Sendable {
    let versionName: String?
    let versionCode: Int?
}

enum AndroidReceiverDeviceInstallState: Equatable, Sendable {
    case missing
    case installed(versionName: String?, versionCode: Int?)
    case unknown(String)
}

struct AndroidReceiverDeviceStatus: Equatable, Identifiable, Sendable {
    let device: USBDeviceInfo
    let installState: AndroidReceiverDeviceInstallState
    let isRunning: Bool
    let detail: String?

    var id: String {
        device.serial
    }

    var isInstalled: Bool {
        if case .installed = installState {
            return true
        }
        return false
    }

    func needsInstall(expectedVersionName: String?) -> Bool {
        switch installState {
        case .missing:
            return true
        case .unknown:
            return false
        case .installed(let versionName, _):
            guard let expectedVersionName, !expectedVersionName.isEmpty,
                  let versionName, !versionName.isEmpty else {
                return false
            }
            return versionName != expectedVersionName
        }
    }
}

struct AndroidReceiverStatusQueryResult: Equatable, Sendable {
    let statuses: [AndroidReceiverDeviceStatus]
    let adbMissing: Bool
    let noDevices: Bool
}

struct AndroidReceiverPrepareResult: Equatable, Sendable {
    let installedSerials: [String]
    let launchedSerials: [String]
    let statuses: [AndroidReceiverDeviceStatus]
    let failures: [AndroidReceiverInstallFailure]
    let adbMissing: Bool
    let apkMissing: Bool
    let noDevices: Bool

    var succeeded: Bool {
        !launchedSerials.isEmpty && failures.isEmpty && !adbMissing && !apkMissing && !noDevices
    }
}

enum AndroidReceiverPackageManager {
    static let packageIdentifier = "com.batikanor.openmultidisplay"
    static let launcherComponent = "com.batikanor.openmultidisplay/com.openmultidisplay.app.MainActivity"
    static let bundledDirectoryName = "Android"
    static let bundledFileName = "OpenMultiDisplay-android.apk"
    static let developmentAPKPath = "AndroidClient/app/build/outputs/apk/debug/app-debug.apk"
    static let processADBRunner: AndroidReceiverADBRunner = { adbPath, arguments in
        AndroidReceiverPackageManager.runADB(adbPath: adbPath, arguments: arguments)
    }

    static func currentPackageInfo(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> AndroidReceiverPackageInfo? {
        for candidate in candidateURLs(bundle: bundle) {
            guard fileManager.fileExists(atPath: candidate.url.path),
                  let attributes = try? fileManager.attributesOfItem(atPath: candidate.url.path),
                  let size = attributes[.size] as? NSNumber else {
                continue
            }
            return AndroidReceiverPackageInfo(
                url: candidate.url,
                source: candidate.source,
                sizeBytes: size.int64Value
            )
        }
        return nil
    }

    static func reveal(_ info: AndroidReceiverPackageInfo) {
        NSWorkspace.shared.activateFileViewerSelecting([info.url])
    }

    static func currentReceiverVersionName(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> String? {
        if let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for root in developmentRoots(fileManager: fileManager) {
            let versionURL = root.appendingPathComponent("VERSION")
            guard let version = try? String(contentsOf: versionURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !version.isEmpty else {
                continue
            }
            return version
        }

        return nil
    }

    static func receiverStatuses(
        for devices: [USBDeviceInfo] = StatusDetector.usbDeviceInfos(),
        adbPath: String? = StatusDetector.adbExecutablePath(),
        runner: @escaping AndroidReceiverADBRunner = AndroidReceiverPackageManager.processADBRunner
    ) async -> AndroidReceiverStatusQueryResult {
        await Task.detached(priority: .utility) {
            guard let adbPath else {
                return AndroidReceiverStatusQueryResult(statuses: [], adbMissing: true, noDevices: false)
            }
            guard !devices.isEmpty else {
                return AndroidReceiverStatusQueryResult(statuses: [], adbMissing: false, noDevices: true)
            }

            return AndroidReceiverStatusQueryResult(
                statuses: devices.map {
                    receiverStatus(for: $0, adbPath: adbPath, runner: runner)
                },
                adbMissing: false,
                noDevices: false
            )
        }.value
    }

    static func prepareAndLaunchReceiverOnAuthorizedUSBDevices(
        apkURL: URL,
        devices: [USBDeviceInfo] = StatusDetector.usbDeviceInfos(),
        expectedVersionName: String? = currentReceiverVersionName(),
        adbPath: String? = StatusDetector.adbExecutablePath(),
        runner: @escaping AndroidReceiverADBRunner = AndroidReceiverPackageManager.processADBRunner
    ) async -> AndroidReceiverPrepareResult {
        await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: apkURL.path) else {
                return AndroidReceiverPrepareResult(
                    installedSerials: [],
                    launchedSerials: [],
                    statuses: [],
                    failures: [],
                    adbMissing: false,
                    apkMissing: true,
                    noDevices: false
                )
            }

            guard let adbPath else {
                return AndroidReceiverPrepareResult(
                    installedSerials: [],
                    launchedSerials: [],
                    statuses: [],
                    failures: [],
                    adbMissing: true,
                    apkMissing: false,
                    noDevices: false
                )
            }

            guard !devices.isEmpty else {
                return AndroidReceiverPrepareResult(
                    installedSerials: [],
                    launchedSerials: [],
                    statuses: [],
                    failures: [],
                    adbMissing: false,
                    apkMissing: false,
                    noDevices: true
                )
            }

            var installedSerials: [String] = []
            var launchedSerials: [String] = []
            var failures: [AndroidReceiverInstallFailure] = []

            for device in devices {
                let currentStatus = receiverStatus(for: device, adbPath: adbPath, runner: runner)
                if currentStatus.needsInstall(expectedVersionName: expectedVersionName) {
                    let installResult = runner(
                        adbPath,
                        ["-s", device.serial, "install", "-r", apkURL.path]
                    )
                    guard installResult.status == 0 else {
                        failures.append(AndroidReceiverInstallFailure(serial: device.serial, output: installResult.output))
                        continue
                    }
                    installedSerials.append(device.serial)
                }

                let launchResult = runner(
                    adbPath,
                    ["-s", device.serial, "shell", "am", "start", "-n", launcherComponent]
                )
                if adbCommandSucceeded(launchResult) {
                    launchedSerials.append(device.serial)
                } else {
                    failures.append(AndroidReceiverInstallFailure(serial: device.serial, output: launchResult.output))
                }
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
            let statuses = devices.map {
                receiverStatus(for: $0, adbPath: adbPath, runner: runner)
            }

            return AndroidReceiverPrepareResult(
                installedSerials: installedSerials,
                launchedSerials: launchedSerials,
                statuses: statuses,
                failures: failures,
                adbMissing: false,
                apkMissing: false,
                noDevices: false
            )
        }.value
    }

    static func installToAuthorizedUSBDevices(
        apkURL: URL,
        devices: [USBDeviceInfo] = StatusDetector.usbDeviceInfos(),
        adbPath: String? = StatusDetector.adbExecutablePath(),
        runner: @escaping AndroidReceiverADBRunner = AndroidReceiverPackageManager.processADBRunner
    ) async -> AndroidReceiverInstallResult {
        await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: apkURL.path) else {
                return AndroidReceiverInstallResult(
                    installedSerials: [],
                    failures: [],
                    adbMissing: false,
                    apkMissing: true,
                    noDevices: false
                )
            }

            guard let adbPath else {
                return AndroidReceiverInstallResult(
                    installedSerials: [],
                    failures: [],
                    adbMissing: true,
                    apkMissing: false,
                    noDevices: false
                )
            }

            guard !devices.isEmpty else {
                return AndroidReceiverInstallResult(
                    installedSerials: [],
                    failures: [],
                    adbMissing: false,
                    apkMissing: false,
                    noDevices: true
                )
            }

            var installedSerials: [String] = []
            var failures: [AndroidReceiverInstallFailure] = []

            for device in devices {
                let result = runner(adbPath, ["-s", device.serial, "install", "-r", apkURL.path])
                if result.status == 0 {
                    installedSerials.append(device.serial)
                } else {
                    failures.append(AndroidReceiverInstallFailure(serial: device.serial, output: result.output))
                }
            }

            return AndroidReceiverInstallResult(
                installedSerials: installedSerials,
                failures: failures,
                adbMissing: false,
                apkMissing: false,
                noDevices: false
            )
        }.value
    }

    private static func candidateURLs(
        bundle: Bundle,
        fileManager: FileManager = .default
    ) -> [(url: URL, source: AndroidReceiverPackageSource)] {
        var candidates: [(URL, AndroidReceiverPackageSource)] = []

        if let resourceURL = bundle.resourceURL {
            candidates.append((
                resourceURL
                    .appendingPathComponent(bundledDirectoryName)
                    .appendingPathComponent(bundledFileName),
                .bundled
            ))
        }

        for root in developmentRoots(fileManager: fileManager) {
            candidates.append((
                root.appendingPathComponent(developmentAPKPath),
                .developmentBuild
            ))
        }

        return candidates
    }

    static func receiverStatus(
        for device: USBDeviceInfo,
        adbPath: String,
        runner: AndroidReceiverADBRunner = AndroidReceiverPackageManager.processADBRunner
    ) -> AndroidReceiverDeviceStatus {
        let packagePathResult = runner(
            adbPath,
            ["-s", device.serial, "shell", "pm", "path", packageIdentifier]
        )
        guard packagePathIndicatesInstalled(packagePathResult) else {
            return AndroidReceiverDeviceStatus(
                device: device,
                installState: .missing,
                isRunning: false,
                detail: packagePathResult.output.isEmpty ? nil : packagePathResult.output
            )
        }

        let versionResult = runner(
            adbPath,
            ["-s", device.serial, "shell", "dumpsys", "package", packageIdentifier]
        )
        let version = parsePackageVersion(from: versionResult.output)
        let runningResult = runner(
            adbPath,
            ["-s", device.serial, "shell", "pidof", packageIdentifier]
        )

        return AndroidReceiverDeviceStatus(
            device: device,
            installState: .installed(versionName: version?.versionName, versionCode: version?.versionCode),
            isRunning: runningResult.status == 0 && !runningResult.output.isEmpty,
            detail: nil
        )
    }

    static func packagePathIndicatesInstalled(_ result: AndroidReceiverADBResult) -> Bool {
        result.status == 0 && result.output
            .split(whereSeparator: \.isNewline)
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("package:") }
    }

    static func parsePackageVersion(from output: String) -> AndroidReceiverPackageVersion? {
        var versionName: String?
        var versionCode: Int?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("versionName=") {
                versionName = String(line.dropFirst("versionName=".count))
            }

            if let versionCodeRange = line.range(of: "versionCode=") {
                let remainder = line[versionCodeRange.upperBound...]
                let digits = remainder.prefix { $0.isNumber }
                if !digits.isEmpty {
                    versionCode = Int(digits)
                }
            }
        }

        guard versionName != nil || versionCode != nil else { return nil }
        return AndroidReceiverPackageVersion(versionName: versionName, versionCode: versionCode)
    }

    static func adbCommandSucceeded(_ result: AndroidReceiverADBResult) -> Bool {
        let lowercasedOutput = result.output.lowercased()
        return result.status == 0
            && !lowercasedOutput.contains("error:")
            && !lowercasedOutput.contains("failure")
    }

    private static func developmentRoots(fileManager: FileManager) -> [URL] {
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let bundlePath = Bundle.main.bundleURL
        return [
            currentDirectory,
            currentDirectory.deletingLastPathComponent(),
            bundlePath.deletingLastPathComponent(),
            bundlePath.deletingLastPathComponent().deletingLastPathComponent()
        ]
    }

    static func runADB(adbPath: String, arguments: [String]) -> AndroidReceiverADBResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return AndroidReceiverADBResult(
                status: process.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return AndroidReceiverADBResult(status: -1, output: error.localizedDescription)
        }
    }
}
