import Foundation

struct USBDeviceInfo: Hashable, Sendable {
    let serial: String
    let model: String?
}

struct DeviceDisplayConfig: Codable, Sendable {
    var name: String?
    var width: Int?
    var height: Int?
    var refreshRate: Int?
    var bitrate: Int?
    var quality: String?
    var hiDPI: Bool?
    var rotation: Int?
    var positionX: Int?
    var positionY: Int?

    var resolutionLabel: String? {
        guard let width, let height else { return nil }
        return "\(width)x\(height)"
    }
}

struct DeviceDisplaySpec: Sendable {
    let device: USBDeviceInfo
    let name: String
    let hostPort: UInt16
    let width: Int
    let height: Int
    let refreshRate: Int
    let bitrate: Int
    let quality: String
    let hiDPI: Bool
    let rotation: Int
    let positionX: Int?
    let positionY: Int?

    var virtualDisplaySerialNumber: UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in device.serial.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash == 0 ? 1 : hash
    }

    func withFallbackPosition(x: Int, y: Int) -> DeviceDisplaySpec {
        DeviceDisplaySpec(
            device: device,
            name: name,
            hostPort: hostPort,
            width: width,
            height: height,
            refreshRate: refreshRate,
            bitrate: bitrate,
            quality: quality,
            hiDPI: hiDPI,
            rotation: rotation,
            positionX: positionX ?? x,
            positionY: positionY ?? y
        )
    }
}

enum DeviceDisplayConfigStore {
    private struct ConfigFile: Codable {
        var devices: [String: DeviceDisplayConfig]
    }

    static var configURL: URL {
        let newDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".tetherspan", isDirectory: true)
        let newURL = newDir.appendingPathComponent("devices.json")
        let legacyURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".sidescreen-multi", isDirectory: true)
            .appendingPathComponent("devices.json")

        if !FileManager.default.fileExists(atPath: newURL.path),
           FileManager.default.fileExists(atPath: legacyURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: newDir,
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: legacyURL, to: newURL)
                debugLog("Migrated legacy device config to \(newURL.path)")
            } catch {
                debugLog("Failed to migrate \(legacyURL.path): \(error.localizedDescription)")
            }
        }

        return newURL
    }

    static func load() -> [String: DeviceDisplayConfig] {
        load(from: configURL)
    }

    static func load(from url: URL, logErrors: Bool = true) -> [String: DeviceDisplayConfig] {
        guard let data = try? Data(contentsOf: url) else { return [:] }

        do {
            return try JSONDecoder().decode(ConfigFile.self, from: data).devices
        } catch {
            if logErrors {
                debugLog("Failed to parse \(url.path): \(error.localizedDescription)")
            }
            return [:]
        }
    }

    static func save(_ configs: [String: DeviceDisplayConfig]) throws {
        try save(configs, to: configURL)
    }

    static func save(_ configs: [String: DeviceDisplayConfig], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.prettySorted.encode(ConfigFile(devices: configs))
        try data.write(to: url, options: .atomic)
    }

    static func save(_ config: DeviceDisplayConfig, for serial: String) throws {
        var configs = load()
        configs[serial] = config
        try save(configs)
    }

    static func writeSampleIfMissing(for devices: [USBDeviceInfo], settings: DisplaySettings) {
        let url = configURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var defaults: [String: DeviceDisplayConfig] = [:]
            for (index, device) in devices.enumerated() {
                let fallback = defaultConfig(for: device, index: index, settings: settings)
                defaults[device.serial] = fallback
            }

            try save(defaults, to: url)
            debugLog("Created per-device display config at \(url.path)")
        } catch {
            debugLog("Failed to create \(url.path): \(error.localizedDescription)")
        }
    }

    static func spec(
        for device: USBDeviceInfo,
        index: Int,
        hostPort: UInt16,
        settings: DisplaySettings,
        savedConfigs: [String: DeviceDisplayConfig]
    ) -> DeviceDisplaySpec {
        let defaults = defaultConfig(for: device, index: index, settings: settings)
        let saved = savedConfigs[device.serial]

        let width = saved?.width ?? defaults.width ?? settings.resolutionSize.width
        let height = saved?.height ?? defaults.height ?? settings.resolutionSize.height
        let name = saved?.name ?? defaults.name ?? device.model ?? "Android \(index + 1)"

        return DeviceDisplaySpec(
            device: device,
            name: name,
            hostPort: hostPort,
            width: width,
            height: height,
            refreshRate: saved?.refreshRate ?? defaults.refreshRate ?? settings.effectiveRefreshRate,
            bitrate: saved?.bitrate ?? defaults.bitrate ?? settings.effectiveBitrate,
            quality: saved?.quality ?? defaults.quality ?? settings.effectiveQuality,
            hiDPI: saved?.hiDPI ?? defaults.hiDPI ?? settings.hiDPI,
            rotation: saved?.rotation ?? defaults.rotation ?? settings.rotation,
            positionX: saved?.positionX ?? defaults.positionX,
            positionY: saved?.positionY ?? defaults.positionY
        )
    }

    static func defaultConfig(for device: USBDeviceInfo, index: Int, settings: DisplaySettings) -> DeviceDisplayConfig {
        let model = (device.model ?? "").uppercased()

        if model.contains("SM_T870") || model.contains("GTS7") {
            return DeviceDisplayConfig(
                name: "Galaxy Tab S7",
                width: 1920,
                height: 1200,
                refreshRate: 60,
                bitrate: 1000,
                quality: "ultralow",
                hiDPI: false,
                rotation: 0,
                positionX: nil,
                positionY: nil
            )
        }

        if model.contains("SM_F936") || model.contains("Q4Q") {
            return DeviceDisplayConfig(
                name: "Galaxy Z Fold 4",
                width: 1600,
                height: 1200,
                refreshRate: 60,
                bitrate: 800,
                quality: "ultralow",
                hiDPI: false,
                rotation: 0,
                positionX: nil,
                positionY: nil
            )
        }

        return DeviceDisplayConfig(
            name: device.model ?? "Android \(index + 1)",
            width: settings.resolutionSize.width,
            height: settings.resolutionSize.height,
            refreshRate: settings.effectiveRefreshRate,
            bitrate: settings.effectiveBitrate,
            quality: settings.effectiveQuality,
            hiDPI: settings.hiDPI,
            rotation: settings.rotation,
            positionX: nil,
            positionY: nil
        )
    }
}

private extension JSONEncoder {
    static var prettySorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
