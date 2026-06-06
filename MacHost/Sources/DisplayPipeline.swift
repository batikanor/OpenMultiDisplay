import Foundation
import CoreGraphics

@available(macOS 14.0, *)
final class DisplayPipeline {
    let spec: DeviceDisplaySpec

    private let virtualDisplayManager = VirtualDisplayManager()
    private var screenCapture: ScreenCapture?
    private var streamingServer: StreamingServer?

    var onClientCountChanged: ((Int) -> Void)?
    var onStats: ((Double, Double) -> Void)?
    var onCaptureMethodChanged: ((String) -> Void)?
    var onTouchEvent: ((CGDirectDisplayID, Float, Float, Int, Int, Float, Float) -> Void)?

    init(spec: DeviceDisplaySpec) {
        self.spec = spec
    }

    var displayID: CGDirectDisplayID? {
        virtualDisplayManager.displayID
    }

    func start(touchEnabled: Bool) async throws {
        debugLog("Starting pipeline for \(spec.device.serial) on host port \(spec.hostPort): \(spec.width)x\(spec.height)")

        try virtualDisplayManager.createDisplay(
            width: spec.width,
            height: spec.height,
            refreshRate: spec.refreshRate,
            hiDPI: spec.hiDPI,
            name: "TetherSpan - \(spec.name)",
            serialNumber: spec.virtualDisplaySerialNumber
        )

        do {
            try virtualDisplayManager.disableMirrorMode()
        } catch {
            debugLog("Mirror disable skipped for \(spec.device.serial): \(error.localizedDescription)")
        }

        if let x = spec.positionX, let y = spec.positionY {
            do {
                try virtualDisplayManager.setDisplayPosition(x: Int32(x), y: Int32(y))
            } catch {
                debugLog("Failed to set position for \(spec.device.serial): \(error.localizedDescription)")
            }
        }

        if !virtualDisplayManager.verifyDisplayRegistered() {
            debugLog("WARNING: virtual display for \(spec.device.serial) not found in online display list")
        }

        guard let displayID = virtualDisplayManager.displayID else {
            throw NSError(
                domain: "DisplayPipeline",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Virtual display ID missing for \(spec.device.serial)"]
            )
        }

        let capture = try await ScreenCapture()
        capture.onCaptureMethodChanged = { [weak self] method in
            guard let self else { return }
            debugLog("Capture method for \(self.spec.device.serial): \(method)")
            self.onCaptureMethodChanged?(method)
        }
        try await capture.setupForVirtualDisplay(displayID, refreshRate: spec.refreshRate)

        let server = StreamingServer(port: spec.hostPort)
        server.touchEnabled = touchEnabled
        server.setDisplaySize(width: spec.width, height: spec.height, rotation: spec.rotation)
        server.onClientConnected = { [weak capture] in
            capture?.requestKeyframeOrReplayCachedFrame(force: true)
        }
        server.onClientCountChanged = { [weak self] count in
            self?.onClientCountChanged?(count)
        }
        server.onKeyframeRequested = { [weak capture] force in
            capture?.requestKeyframeOrReplayCachedFrame(force: force)
        }
        server.onTouchEvent = { [weak self] x, y, action, pointerCount, x2, y2 in
            guard let self, let displayID = self.virtualDisplayManager.displayID else { return }
            self.onTouchEvent?(displayID, x, y, action, pointerCount, x2, y2)
        }
        server.onStats = { [weak self] fps, mbps in
            self?.onStats?(fps, mbps)
        }

        server.start()
        capture.startStreaming(
            to: server,
            bitrateMbps: spec.bitrate,
            quality: spec.quality,
            gamingBoost: false,
            frameRate: spec.refreshRate
        )

        streamingServer = server
        screenCapture = capture
    }

    func stop() {
        screenCapture?.stopStreaming()
        streamingServer?.stop()
        virtualDisplayManager.destroyDisplay()
        screenCapture = nil
        streamingServer = nil
    }

    func updateEncoderSettings(bitrateMbps: Int, quality: String, gamingBoost: Bool) {
        screenCapture?.updateEncoderSettings(bitrateMbps: bitrateMbps, quality: quality, gamingBoost: gamingBoost)
    }

    func updateRotation(_ rotation: Int) {
        streamingServer?.updateRotation(rotation)
    }

    func setTouchEnabled(_ enabled: Bool) {
        streamingServer?.touchEnabled = enabled
    }
}
