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
