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
}
