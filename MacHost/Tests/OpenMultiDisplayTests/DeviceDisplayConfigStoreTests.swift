import XCTest
@testable import OpenMultiDisplay

final class DeviceDisplayConfigStoreTests: XCTestCase {
    func testSaveAndLoadConfigs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceDisplayConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("devices.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let configs = [
            "SERIAL-1": DeviceDisplayConfig(
                name: "Galaxy Tab",
                width: 1920,
                height: 1200,
                refreshRate: 60,
                bitrate: 1000,
                quality: "ultralow",
                hiDPI: false,
                rotation: 0,
                positionX: 1440,
                positionY: 0
            )
        ]

        try DeviceDisplayConfigStore.save(configs, to: url)
        let loaded = DeviceDisplayConfigStore.load(from: url)

        XCTAssertEqual(loaded["SERIAL-1"]?.name, "Galaxy Tab")
        XCTAssertEqual(loaded["SERIAL-1"]?.resolutionLabel, "1920x1200")
        XCTAssertEqual(loaded["SERIAL-1"]?.positionX, 1440)
    }

    func testInvalidConfigReturnsEmptyMap() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceDisplayConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("devices.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ invalid json".utf8).write(to: url)

        XCTAssertTrue(DeviceDisplayConfigStore.load(from: url, logErrors: false).isEmpty)
    }

    @available(macOS 14.0, *)
    func testKnownSamsungTabletGetsDeviceSpecificDefaults() {
        let settings = makeDisplaySettings()
        settings.resolution = "2560x1600"
        settings.refreshRate = 90

        let config = DeviceDisplayConfigStore.defaultConfig(
            for: USBDeviceInfo(serial: "TAB-SERIAL", model: "SM_T870"),
            index: 0,
            settings: settings
        )

        XCTAssertEqual(config.name, "Galaxy Tab S7")
        XCTAssertEqual(config.width, 1920)
        XCTAssertEqual(config.height, 1200)
        XCTAssertEqual(config.refreshRate, 60)
        XCTAssertEqual(config.quality, "ultralow")
    }

    @available(macOS 14.0, *)
    func testKnownFoldableGetsDeviceSpecificDefaults() {
        let config = DeviceDisplayConfigStore.defaultConfig(
            for: USBDeviceInfo(serial: "PHONE-SERIAL", model: "SM_F936B"),
            index: 1,
            settings: makeDisplaySettings()
        )

        XCTAssertEqual(config.name, "Galaxy Z Fold 4")
        XCTAssertEqual(config.width, 1600)
        XCTAssertEqual(config.height, 1200)
        XCTAssertEqual(config.bitrate, 800)
    }

    @available(macOS 14.0, *)
    func testSpecCombinesSavedOverridesWithSettingsFallbacks() {
        let settings = makeDisplaySettings()
        settings.resolution = "2560x1440"
        settings.refreshRate = 90
        settings.bitrate = 750
        settings.quality = "medium"
        settings.rotation = 90

        let saved = DeviceDisplayConfig(
            name: "Desk Phone",
            width: 1400,
            height: nil,
            refreshRate: nil,
            bitrate: 500,
            quality: nil,
            hiDPI: true,
            rotation: nil,
            positionX: 320,
            positionY: 40
        )

        let spec = DeviceDisplayConfigStore.spec(
            for: USBDeviceInfo(serial: "SERIAL-1", model: "Pixel"),
            index: 0,
            hostPort: 54321,
            settings: settings,
            savedConfigs: ["SERIAL-1": saved]
        )

        XCTAssertEqual(spec.name, "Desk Phone")
        XCTAssertEqual(spec.width, 1400)
        XCTAssertEqual(spec.height, 2560)
        XCTAssertEqual(spec.refreshRate, 90)
        XCTAssertEqual(spec.bitrate, 500)
        XCTAssertEqual(spec.quality, "medium")
        XCTAssertEqual(spec.hiDPI, true)
        XCTAssertEqual(spec.rotation, 90)
        XCTAssertEqual(spec.positionX, 320)
        XCTAssertEqual(spec.positionY, 40)
    }

    @available(macOS 14.0, *)
    func testDisplaySettingsResetClearsPersistedConnectionMode() {
        let settings = makeDisplaySettings()
        settings.connectionMode = .wireless
        settings.refreshRate = 120

        settings.resetToDefaults()

        XCTAssertEqual(settings.connectionMode, .usb)
        XCTAssertEqual(settings.refreshRate, 60)
    }

    func testVirtualDisplaySerialNumberIsStableAndNonZero() {
        let device = USBDeviceInfo(serial: "ABC123", model: nil)
        let first = spec(for: device).virtualDisplaySerialNumber
        let second = spec(for: device).virtualDisplaySerialNumber

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, 0)
        XCTAssertNotEqual(first, spec(for: USBDeviceInfo(serial: "XYZ999", model: nil)).virtualDisplaySerialNumber)
    }

    @available(macOS 14.0, *)
    private func makeDisplaySettings() -> DisplaySettings {
        let suiteName = "OpenMultiDisplayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return DisplaySettings(defaults: defaults)
    }

    private func spec(for device: USBDeviceInfo) -> DeviceDisplaySpec {
        DeviceDisplaySpec(
            device: device,
            name: "Test",
            hostPort: 54321,
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
}
