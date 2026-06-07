import Foundation
import AppKit

enum AndroidReceiverPackageSource: String {
    case bundled = "Bundled"
    case developmentBuild = "Development"
}

struct AndroidReceiverPackageInfo: Equatable {
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

struct AndroidReceiverInstallFailure: Equatable {
    let serial: String
    let output: String
}

struct AndroidReceiverInstallResult: Equatable {
    let installedSerials: [String]
    let failures: [AndroidReceiverInstallFailure]
    let adbMissing: Bool
    let apkMissing: Bool
    let noDevices: Bool

    var succeeded: Bool {
        !installedSerials.isEmpty && failures.isEmpty && !adbMissing && !apkMissing && !noDevices
    }
}

enum AndroidReceiverPackageManager {
    static let bundledDirectoryName = "Android"
    static let bundledFileName = "OpenMultiDisplay-android.apk"
    static let developmentAPKPath = "AndroidClient/app/build/outputs/apk/debug/app-debug.apk"

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

    static func installToAuthorizedUSBDevices(
        apkURL: URL,
        devices: [USBDeviceInfo] = StatusDetector.usbDeviceInfos()
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

            guard let adbPath = StatusDetector.adbExecutablePath() else {
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
                let result = runADB(
                    adbPath: adbPath,
                    arguments: ["-s", device.serial, "install", "-r", apkURL.path]
                )
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

    private static func runADB(adbPath: String, arguments: [String]) -> (status: Int32, output: String) {
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
            return (process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
