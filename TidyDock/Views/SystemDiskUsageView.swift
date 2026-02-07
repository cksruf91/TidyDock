import SwiftUI

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
                                reclaimableSize: usage.imageSummary.reclaimableBytes,
                                highlight: false
                            )
                            SystemUsageCard(
                                title: "Containers",
                                totalCount: usage.containerSummary.totalCount,
                                activeCount: usage.containerSummary.activeCount,
                                totalSize: usage.containerSummary.totalSizeBytes,
                                reclaimableSize: usage.containerSummary.reclaimableBytes,
                                highlight: false
                            )
                            SystemUsageCard(
                                title: "Volumes",
                                totalCount: usage.volumeSummary.totalCount,
                                activeCount: usage.volumeSummary.activeCount,
                                totalSize: usage.volumeSummary.totalSizeBytes,
                                reclaimableSize: usage.volumeSummary.reclaimableBytes,
                                highlight: false
                            )
                            SystemUsageCard(
                                title: "Build Cache",
                                totalCount: usage.buildCacheSummary.totalCount,
                                activeCount: usage.buildCacheSummary.activeCount,
                                totalSize: usage.buildCacheSummary.totalSizeBytes,
                                reclaimableSize: usage.buildCacheSummary.reclaimableBytes,
                                highlight: false
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
            .sorted(by: { $0.effectiveSizeBytes > $1.effectiveSizeBytes })
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
            .sorted(by: { $0.sizeBytes > $1.sizeBytes })
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
            .sorted(by: { $0.sizeBytes > $1.sizeBytes })
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
