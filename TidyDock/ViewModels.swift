import Combine
import Foundation

@MainActor
final class ImageListViewModel: ObservableObject {
    @Published var images: [DockerImage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: DockerService

    init(service: DockerService) {
        self.service = service
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            images = try await service.fetchImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteImage(id: String) async {
        do {
            try await service.deleteImage(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ContainerListViewModel: ObservableObject {
    @Published var containers: [DockerContainer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: DockerService

    init(service: DockerService) {
        self.service = service
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            containers = try await service.fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteContainer(id: String) async {
        do {
            try await service.deleteContainer(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startContainer(id: String) async {
        do {
            try await service.startContainer(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopContainer(id: String) async {
        do {
            try await service.stopContainer(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class NetworkListViewModel: ObservableObject {
    @Published var networks: [DockerNetwork] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: DockerService

    init(service: DockerService) {
        self.service = service
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            networks = sortNetworks(try await service.fetchNetworks())
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func sortNetworks(_ items: [DockerNetwork]) -> [DockerNetwork] {
        items.sorted { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (left?, right?):
                if left != right {
                    return left > right
                }
            case (nil, nil):
                if lhs.createdRaw != rhs.createdRaw {
                    return lhs.createdRaw > rhs.createdRaw
                }
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

@MainActor
final class SystemDiskUsageViewModel: ObservableObject {
    @Published var usage: DockerSystemDiskUsage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: DockerService

    init(service: DockerService) {
        self.service = service
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            usage = try await service.fetchSystemDiskUsage()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
