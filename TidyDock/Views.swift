import SwiftUI

struct ImageListView: View {
    @StateObject private var viewModel: ImageListViewModel
    @State private var selectedImage: DockerImage?
    @State private var showDeleteConfirm = false

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: ImageListViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading) {
            header(title: "Images")
            if viewModel.isLoading {
                ProgressView()
            }
            Table(viewModel.images) {
                TableColumn("Name") { image in
                    Text(image.nameWithTag)
                }
                TableColumn("ID") { image in
                    Text(image.id)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                TableColumn("Created") { image in
                    Text(image.createdAt.formatted(date: .numeric, time: .shortened))
                }
                TableColumn("Size") { image in
                    Text(ByteCountFormatter.string(fromByteCount: image.sizeBytes, countStyle: .file))
                }
                TableColumn("In Use") { image in
                    Text(image.inUse ? "Yes" : "No")
                }
                TableColumn("Actions") { image in
                    Button("Delete") {
                        selectedImage = image
                        showDeleteConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .width(min: 90)
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .task {
            await viewModel.refresh()
        }
        .confirmationDialog(
            "Delete image?",
            isPresented: $showDeleteConfirm,
            presenting: selectedImage
        ) { image in
            Button("Delete \(image.nameWithTag)", role: .destructive) {
                Task { await viewModel.deleteImage(id: image.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { image in
            Text("Are you sure you want to delete \(image.nameWithTag)?")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private func header(title: String) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .bold()
            Spacer()
            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
        }
    }
}

struct ContainerListView: View {
    @StateObject private var viewModel: ContainerListViewModel
    @State private var selectedContainer: DockerContainer?
    @State private var showDeleteConfirm = false

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: ContainerListViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading) {
            header(title: "Containers")
            if viewModel.isLoading {
                ProgressView()
            }
            Table(viewModel.containers) {
                TableColumn("Name") { container in
                    Text(container.name)
                }
                TableColumn("ID") { container in
                    Text(container.id)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                TableColumn("Image") { container in
                    Text(container.imageName)
                }
                TableColumn("Command") { container in
                    Text(container.command)
                }
                TableColumn("Created") { container in
                    Text(container.createdAt.formatted(date: .numeric, time: .shortened))
                }
                TableColumn("Status") { container in
                    Text(container.status)
                }
                TableColumn("Ports") { container in
                    Text(container.ports.isEmpty ? "-" : container.ports)
                }
                TableColumn("Actions") { container in
                    HStack(spacing: 6) {
                        Button("Start") {
                            Task { await viewModel.startContainer(id: container.id) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(container.status == "running")

                        Button("Stop") {
                            Task { await viewModel.stopContainer(id: container.id) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(container.status != "running")

                        Button("Delete") {
                            selectedContainer = container
                            showDeleteConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .width(min: 220)
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .task {
            await viewModel.refresh()
        }
        .confirmationDialog(
            "Delete container?",
            isPresented: $showDeleteConfirm,
            presenting: selectedContainer
        ) { container in
            Button("Delete \(container.name)", role: .destructive) {
                Task { await viewModel.deleteContainer(id: container.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Are you sure you want to delete \(container.name)?")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private func header(title: String) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .bold()
            Spacer()
            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
        }
    }
}

#Preview {
    let service = MockDockerService()
    return TabView {
        ImageListView(service: service)
            .tabItem { Text("Images") }
        ContainerListView(service: service)
            .tabItem { Text("Containers") }
    }
    .frame(width: 980, height: 640)
}
