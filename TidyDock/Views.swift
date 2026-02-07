import AppKit
import SwiftUI

struct ImageListView: View {
    @StateObject private var viewModel: ImageListViewModel
    @State private var selectedImage: DockerImage?
    @State private var showDeleteConfirm = false
    @State private var selectedImageIds: Set<String> = []
    @State private var showBulkDeleteConfirm = false
    @State private var showDanglingDeleteConfirm = false
    @State private var lastCopiedImageId: String?
    @State private var showErrorAlert = false
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
                            isCopied: lastCopiedImageId == image.id,
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
                        } onCopy: {
                            copyToClipboard(image.nameWithTag)
                            withAnimation(.easeOut(duration: 0.2)) {
                                lastCopiedImageId = image.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if lastCopiedImageId == image.id {
                                    withAnimation(.easeIn(duration: 0.2)) {
                                        lastCopiedImageId = nil
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .frame(minWidth: leftColumnWidth + middleColumnWidth + rightColumnWidth + 64)
            }
        }
        .padding()
        .tidyPanelBackground()
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
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
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
            .deleteButtonStyle()
            Button("Delete Dangling") {
                showDanglingDeleteConfirm = true
            }
            .disabled(danglingImages.isEmpty)
            .deleteButtonStyle()
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
    @State private var lastCopiedContainerId: String?
    @State private var showErrorAlert = false
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 16)
    ]
    private let cardHeight: CGFloat = 70
    private let leftColumnWidth: CGFloat = 250
    private let middleColumnWidth: CGFloat = 250
    private let rightColumnWidth: CGFloat = 180

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
                            isCopied: lastCopiedContainerId == container.id,
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
                        } onCopy: {
                            copyToClipboard(container.imageName)
                            withAnimation(.easeOut(duration: 0.2)) {
                                lastCopiedContainerId = container.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if lastCopiedContainerId == container.id {
                                    withAnimation(.easeIn(duration: 0.2)) {
                                        lastCopiedContainerId = nil
                                    }
                                }
                            }
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
        .tidyPanelBackground()
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
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
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
            .deleteButtonStyle()
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

struct NetworkListView: View {
    @StateObject private var viewModel: NetworkListViewModel
    @State private var showErrorAlert = false
    private let cardWidth: CGFloat = 260
    private let gridSpacing: CGFloat = 16

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: NetworkListViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(title: "Networks")
            if viewModel.isLoading {
                ProgressView()
            }
            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width, cardWidth)
                let columnCount = max(1, Int((availableWidth + gridSpacing) / (cardWidth + gridSpacing)))
                let columns = Array(
                    repeating: GridItem(.fixed(cardWidth), spacing: gridSpacing),
                    count: columnCount
                )
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(viewModel.networks) { network in
                            NetworkCard(network: network, width: cardWidth)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .tidyPanelBackground()
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
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

struct SystemDiskUsageView: View {
    @StateObject private var viewModel: SystemDiskUsageViewModel
    @State private var showErrorAlert = false
    private let summaryColumns = [
        GridItem(.flexible(minimum: 0), spacing: 16),
        GridItem(.flexible(minimum: 0), spacing: 16)
    ]

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: SystemDiskUsageViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(title: "Disk Usage")
            if viewModel.isLoading {
                ProgressView()
            }
            if let usage = viewModel.usage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: summaryColumns, spacing: 16) {
                            SystemUsageCard(
                                title: "Images",
                                totalCount: usage.imageSummary.totalCount,
                                activeCount: usage.imageSummary.activeCount,
                                totalSize: usage.imageSummary.totalSizeBytes,
                                reclaimableSize: usage.imageSummary.reclaimableBytes
                            )
                            SystemUsageCard(
                                title: "Containers",
                                totalCount: usage.containerSummary.totalCount,
                                activeCount: usage.containerSummary.activeCount,
                                totalSize: usage.containerSummary.totalSizeBytes,
                                reclaimableSize: usage.containerSummary.reclaimableBytes
                            )
                            SystemUsageCard(
                                title: "Volumes",
                                totalCount: usage.volumeSummary.totalCount,
                                activeCount: usage.volumeSummary.activeCount,
                                totalSize: usage.volumeSummary.totalSizeBytes,
                                reclaimableSize: usage.volumeSummary.reclaimableBytes
                            )
                            SystemUsageCard(
                                title: "Build Cache",
                                totalCount: usage.buildCacheSummary.totalCount,
                                activeCount: usage.buildCacheSummary.activeCount,
                                totalSize: usage.buildCacheSummary.totalSizeBytes,
                                reclaimableSize: usage.buildCacheSummary.reclaimableBytes
                            )
                        }

                        SystemUsageDetailCard(
                            title: "Highlights",
                            items: highlightRows(for: usage)
                        )

                        SystemUsageDetailCard(
                            title: "Top Reclaimable",
                            items: topReclaimableRows(for: usage)
                        )
                    }
                    .padding(.top, 4)
                }
            } else if !viewModel.isLoading {
                Text("No disk usage data available.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .tidyPanelBackground()
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
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

    private func highlightRows(for usage: DockerSystemDiskUsage) -> [SystemUsageRow] {
        let imageTop = usage.images.max { $0.effectiveSizeBytes < $1.effectiveSizeBytes }
        let containerTop = usage.containers.max { $0.sizeRootFsBytes < $1.sizeRootFsBytes }
        let volumeTop = usage.volumes.max { $0.sizeBytes < $1.sizeBytes }
        let totalSize = usage.imageSummary.totalSizeBytes
            + usage.containerSummary.totalSizeBytes
            + usage.volumeSummary.totalSizeBytes
            + usage.buildCacheSummary.totalSizeBytes

        return [
            SystemUsageRow(
                title: "Total footprint",
                value: formatBytes(totalSize),
                detail: "Layers: \(formatBytes(usage.layersSize))"
            ),
            SystemUsageRow(
                title: "Largest image",
                value: formatBytes(imageTop?.effectiveSizeBytes ?? 0),
                detail: imageTop?.displayName ?? "-"
            ),
            SystemUsageRow(
                title: "Largest container",
                value: formatBytes(containerTop?.sizeRootFsBytes ?? 0),
                detail: containerTop?.name ?? "-"
            ),
            SystemUsageRow(
                title: "Largest volume",
                value: formatBytes(volumeTop?.sizeBytes ?? 0),
                detail: volumeTop?.name ?? "-"
            )
        ]
    }

    private func topReclaimableRows(for usage: DockerSystemDiskUsage) -> [SystemUsageRow] {
        let unusedImages = usage.images
            .filter { $0.containers == 0 }
            .sorted { $0.effectiveSizeBytes > $1.effectiveSizeBytes }
            .prefix(3)
            .map {
                SystemUsageRow(
                    title: "Image",
                    value: formatBytes($0.effectiveSizeBytes),
                    detail: $0.displayName
                )
            }
        let unusedVolumes = usage.volumes
            .filter { $0.refCount == 0 }
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(2)
            .map {
                SystemUsageRow(
                    title: "Volume",
                    value: formatBytes($0.sizeBytes),
                    detail: $0.name
                )
            }
        let buildCache = usage.buildCache
            .filter { !$0.inUse }
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(2)
            .map {
                SystemUsageRow(
                    title: "Build cache",
                    value: formatBytes($0.sizeBytes),
                    detail: $0.description
                )
            }
        let rows = unusedImages + unusedVolumes + buildCache
        return rows.isEmpty
            ? [SystemUsageRow(title: "-", value: "-", detail: "No reclaimable items found.")]
            : rows
    }
}

private struct SystemUsageCard: View {
    let title: String
    let totalCount: Int
    let activeCount: Int
    let totalSize: Int64
    let reclaimableSize: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(activeCount)/\(totalCount) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(formatBytes(totalSize))
                .font(.title3)
                .bold()
            HStack {
                Text("Reclaimable")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatBytes(reclaimableSize))
            }
            .font(.subheadline)
        }
        .padding(12)
        .cardBackground(highlight: false)
    }
}

