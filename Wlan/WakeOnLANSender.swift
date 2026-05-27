import Foundation
import Network

struct WakeOnLANSender {

    enum WOLError: LocalizedError {
        case invalidMAC
        case socketError(String)
        case noNetwork

        var errorDescription: String? {
            switch self {
            case .invalidMAC:
                return String(localized: "error.invalid_mac")
            case .socketError(let msg):
                return String(format: String(localized: "error.network"), msg)
            case .noNetwork:
                return "No Wi-Fi connection"
            }
        }
    }

    static func send(mac: String, port: UInt16 = 9, broadcast: String = "255.255.255.255") async throws {
        let macBytes = try parseMac(mac)
        let packet = buildPacket(macBytes: macBytes)

        // Determine the broadcast address of the current network
        let targetBroadcast = detectBroadcast() ?? broadcast
        print("WoL → sending to \(targetBroadcast):\(port)")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                do {
                    // Send to the subnet broadcast
                    try sendViaBSDSocket(packet: packet, address: targetBroadcast, port: port)

                    // Additionally send to the global broadcast
                    if targetBroadcast != "255.255.255.255" {
                        try? sendViaBSDSocket(packet: packet, address: "255.255.255.255", port: port)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Detect broadcast address

    static func detectBroadcast() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let ifa = ptr?.pointee {
            defer { ptr = ifa.ifa_next }

            // Look for IPv4 addresses on en0 (Wi-Fi on iPhone/iPad)
            guard
                let name = ifa.ifa_name,
                String(cString: name) == "en0",
                ifa.ifa_addr?.pointee.sa_family == UInt8(AF_INET),
                let netmaskPtr = ifa.ifa_netmask,
                let addrPtr = ifa.ifa_addr
            else { continue }

            // Get IP and netmask
            var ipAddr = sockaddr_in()
            var mask = sockaddr_in()
            memcpy(&ipAddr, addrPtr, MemoryLayout<sockaddr_in>.size)
            memcpy(&mask, netmaskPtr, MemoryLayout<sockaddr_in>.size)

            let ip = ipAddr.sin_addr.s_addr
            let nm = mask.sin_addr.s_addr

            // broadcast = (ip & mask) | ~mask
            let broadcast = (ip & nm) | ~nm

            var broadcastAddr = in_addr(s_addr: broadcast)
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &broadcastAddr, &buf, socklen_t(INET_ADDRSTRLEN))
            let result = String(cString: buf)
            print("WoL → detected broadcast: \(result)")
            return result
        }
        return nil
    }

    // MARK: - BSD Socket

    private static func sendViaBSDSocket(packet: Data, address: String, port: UInt16) throws {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else {
            throw WOLError.socketError("socket(): \(String(cString: strerror(errno)))")
        }
        defer { close(sock) }

        var broadcastEnable: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))

        var reuseEnable: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseEnable, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(address)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        let bytesSent = packet.withUnsafeBytes { rawBuf in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    sendto(sock, rawBuf.baseAddress, packet.count, 0,
                           sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard bytesSent == packet.count else {
            throw WOLError.socketError("sendto \(address): \(String(cString: strerror(errno)))")
        }
    }

    // MARK: - Helpers

    private static func parseMac(_ mac: String) throws -> [UInt8] {
        let cleaned = mac
            .replacingOccurrences(of: "-", with: ":")
            .replacingOccurrences(of: ".", with: ":")
        let parts = cleaned.split(separator: ":")
        guard parts.count == 6 else { throw WOLError.invalidMAC }
        return try parts.map { part -> UInt8 in
            guard let byte = UInt8(part, radix: 16) else { throw WOLError.invalidMAC }
            return byte
        }
    }

    private static func buildPacket(macBytes: [UInt8]) -> Data {
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        return packet
    }
}
