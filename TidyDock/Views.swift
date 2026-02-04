import AppKit
import SwiftUI

struct ImageListView: View {
    @StateObject private var viewModel: ImageListViewModel
    @State private var selectedImage: DockerImage?
    @State private var showDeleteConfirm = false
    @State private var selectedImageIds: Set<String> = []
    @State private var showBulkDeleteConfirm = false
    @State private var showDanglingDeleteConfirm = false
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 16)
    ]
    private let cardHeight: CGFloat = 50
    private let leftColumnWidth: CGFloat = 320
    private let middleColumnWidth: CGFloat = 220
    private let rightColumnWidth: CGFloat = 180

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: ImageListViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(title: "Images")
            if viewModel.isLoading {
                ProgressView()
            }
            ScrollView([.vertical, .horizontal]) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.images) { image in
                        ImageCard(
                            image: image,
                            isSelected: selectedImageIds.contains(image.id),
                            onToggleSelection: {
                                toggleSelection(for: image.id)
                            },
                            leftColumnWidth: leftColumnWidth,
                            middleColumnWidth: middleColumnWidth,
                            rightColumnWidth: rightColumnWidth,
                            cardHeight: cardHeight
                        ) {
                            selectedImage = image
                            showDeleteConfirm = true
                        }
                    }
                }
                .padding(.top, 4)
                .frame(minWidth: leftColumnWidth + middleColumnWidth + rightColumnWidth + 64)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
        .confirmationDialog(
            "Delete selected images?",
            isPresented: $showBulkDeleteConfirm
        ) {
            Button("Delete \(selectedImageIds.count) images", role: .destructive) {
                Task { await deleteSelectedImages() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete the selected images?")
        }
        .confirmationDialog(
            "Delete dangling images?",
            isPresented: $showDanglingDeleteConfirm
        ) {
            Button("Delete \(danglingImages.count) images", role: .destructive) {
                Task { await deleteDanglingImages() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove all unused images with <none> name/tag?")
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
            Button("Delete Selected") {
                showBulkDeleteConfirm = true
            }
            .disabled(selectedImageIds.isEmpty)
            .buttonStyle(.bordered)
            .tint(.red.opacity(2))
            Button("Delete Dangling") {
                showDanglingDeleteConfirm = true
            }
            .disabled(danglingImages.isEmpty)
            .buttonStyle(.bordered)
            .tint(.red.opacity(2))
            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
        }
    }

    private func toggleSelection(for id: String) {
        if selectedImageIds.contains(id) {
            selectedImageIds.remove(id)
        } else {
            selectedImageIds.insert(id)
        }
    }

    private func deleteSelectedImages() async {
        let ids = selectedImageIds
        selectedImageIds.removeAll()
        for id in ids {
            await viewModel.deleteImage(id: id)
        }
    }

    private var danglingImages: [DockerImage] {
        viewModel.images.filter { !$0.inUse && ($0.repository == "<none>" || $0.tag == "<none>") }
    }

    private func deleteDanglingImages() async {
        for image in danglingImages {
            await viewModel.deleteImage(id: image.id)
        }
    }

}

struct ContainerListView: View {
    @StateObject private var viewModel: ContainerListViewModel
    @State private var selectedContainer: DockerContainer?
    @State private var showDeleteConfirm = false
    @State private var selectedContainerIds: Set<String> = []
    @State private var showBulkDeleteConfirm = false
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 16)
    ]
    private let cardHeight: CGFloat = 70
    private let leftColumnWidth: CGFloat = 170
    private let middleColumnWidth: CGFloat = 220
    private let rightColumnWidth: CGFloat = 220

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: ContainerListViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(title: "Containers")
            if viewModel.isLoading {
                ProgressView()
            }
            ScrollView([.vertical, .horizontal]) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.containers) { container in
                        ContainerCard(
                            container: container,
                            isSelected: selectedContainerIds.contains(container.id),
                            onToggleSelection: {
                                toggleSelection(for: container.id)
                            },
                            leftColumnWidth: leftColumnWidth,
                            middleColumnWidth: middleColumnWidth,
                            rightColumnWidth: rightColumnWidth,
                            cardHeight: cardHeight
                        ) {
                            selectedContainer = container
                            showDeleteConfirm = true
                        } onStart: {
                            Task { await viewModel.startContainer(id: container.id) }
                        } onStop: {
                            Task { await viewModel.stopContainer(id: container.id) }
                        }
                    }
                }
                .padding(.top, 4)
                .frame(minWidth: leftColumnWidth + middleColumnWidth + rightColumnWidth + 64)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
        .confirmationDialog(
            "Delete selected containers?",
            isPresented: $showBulkDeleteConfirm
        ) {
            Button("Delete \(selectedContainerIds.count) containers", role: .destructive) {
                Task { await deleteSelectedContainers() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete the selected containers?")
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
            Button("Start Selected") {
                Task { await startSelectedContainers() }
            }
            .disabled(selectedContainerIds.isEmpty || !hasStoppedSelected)
            .buttonStyle(.bordered)
            .tint(.blue.opacity(2))
            Button("Stop Selected") {
                Task { await stopSelectedContainers() }
            }
            .disabled(selectedContainerIds.isEmpty || !hasRunningSelected)
            .buttonStyle(.bordered)
            Button("Delete Selected") {
                showBulkDeleteConfirm = true
            }
            .disabled(selectedContainerIds.isEmpty)
            .buttonStyle(.bordered)
            .tint(.red.opacity(2))
            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
        }
    }

    private var selectedContainers: [DockerContainer] {
        viewModel.containers.filter { selectedContainerIds.contains($0.id) }
    }

    private var hasRunningSelected: Bool {
        selectedContainers.contains { $0.state == "running" }
    }

    private var hasStoppedSelected: Bool {
        selectedContainers.contains { $0.state != "running" }
    }

    private func toggleSelection(for id: String) {
        if selectedContainerIds.contains(id) {
            selectedContainerIds.remove(id)
        } else {
            selectedContainerIds.insert(id)
        }
    }

    private func startSelectedContainers() async {
        let ids = selectedContainers.filter { $0.state != "running" }.map(\.id)
        for id in ids {
            await viewModel.startContainer(id: id)
        }
    }

    private func stopSelectedContainers() async {
        let ids = selectedContainers.filter { $0.state == "running" }.map(\.id)
        for id in ids {
            await viewModel.stopContainer(id: id)
        }
    }

    private func deleteSelectedContainers() async {
        let ids = selectedContainerIds
        selectedContainerIds.removeAll()
        for id in ids {
            await viewModel.deleteContainer(id: id)
        }
    }
}

