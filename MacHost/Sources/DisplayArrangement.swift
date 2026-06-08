import CoreGraphics
import Foundation

enum DisplayArrangement {
    static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var error = CGGetOnlineDisplayList(0, nil, &displayCount)
        guard error == .success, displayCount > 0 else {
            if error != .success {
                debugLog("CGGetOnlineDisplayList count failed: \(error)")
            }
            return []
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        error = CGGetOnlineDisplayList(displayCount, &displays, &displayCount)
        guard error == .success else {
            debugLog("CGGetOnlineDisplayList values failed: \(error)")
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    static func onlineDisplayBounds(excluding excludedIDs: Set<CGDirectDisplayID> = []) -> [CGRect] {
        onlineDisplayIDs()
            .filter { !excludedIDs.contains($0) }
            .map(CGDisplayBounds)
            .filter { !$0.isNull && !$0.isEmpty }
    }

    static func mainDisplayBounds() -> CGRect {
        CGDisplayBounds(CGMainDisplayID())
    }

    static func desktopUnion(of displayBounds: [CGRect]) -> CGRect? {
        displayBounds.reduce(nil) { partialUnion, bounds in
            guard let partialUnion else { return bounds }
            return partialUnion.union(bounds)
        }
    }

    static func fallbackOrigins(
        existingDisplayBounds: [CGRect],
        anchorDisplayBounds: CGRect?,
        virtualDisplaySizes: [CGSize],
        spacing: Int
    ) -> [CGPoint] {
        guard !virtualDisplaySizes.isEmpty else { return [] }

        let desktopBounds = desktopUnion(of: existingDisplayBounds)
        var nextX = Int(ceil(desktopBounds?.maxX ?? 0))
        if desktopBounds != nil {
            nextX += spacing
        }

        let fallbackY = Int(anchorDisplayBounds?.minY ?? desktopBounds?.minY ?? 0)

        return virtualDisplaySizes.map { size in
            let origin = CGPoint(x: nextX, y: fallbackY)
            nextX += Int(ceil(size.width)) + spacing
            return origin
        }
    }
}