private struct SystemUsageDetailCard: View {
    let title: String
    let items: [SystemUsageRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items) { item in
                HStack(alignment: .top) {
                    Text(item.title)
                        .foregroundColor(.secondary)
                        .frame(width: 140, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.value)
                            .bold()
                        Text(item.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .cardBackground(highlight: false)
    }
}

private struct SystemUsageRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
}

private struct ImageCard: View {
    let image: DockerImage
    let isSelected: Bool
    let isCopied: Bool
    let onToggleSelection: () -> Void
    let leftColumnWidth: CGFloat
    let middleColumnWidth: CGFloat
    let rightColumnWidth: CGFloat
    let cardHeight: CGFloat
    let onDelete: () -> Void
    let onCopy: () -> Void

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
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: leftColumnWidth - 48, alignment: .leading)
                        .background(TooltipArea(text: image.nameWithTag))
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .scaleEffect(isCopied ? 1.05 : 1.0)
                            .opacity(isCopied ? 1.0 : 0.75)
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
                        .background(image.inUse ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                    Button("Delete", action: onDelete)
                        .deleteButtonStyle()
                }
            }
            .frame(width: rightColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: cardHeight)
        .foregroundColor(.primary)
        .cardBackground(highlight: image.inUse)
    }

}

private struct ContainerCard: View {
    let container: DockerContainer
    let isSelected: Bool
    let isCopied: Bool
    let onToggleSelection: () -> Void
    let leftColumnWidth: CGFloat
    let middleColumnWidth: CGFloat
    let rightColumnWidth: CGFloat
    let cardHeight: CGFloat
    let onDelete: () -> Void
    let onCopy: () -> Void
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
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: leftColumnWidth - 48, alignment: .leading)
                        .background(TooltipArea(text: container.name))
                }
                Text(truncatedId(container.id))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .draggable(truncatedId(container.id))
            }
            .frame(width: leftColumnWidth, alignment: .leading)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(truncatedImageName(container.imageName))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: middleColumnWidth - 48, alignment: .leading)
                        .background(TooltipArea(text: container.imageName))
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .scaleEffect(isCopied ? 1.05 : 1.0)
                            .opacity(isCopied ? 1.0 : 0.75)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy image name")
                }
                Text(container.command)
                    .lineLimit(1)
                    .font(.system(size: 11, design: .monospaced))
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
                    .background(isRunning ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
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
                    Button("Delete", action: onDelete)
                        .deleteButtonStyle()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: cardHeight)
        .foregroundColor(.primary)
        .cardBackground(highlight: isRunning)
    }
}

