import Foundation
import Network

protocol DockerService {
    func fetchImages() async throws -> [DockerImage]
    func fetchContainers() async throws -> [DockerContainer]
    func fetchNetworks() async throws -> [DockerNetwork]
    func deleteImage(id: String) async throws
    func deleteContainer(id: String) async throws
    func startContainer(id: String) async throws
    func stopContainer(id: String) async throws
}

enum DockerServiceError: LocalizedError {
    case commandFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .invalidResponse(let message):
            return message
        }
    }
}

final class DockerHTTPService: DockerService {
    private let socketPath: String
    private let client: DockerHTTPClient

    init(socketPath: String = "/Users/changyeol/.colima/default/docker.sock") {
        self.socketPath = socketPath
        self.client = DockerHTTPClient(socketPath: socketPath)
    }

    func fetchImages() async throws -> [DockerImage] {
        let data = try await client.request(method: "GET", path: "/images/json")
        let items = try JSONDecoder().decode([DockerImageItem].self, from: data)
        return items.compactMap { item in
            let repoTags = (item.repoTags ?? []).filter { $0 != "<none>:<none>" }
            let repoDigests = (item.repoDigests ?? []).filter { $0 != "<none>@<none>" }
            guard let name = repoTags.first ?? repoDigests.first else {
                return nil
            }
            let separator = name.contains("@") ? "@" : ":"
            let parts = name.split(separator: Character(separator), maxSplits: 1).map(String.init)
            let repository = parts.first ?? "<none>"
            let tag = parts.count > 1 ? parts[1] : "<none>"
            return DockerImage(
                id: item.id,
                repository: repository,
                tag: tag,
                createdAt: Date(timeIntervalSince1970: TimeInterval(item.created)),
                sizeBytes: item.size,
                inUse: (item.containers ?? 0) > 0
            )
        }
    }

    func fetchContainers() async throws -> [DockerContainer] {
        let data = try await client.request(method: "GET", path: "/containers/json?all=1")
        let items = try JSONDecoder().decode([DockerContainerItem].self, from: data)
        return items.map { item in
            DockerContainer(
                id: item.id,
                imageName: item.image,
                command: item.command,
                createdAt: Date(timeIntervalSince1970: TimeInterval(item.created)),
                status: item.status,
                state: item.state,
                ports: formatPorts(item.ports),
                name: formatName(item.names)
            )
        }
    }

