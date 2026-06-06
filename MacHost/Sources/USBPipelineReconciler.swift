import Foundation

struct USBPipelineReconciliation: Equatable {
    let disconnectedSerials: [String]
    let remainingSerials: [String]

    var allPipelinesDisconnected: Bool {
        remainingSerials.isEmpty
    }
}

enum USBPipelineReconciler {
    static func reconcile(activeSerials: [String], connectedSerials: [String]) -> USBPipelineReconciliation {
        let connectedSerialSet = Set(connectedSerials)
        let disconnectedSerials = activeSerials
            .filter { !connectedSerialSet.contains($0) }
            .sorted()
        let remainingSerials = activeSerials
            .filter { connectedSerialSet.contains($0) }
            .sorted()

        return USBPipelineReconciliation(
            disconnectedSerials: disconnectedSerials,
            remainingSerials: remainingSerials
        )
    }
}