private struct NetworkCard: View {
    let network: DockerNetwork
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(network.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .background(TooltipArea(text: network.name))
            VStack(alignment: .leading, spacing: 6) {
                KeyValueRow(label: "ID", value: truncatedId(network.id))
                KeyValueRow(label: "Created", value: formattedNetworkDate(network))
                KeyValueRow(label: "Driver", value: network.driver)
                KeyValueRow(label: "Scope", value: network.scope)
                KeyValueRow(label: "IPv4", value: booleanText(network.enableIPv4))
                KeyValueRow(label: "IPv6", value: booleanText(network.enableIPv6))
                KeyValueRow(label: "Internal", value: network.internalValue ? "true" : "false")
                KeyValueRow(label: "Labels", value: formattedLabels(network.labels))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: width, alignment: .leading)
        .foregroundColor(.primary)
        .cardBackground(highlight: false)
    }
}

private struct CardBackground: ViewModifier {
    let highlight: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = 16
        let baseFill = colorScheme == .light ? TidyTheme.lightCard : TidyTheme.darkCard
        let highlightFill = colorScheme == .light ? TidyTheme.lightHighlight : TidyTheme.darkHighlight
        let stroke = colorScheme == .light ? TidyTheme.lightStroke : TidyTheme.darkStroke
        let darkShadowOpacity = colorScheme == .light ? 0.15 : 0.40
        let lightShadowOpacity = colorScheme == .light ? 0.95 : 0.12

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(highlight ? highlightFill : Color.clear)
                    )
                    .shadow(color: Color.black.opacity(darkShadowOpacity), radius: 10, x: 10, y: 20)
                    .shadow(color: Color.white.opacity(lightShadowOpacity), radius: 16, x: -2, y: -2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke)
            )
    }
}

private extension View {
    func cardBackground(highlight: Bool) -> some View {
        modifier(CardBackground(highlight: highlight))
    }

    func deleteButtonStyle() -> some View {
        modifier(DeleteButtonStyle())
    }
}

private struct DeleteButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.22))
            )
    }
}

private struct TooltipArea: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}

private func copyToClipboard(_ value: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
}

private func truncatedImageName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 12 else { return trimmed }
    let isHex = trimmed.unicodeScalars.allSatisfy { scalar in
        switch scalar {
        case "0"..."9", "a"..."f", "A"..."F":
            return true
        default:
            return false
        }
    }
    return isHex ? String(trimmed.prefix(12)) : trimmed
}

private func truncatedId(_ value: String) -> String {
    let normalized = value.hasPrefix("sha256:") ? String(value.dropFirst(7)) : value
    return String(normalized.prefix(12))
}

private func formatBytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
}

private func formattedNetworkDate(_ network: DockerNetwork) -> String {
    if let createdAt = network.createdAt {
        return createdAt.formatted(date: .numeric, time: .shortened)
    }
    return network.createdRaw
}

private func booleanText(_ value: Bool?) -> String {
    guard let value else { return "-" }
    return value ? "true" : "false"
}

private func formattedLabels(_ labels: [String: String]) -> String {
    guard !labels.isEmpty else { return "-" }
    return labels
        .keys
        .sorted()
        .map { key in
            if let value = labels[key], !value.isEmpty {
                return "\(key)=\(value)"
            }
            return key
        }
        .joined(separator: ", ")
}

private struct KeyValueRow: View {
    let label: String
    let value: String
    private let valueWidth: CGFloat = 130

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
                .background(TooltipArea(text: value))
                .frame(width: valueWidth, alignment: .leading)
        }
        .font(.subheadline)
    }
}

private struct KeyValueList: View {
    let title: String
    let items: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if items.isEmpty {
                Text("-")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(items.keys.sorted(), id: \.self) { key in
                    KeyValueRow(label: key, value: items[key] ?? "-")
                }
            }
        }
    }
}

private extension DockerSystemImage {
    var displayName: String {
        if let name = repoTags.first, !name.isEmpty {
            return name
        }
        if let digest = repoDigests.first, !digest.isEmpty {
            return digest
        }
        return truncatedId(id)
    }

    var effectiveSizeBytes: Int64 {
        max(0, sizeBytes - sharedSizeBytes)
    }
}

#Preview {
    let service = MockDockerService()
    return TabView {
        ImageListView(service: service)
            .tabItem { Text("Images") }
        ContainerListView(service: service)
            .tabItem { Text("Containers") }
        NetworkListView(service: service)
            .tabItem { Text("Networks") }
        SystemDiskUsageView(service: service)
            .tabItem { Text("Disk Usage") }
    }
    .frame(width: 980, height: 640)
}
