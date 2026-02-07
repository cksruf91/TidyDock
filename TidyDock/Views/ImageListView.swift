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
