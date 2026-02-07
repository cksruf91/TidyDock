import SwiftUI

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
                            cardHeight: cardHeight,
                            onDelete: {
                                selectedContainer = container
                                showDeleteConfirm = true
                            },
                            onCopy: {
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
                            },
                            onStart: {
                                Task { await viewModel.startContainer(id: container.id) }
                            },
                            onStop: {
                                Task { await viewModel.stopContainer(id: container.id) }
                            }
                        )
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

    private func toggleSelection(for id: String) {
        if selectedContainerIds.contains(id) {
            selectedContainerIds.remove(id)
        } else {
            selectedContainerIds.insert(id)
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
