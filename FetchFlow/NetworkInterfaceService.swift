//
//  NetworkInterfaceService.swift
//  FetchFlow
//
//  Native macOS network topology and interface observer.
//  Detects active VPN tunnels (WireGuard, OpenVPN, ProtonVPN, etc.) via NWPathMonitor
//  and BSD getifaddrs, filtering out internal Apple link-local interfaces.
//

import Foundation
import Network
import Combine

public struct NetworkInterfaceInfo: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let ipAddress: String
    public let isVPN: Bool
    public let isPointToPoint: Bool
}

@MainActor
public final class NetworkInterfaceService: ObservableObject {
    public static let shared = NetworkInterfaceService()

    @Published public private(set) var availableInterfaces: [NetworkInterfaceInfo] = []
    @Published public private(set) var activeVPN: NetworkInterfaceInfo?
    @Published public private(set) var isConnectedToVPN: Bool = false
    @Published public private(set) var lastDetectedRouteInterface: String? = nil

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.fetchflow.networkmonitor", qos: .utility)
    private var isMonitoring = false

    public var onInterfaceTopologyChanged: ((_ newVPN: NetworkInterfaceInfo?, _ allInterfaces: [NetworkInterfaceInfo]) -> Void)?

    private init() {
        refreshInterfaces()
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func refreshInterfaces() {
        let scanned = Self.scanInterfaces()
        self.availableInterfaces = scanned
        let vpn = scanned.first(where: { $0.isVPN })
        let vpnChanged = (vpn?.name != self.activeVPN?.name)
        self.activeVPN = vpn
        self.isConnectedToVPN = (vpn != nil)

        if vpnChanged {
            onInterfaceTopologyChanged?(vpn, scanned)
        }
    }

    private func handlePathUpdate(_ path: NWPath) {
        let oldVPN = self.activeVPN?.name
        let scanned = Self.scanInterfaces()
        self.availableInterfaces = scanned
        let vpn = scanned.first(where: { $0.isVPN })
        self.activeVPN = vpn
        self.isConnectedToVPN = (vpn != nil)

        if oldVPN != vpn?.name {
            onInterfaceTopologyChanged?(vpn, scanned)
        }
    }

    /// Resolves the interface name to bind to based on user preferences.
    /// - Parameter mode: "auto_vpn", "any", or a specific interface name.
    /// - Returns: Interface name (e.g. "utun4") or nil if unbound (0.0.0.0 / all interfaces).
    public func resolveBoundInterface(mode: String) -> String? {
        refreshInterfaces()
        switch mode {
        case "auto_vpn":
            // VPN Preferred: If VPN is active, use it; otherwise nil (any/direct)
            return activeVPN?.name
        case "any":
            return nil
        default:
            // Explicit interface selection (e.g. "utun4" or "en0")
            if availableInterfaces.contains(where: { $0.name == mode }) {
                return mode
            }
            return mode
        }
    }

    // MARK: - BSD Interface Scanning

    public static func scanInterfaces() -> [NetworkInterfaceInfo] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ip4Map: [String: (ip: String, isP2P: Bool)] = [:]
        var ip6Map: [String: (ip: String, isP2P: Bool)] = [:]

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let name = String(cString: ptr.pointee.ifa_name)
            guard let addr = ptr.pointee.ifa_addr else { continue }
            let family = addr.pointee.sa_family

            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isP2P = (flags & IFF_POINTOPOINT) != 0

            guard isUp, isRunning, !isLoopback else { continue }

            if family == UInt8(AF_INET) {
                var addr4 = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr4, &buffer, socklen_t(INET_ADDRSTRLEN))
                let ip = String(cString: buffer)
                if !ip.isEmpty && ip != "0.0.0.0" {
                    ip4Map[name] = (ip, isP2P)
                }
            } else if family == UInt8(AF_INET6) {
                var addr6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                inet_ntop(AF_INET6, &addr6, &buffer, socklen_t(INET6_ADDRSTRLEN))
                let ip = String(cString: buffer)
                // Filter out link-local addresses (fe80::)
                if !ip.isEmpty && !ip.lowercased().hasPrefix("fe80:") {
                    ip6Map[name] = (ip, isP2P)
                }
            }
        }

        var results: [NetworkInterfaceInfo] = []
        let allNames = Set(ip4Map.keys).union(ip6Map.keys)

        for name in allNames {
            let (ip, isP2P) = ip4Map[name] ?? ip6Map[name] ?? ("", false)
            guard !ip.isEmpty else { continue }

            let isVPNPrefix = name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("tap") ||
                              name.hasPrefix("ppp") || name.hasPrefix("ipsec") || name.hasPrefix("wg")
            let isVPN = isVPNPrefix || isP2P

            let displayName: String
            if isVPN {
                displayName = "VPN Tunnel (\(name))"
            } else if name.hasPrefix("en") {
                displayName = name == "en0" ? "Wi-Fi (\(name))" : "Ethernet (\(name))"
            } else {
                displayName = "Interface (\(name))"
            }

            results.append(NetworkInterfaceInfo(
                name: name,
                displayName: displayName,
                ipAddress: ip,
                isVPN: isVPN,
                isPointToPoint: isP2P
            ))
        }

        return results.sorted { lhs, rhs in
            if lhs.isVPN != rhs.isVPN {
                return lhs.isVPN && !rhs.isVPN
            }
            return lhs.name < rhs.name
        }
    }
}