    func fetchNetworks() async throws -> [DockerNetwork] {
        let data = try await client.request(method: "GET", path: "/networks")
        let items = try JSONDecoder().decode([DockerNetworkItem].self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        return items.map { item in
            let createdAt = formatter.date(from: item.created) ?? fallbackFormatter.date(from: item.created)
            let containers = (item.containers ?? [:])
                .map { DockerNetworkContainer(
                    id: $0.key,
                    name: $0.value.name ?? "-",
                    endpointID: $0.value.endpointID ?? "-",
                    macAddress: $0.value.macAddress ?? "-",
                    ipv4Address: $0.value.ipv4Address ?? "-",
                    ipv6Address: $0.value.ipv6Address ?? "-"
                ) }
                .sorted { $0.name < $1.name }
            let ipamConfigs = (item.ipam.config ?? []).enumerated().map { index, config in
                DockerNetworkIPAMConfig(
                    id: "\(item.id)-\(index)",
                    subnet: config.subnet,
                    gateway: config.gateway,
                    ipRange: config.ipRange,
                    auxAddresses: config.auxAddresses ?? [:]
                )
            }

            return DockerNetwork(
                id: item.id,
                name: item.name,
                createdAt: createdAt,
                createdRaw: item.created,
                scope: item.scope,
                driver: item.driver,
                enableIPv4: item.enableIPv4,
                enableIPv6: item.enableIPv6,
                ipam: DockerNetworkIPAM(
                    driver: item.ipam.driver,
                    options: item.ipam.options ?? [:],
                    config: ipamConfigs
                ),
                internalValue: item.internalValue,
                attachable: item.attachable,
                ingress: item.ingress,
                configFrom: DockerNetworkConfigFrom(network: item.configFrom?.network ?? ""),
                configOnly: item.configOnly,
                containers: containers,
                options: item.options ?? [:],
                labels: item.labels ?? [:]
            )
        }
    }

    func deleteImage(id: String) async throws {
        _ = try await client.request(method: "DELETE", path: "/images/\(id)?force=1")
    }

    func deleteContainer(id: String) async throws {
        _ = try await client.request(method: "DELETE", path: "/containers/\(id)?force=1")
    }

    func startContainer(id: String) async throws {
        _ = try await client.request(method: "POST", path: "/containers/\(id)/start")
    }

    func stopContainer(id: String) async throws {
        _ = try await client.request(method: "POST", path: "/containers/\(id)/stop")
    }

    private func formatPorts(_ ports: [DockerContainerItem.Port]) -> String {
        guard !ports.isEmpty else { return "-" }
        return ports.map { port in
            if let publicPort = port.publicPort {
                let ip = port.ip ?? "0.0.0.0"
                return "\(ip):\(publicPort)->\(port.privatePort)/\(port.type)"
            }
            return "\(port.privatePort)/\(port.type)"
        }
        .joined(separator: ", ")
    }

    private func formatName(_ names: [String]) -> String {
        guard let first = names.first else { return "-" }
        return first.hasPrefix("/") ? String(first.dropFirst()) : first
    }
}

private struct DockerImageItem: Decodable {
    let id: String
    let repoTags: [String]?
    let repoDigests: [String]?
    let created: Int
    let size: Int64
    let containers: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case repoDigests = "RepoDigests"
        case created = "Created"
        case size = "Size"
        case containers = "Containers"
    }
}

private struct DockerContainerItem: Decodable {
    struct Port: Decodable {
        let ip: String?
        let privatePort: Int
        let publicPort: Int?
        let type: String

        enum CodingKeys: String, CodingKey {
            case ip = "IP"
            case privatePort = "PrivatePort"
            case publicPort = "PublicPort"
            case type = "Type"
        }
    }

    let id: String
    let image: String
    let command: String
    let created: Int
    let state: String
    let status: String
    let ports: [Port]
    let names: [String]

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case image = "Image"
        case command = "Command"
        case created = "Created"
        case state = "State"
        case status = "Status"
        case ports = "Ports"
        case names = "Names"
    }
}

private struct DockerNetworkItem: Decodable {
    struct IPAM: Decodable {
        struct Config: Decodable {
            let subnet: String?
            let gateway: String?
            let ipRange: String?
            let auxAddresses: [String: String]?

            enum CodingKeys: String, CodingKey {
                case subnet = "Subnet"
                case gateway = "Gateway"
                case ipRange = "IPRange"
                case auxAddresses = "AuxAddresses"
            }
        }

        let driver: String
        let options: [String: String]?
        let config: [Config]?

        enum CodingKeys: String, CodingKey {
            case driver = "Driver"
            case options = "Options"
            case config = "Config"
        }
    }

    struct ConfigFrom: Decodable {
        let network: String

        enum CodingKeys: String, CodingKey {
            case network = "Network"
        }
    }

    struct NetworkContainer: Decodable {
        let name: String?
        let endpointID: String?
        let macAddress: String?
        let ipv4Address: String?
        let ipv6Address: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case endpointID = "EndpointID"
            case macAddress = "MacAddress"
            case ipv4Address = "IPv4Address"
            case ipv6Address = "IPv6Address"
        }
    }

    let name: String
    let id: String
    let created: String
    let scope: String
    let driver: String
    let enableIPv4: Bool?
    let enableIPv6: Bool?
    let ipam: IPAM
    let internalValue: Bool
    let attachable: Bool
    let ingress: Bool
    let configFrom: ConfigFrom?
    let configOnly: Bool
    let containers: [String: NetworkContainer]?
    let options: [String: String]?
    let labels: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case created = "Created"
        case scope = "Scope"
        case driver = "Driver"
        case enableIPv4 = "EnableIPv4"
        case enableIPv6 = "EnableIPv6"
        case ipam = "IPAM"
        case internalValue = "Internal"
        case attachable = "Attachable"
        case ingress = "Ingress"
        case configFrom = "ConfigFrom"
        case configOnly = "ConfigOnly"
        case containers = "Containers"
        case options = "Options"
        case labels = "Labels"
    }
}

