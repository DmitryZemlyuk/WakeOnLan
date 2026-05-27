import Foundation
import Network

enum DeviceReachability {

    static func ping(host: String, port: UInt16 = 9) async -> Bool {

        guard !host.isEmpty else {
            return false
        }

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

            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {

                if !resumed {
                    resumed = true
                    continuation.resume(returning: false)
                    connection.cancel()
                }
            }
        }
    }
}
