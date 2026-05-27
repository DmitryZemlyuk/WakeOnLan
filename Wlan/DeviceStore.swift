import Foundation
import SwiftUI
import Combine
import Network

struct Device: Identifiable, Codable {

    var id = UUID()

    var name: String
    var host: String
    var mac: String

    var port: String
    var checkPort: String

    var broadcast: String
}

enum WakeState: Equatable {
    case idle
    case waking
    case success
    case failed(String)

    var caption: String {
        switch self {
        case .idle: return "Idle"
        case .waking: return "Checking..."
        case .success: return "Online"
        case .failed(let error): return error
        }
    }
}

enum DeviceReachability {

    static func ping(host: String, port: UInt16 = 9) async -> Bool {

        guard !host.isEmpty else { return false }

        return await withCheckedContinuation { continuation in

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            var resumed = false

            connection.stateUpdateHandler = { state in

                switch state {

                case .ready:

                    if !resumed {
                        resumed = true
                        continuation.resume(returning: true)
                    }

                    connection.cancel()

                case .failed(_):

                    if !resumed {
                        resumed = true
                        continuation.resume(returning: false)
                    }

                    connection.cancel()

                default:
                    break
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {

                if !resumed {
                    resumed = true
                    continuation.resume(returning: false)
                    connection.cancel()
                }
            }
        }
    }
}

@MainActor
final class DeviceStore: ObservableObject {

    @Published var devices: [Device] = []
    @Published var statuses: [UUID: WakeState] = [:]

    private let saveKey = "SavedDevices"

    init() {
        load()
    }

    func add(_ device: Device) {
        devices.append(device)
        save()
    }

    func update(_ device: Device) {

        guard let index = devices.firstIndex(where: { $0.id == device.id }) else {
            return
        }

        devices[index] = device
        save()
    }

    func delete(at offsets: IndexSet) {

        if let index = offsets.first {
            devices.remove(at: index)
        }

        save()
    }

    func refreshStatus(for device: Device) async {

        statuses[device.id] = .waking

        let online = await DeviceReachability.ping(
            host: device.host,
            port: UInt16(Int(device.checkPort) ?? 3389)
        )

        statuses[device.id] = online
            ? .success
            : .failed("Offline")
    }

    func refreshAllStatuses() async {

        for device in devices {
            await refreshStatus(for: device)
        }
    }

    private func save() {

        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {

        guard
            let data = UserDefaults.standard.data(forKey: saveKey),
            let decoded = try? JSONDecoder().decode([Device].self, from: data)
        else {
            return
        }

        devices = decoded
    }
}