private struct ImageCard: View {
    let image: DockerImage
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let leftColumnWidth: CGFloat
    let middleColumnWidth: CGFloat
    let rightColumnWidth: CGFloat
    let cardHeight: CGFloat
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { _ in onToggleSelection() }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    Text(image.nameWithTag)
                        .font(.headline)
                    Button {
                        copyToClipboard(image.nameWithTag)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy image name")
                }
                Text(truncatedId(image.id))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .draggable(truncatedId(image.id))
            }
            .frame(width: leftColumnWidth, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text("Created:")
                        .foregroundColor(.secondary)
                    Text(image.createdAt.formatted(date: .numeric, time: .shortened))
                }
                HStack {
                    Text("Size:")
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: image.sizeBytes, countStyle: .file))
                }
            }
            .font(.subheadline)
            .frame(width: middleColumnWidth, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Text(image.inUse ? "In Use" : "Unused")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(image.inUse ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(.bordered)
                        .tint(.red.opacity(2))
                }
            }
            .frame(width: rightColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: cardHeight)
        .cardBackground(highlight: image.inUse)
    }

}

private struct ContainerCard: View {
    let container: DockerContainer
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let leftColumnWidth: CGFloat
    let middleColumnWidth: CGFloat
    let rightColumnWidth: CGFloat
    let cardHeight: CGFloat
    let onDelete: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        let isRunning = container.state == "running"
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { _ in onToggleSelection() }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    Text(container.name)
                        .font(.headline)
                }
                Text(truncatedId(container.id))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .draggable(truncatedId(container.id))
                HStack(spacing: 6) {
                    Text(container.imageName)
                        .foregroundColor(.secondary)
                    Button {
                        copyToClipboard(container.imageName)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy image name")
                }
            }
            .frame(width: leftColumnWidth, alignment: .leading)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text(container.command)
                    .lineLimit(1)
                HStack {
                    Text("Ports:")
                        .foregroundColor(.secondary)
                    Text(container.ports.isEmpty ? "-" : container.ports)
                }
            }
            .frame(width: middleColumnWidth, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text("Created:")
                        .foregroundColor(.secondary)
                    Text(container.createdAt.formatted(date: .numeric, time: .shortened))
                }
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Text(container.status)
                }
            }
            .font(.subheadline)
            .frame(width: rightColumnWidth, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 8) {
                Text(container.status)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isRunning ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .clipShape(Capsule())
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue.opacity(2))
                    .disabled(isRunning)
                    Button(action: onStop) {
                        Image(systemName: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isRunning)
                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(.bordered)
                        .tint(.red.opacity(2))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: cardHeight)
        .cardBackground(highlight: isRunning)
    }
}

private struct CardBackground: ViewModifier {
    let highlight: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let baseBackground = colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.24)
        let highlightOverlay = colorScheme == .dark
            ? Color.blue.opacity(0.2)
            : Color.blue.opacity(0.4)

        content
            .background(.thickMaterial)
            .background(baseBackground)
            .background(highlight ? highlightOverlay : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15))
            )
    }
}

private extension View {
    func cardBackground(highlight: Bool) -> some View {
        modifier(CardBackground(highlight: highlight))
    }
}

private func copyToClipboard(_ value: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
}

private func truncatedId(_ value: String) -> String {
    let normalized = value.hasPrefix("sha256:") ? String(value.dropFirst(7)) : value
    return String(normalized.prefix(12))
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