final class DockerHTTPClient {
    private let socketPath: String
    private let queue = DispatchQueue(label: "tidydock.docker.http", qos: .utility)
    private let timeoutSeconds: TimeInterval = 3.0
    private let enableDebugLogging = false

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func request(method: String, path: String, body: Data? = nil) async throws -> Data {
        try await withTimeout(timeoutSeconds) { [socketPath, queue] in
            let connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
            defer { connection.cancel() }
            try await self.connect(connection, queue: queue)
            let requestData = self.buildRequest(method: method, path: path, body: body)
            try await self.send(connection, data: requestData)
            let responseData = try await self.receiveAll(connection)

            let response = try self.parseHTTPResponse(responseData)
            guard (200..<300).contains(response.statusCode) else {
                let message = String(data: response.body, encoding: .utf8) ?? "HTTP \(response.statusCode)"
                throw DockerServiceError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return response.body
        }
    }

    private func buildRequest(method: String, path: String, body: Data?) -> Data {
        let bodyData = body ?? Data()
        var header = "\(method) \(path) HTTP/1.1\r\n"
        header += "Host: docker\r\n"
        header += "User-Agent: TidyDock\r\n"
        header += "Connection: close\r\n"
        header += "Content-Length: \(bodyData.count)\r\n\r\n"
        var data = Data(header.utf8)
        data.append(bodyData)
        return data
    }

    private func connect(_ connection: NWConnection, queue: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: ())
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send(_ connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func receiveAll(_ connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            var buffer = Data()
            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let data, !data.isEmpty {
                        buffer.append(data)
                    }
                    if isComplete {
                        continuation.resume(returning: buffer)
                    } else {
                        receiveNext()
                    }
                }
            }
            receiveNext()
        }
    }

    private func parseHTTPResponse(_ data: Data) throws -> HTTPResponse {
        let separator = Data("\r\n\r\n".utf8)
        let fallbackSeparator = Data("\n\n".utf8)
        let separatorRange = data.range(of: separator) ?? data.range(of: fallbackSeparator)
        guard let separatorRange else {
            throw DockerServiceError.invalidResponse("Missing header separator")
        }
        let headerData = data[..<separatorRange.lowerBound]
        let bodyData = data[separatorRange.upperBound...]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw DockerServiceError.invalidResponse("Invalid header encoding")
        }

        var lines = headerText
            .split(whereSeparator: { $0.isNewline })
            .map(String.init)
        guard let statusLine = lines.first else {
            throw DockerServiceError.invalidResponse("Missing status line")
        }
        let statusParts = statusLine.split(separator: " ")
        guard statusParts.count >= 2, let statusCode = Int(statusParts[1]) else {
            throw DockerServiceError.invalidResponse("Invalid status line")
        }
        lines.removeFirst()

        var headers: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let finalBody: Data
        if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            finalBody = try decodeChunkedBody(bodyData)
        } else {
            finalBody = Data(bodyData)
        }

        if enableDebugLogging {
            let headerPreview = headerText
                .split(whereSeparator: { $0.isNewline })
                .prefix(6)
                .joined(separator: " | ")
            print("[DockerHTTP] status=\(statusCode) headers=\(headers.count) head=\(headerPreview)")
            print("[DockerHTTP] body-bytes=\(finalBody.count)")
        }

        return HTTPResponse(statusCode: statusCode, headers: headers, body: finalBody)
    }

    private func decodeChunkedBody(_ data: Data) throws -> Data {
        var cursor = data.startIndex
        var output = Data()

        while cursor < data.endIndex {
            guard let lineEnd = data[cursor...].range(of: Data("\r\n".utf8)) else {
                break
            }
            let sizeLineData = data[cursor..<lineEnd.lowerBound]
            guard let sizeLine = String(data: sizeLineData, encoding: .utf8),
                  let size = Int(sizeLine.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16) else {
                throw DockerServiceError.invalidResponse("Invalid chunk size")
            }
            cursor = lineEnd.upperBound
            if size == 0 {
                break
            }
            let chunkEnd = data.index(cursor, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
            output.append(data[cursor..<chunkEnd])
            cursor = chunkEnd
            if let nextLineEnd = data[cursor...].range(of: Data("\r\n".utf8)) {
                cursor = nextLineEnd.upperBound
            } else {
                break
            }
        }
        return output
    }
}

