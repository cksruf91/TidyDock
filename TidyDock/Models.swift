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
    let ports: String
    let name: String
}
