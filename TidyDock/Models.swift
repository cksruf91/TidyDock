import Foundation

struct DockerImage: Identifiable, Hashable {
    let id: String
    let repository: String
    let tag: String
    let createdAt: Date
    let sizeBytes: Int64
    let inUse: Bool

    var nameWithTag: String {
        "\(repository):\(tag)"
    }
}

struct DockerContainer: Identifiable, Hashable {
    let id: String
    let imageName: String
    let command: String
    let createdAt: Date
    let status: String
    let state: String
    let ports: String
    let name: String
}

struct DockerNetwork: Identifiable {
    let id: String
    let name: String
    let createdAt: Date?
    let createdRaw: String
    let scope: String
    let driver: String
    let enableIPv4: Bool?
    let enableIPv6: Bool?
    let ipam: DockerNetworkIPAM
    let internalValue: Bool
    let attachable: Bool
    let ingress: Bool
    let configFrom: DockerNetworkConfigFrom
    let configOnly: Bool
    let containers: [DockerNetworkContainer]
    let options: [String: String]
    let labels: [String: String]
}

struct DockerNetworkIPAM {
    let driver: String
    let options: [String: String]
    let config: [DockerNetworkIPAMConfig]
}

struct DockerNetworkIPAMConfig: Identifiable {
    let id: String
    let subnet: String?
    let gateway: String?
    let ipRange: String?
    let auxAddresses: [String: String]
}

struct DockerNetworkConfigFrom {
    let network: String
}

struct DockerNetworkContainer: Identifiable {
    let id: String
    let name: String
    let endpointID: String
    let macAddress: String
    let ipv4Address: String
    let ipv6Address: String
}