private func withTimeout<T>(_ seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw DockerServiceError.commandFailed("Request timed out after \(Int(seconds))s.")
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

private struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

final class MockDockerService: DockerService {
    func fetchImages() async throws -> [DockerImage] {
        return [
            DockerImage(
                id: "sha256:1a2b3c4d5e",
                repository: "nginx",
                tag: "latest",
                createdAt: Date().addingTimeInterval(-86400 * 3),
                sizeBytes: 134_217_728,
                inUse: true
            ),
            DockerImage(
                id: "sha256:9f8e7d6c5b",
                repository: "redis",
                tag: "7.2",
                createdAt: Date().addingTimeInterval(-86400 * 30),
                sizeBytes: 69_206_016,
                inUse: false
            )
        ]
    }

    func fetchContainers() async throws -> [DockerContainer] {
        return [
            DockerContainer(
                id: "f1e2d3c4b5",
                imageName: "nginx:latest",
                command: "nginx -g 'daemon off;'",
                createdAt: Date().addingTimeInterval(-3600 * 12),
                status: "running",
                state: "running",
                ports: "0.0.0.0:8080->80/tcp",
                name: "web-nginx"
            ),
            DockerContainer(
                id: "a1b2c3d4e5",
                imageName: "redis:7.2",
                command: "redis-server",
                createdAt: Date().addingTimeInterval(-86400 * 2),
                status: "exited",
                state: "exited",
                ports: "",
                name: "cache-redis"
            )
        ]
    }

    func fetchNetworks() async throws -> [DockerNetwork] {
        return [
            DockerNetwork(
                id: "5230cd48db94a630ae2d6ba5d821a757e52221ac150a3045687ab43aad5a6049",
                name: "bridge",
                createdAt: Date().addingTimeInterval(-86400 * 3),
                createdRaw: "2026-02-02T11:21:26.862086378+09:00",
                scope: "local",
                driver: "bridge",
                enableIPv4: true,
                enableIPv6: false,
                ipam: DockerNetworkIPAM(
                    driver: "default",
                    options: [:],
                    config: [
                        DockerNetworkIPAMConfig(
                            id: "bridge-0",
                            subnet: "172.17.0.0/16",
                            gateway: "172.17.0.1",
                            ipRange: nil,
                            auxAddresses: [:]
                        )
                    ]
                ),
                internalValue: false,
                attachable: false,
                ingress: false,
                configFrom: DockerNetworkConfigFrom(network: ""),
                configOnly: false,
                containers: [],
                options: [
                    "com.docker.network.bridge.default_bridge": "true",
                    "com.docker.network.bridge.name": "docker0"
                ],
                labels: [:]
            )
        ]
    }

    func deleteImage(id: String) async throws {}
    func deleteContainer(id: String) async throws {}
    func startContainer(id: String) async throws {}
    func stopContainer(id: String) async throws {}
}
