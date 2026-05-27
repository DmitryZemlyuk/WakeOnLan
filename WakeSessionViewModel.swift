import Foundation
import SwiftUI

@MainActor
final class WakeSessionViewModel: ObservableObject {

    @Published var state: WakeState = .idle

    func wake(device: Device) async {

        state = .waking

        do {
            try await WakeOnLANSender.send(
                macAddress: device.mac,
                broadcastIP: device.broadcast,
                port: Int(device.port) ?? 9
            )

            try? await Task.sleep(for: .seconds(5))

            let online = await DeviceReachability.ping(
                host: device.host,
                port: UInt16(Int(device.port) ?? 9)
            )

            state = online
                ? .success
                : .failed("Offline")

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        } catch {

            state = .failed(error.localizedDescription)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
