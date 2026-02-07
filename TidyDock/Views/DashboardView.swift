import SwiftUI

struct DashboardView: View {
    @StateObject private var imageViewModel: ImageListViewModel
    @StateObject private var containerViewModel: ContainerListViewModel
    @StateObject private var networkViewModel: NetworkListViewModel
    @StateObject private var usageViewModel: SystemDiskUsageViewModel
    @State private var showErrorAlert = false

    private let summaryColumns = [
        GridItem(.flexible(minimum: 0), spacing: 16),
        GridItem(.flexible(minimum: 0), spacing: 16)
    ]
    private let maxDashboardItems = 10

    init(service: DockerService) {
        _imageViewModel = StateObject(wrappedValue: ImageListViewModel(service: service))
        _containerViewModel = StateObject(wrappedValue: ContainerListViewModel(service: service))
        _networkViewModel = StateObject(wrappedValue: NetworkListViewModel(service: service))
        _usageViewModel = StateObject(wrappedValue: SystemDiskUsageViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(title: "Dashboard")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DashboardSectionHeader(title: "Images / Containers")
                    LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
                        DashboardListCard(
                            title: "Images",
                            items: topImages
                        )
                        .frame(maxHeight: .infinity, alignment: .top)
                        DashboardContainerCard(items: topContainers)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }

                    DashboardSectionHeader(title: "Disk Usage")
                    if let usage = usageViewModel.usage {
                        LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
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
                    } else if usageViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("No disk usage data available.")
                            .foregroundColor(.secondary)
                    }

                    DashboardSectionHeader(title: "Networks")
                    DashboardNetworkCard(networks: networkViewModel.networks)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .tidyPanelBackground()
        .task {
            await refreshAll()
        }
        .onChange(of: combinedErrorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                clearErrors()
            }
        } message: {
            Text(combinedErrorMessage ?? "Unknown error")
        }
    }

    private var topImages: [DashboardItemRow] {
        let sorted = imageViewModel.images
            .sorted(by: { $0.sizeBytes > $1.sizeBytes })
        let items = sorted
            .prefix(maxDashboardItems)
            .map { image in
                DashboardItemRow(
                    title: image.nameWithTag,
                    detail: formatBytes(image.sizeBytes)
                )
            }
        if items.isEmpty {
            return [DashboardItemRow(title: "-", detail: "-")]
        }
        let omitted = max(sorted.count - maxDashboardItems, 0)
        return omitted > 0
            ? items + [DashboardItemRow(title: "... +\(omitted) more", detail: "")]
            : items
    }

    private var topContainers: [DashboardContainerRow] {
        guard let usage = usageViewModel.usage else {
            return [DashboardContainerRow(containerName: "-", imageName: "-", sizeText: "-")]
        }
        let sorted = usage.containers
            .sorted(by: { $0.sizeRootFsBytes > $1.sizeRootFsBytes })
        let items = sorted
            .prefix(maxDashboardItems)
            .map { container in
                DashboardContainerRow(
                    containerName: container.name,
                    imageName: container.image,
                    sizeText: formatBytes(container.sizeRootFsBytes)
                )
            }
        if items.isEmpty {
            return [DashboardContainerRow(containerName: "-", imageName: "-", sizeText: "-")]
        }
        let omitted = max(sorted.count - maxDashboardItems, 0)
        return omitted > 0
            ? items + [DashboardContainerRow(containerName: "... +\(omitted) more", imageName: "", sizeText: "")]
            : items
    }

    private var combinedErrorMessage: String? {
        imageViewModel.errorMessage
            ?? containerViewModel.errorMessage
            ?? networkViewModel.errorMessage
            ?? usageViewModel.errorMessage
    }

    private func clearErrors() {
        imageViewModel.errorMessage = nil
        containerViewModel.errorMessage = nil
        networkViewModel.errorMessage = nil
        usageViewModel.errorMessage = nil
    }

    private func refreshAll() async {
        await imageViewModel.refresh()
        await containerViewModel.refresh()
        await networkViewModel.refresh()
        await usageViewModel.refresh()
    }

    private func header(title: String) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .bold()
            Spacer()
            Button("Refresh") {
                Task { await refreshAll() }
            }
        }
    }
}

private struct DashboardSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .bold()
    }
}

private struct DashboardListCard: View {
    let title: String
    let items: [DashboardItemRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(TooltipArea(text: item.title))
                    Spacer()
                    Text(item.detail)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding(12)
        .cardBackground(highlight: false)
    }
}

private struct DashboardContainerCard: View {
    let items: [DashboardContainerRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Containers")
                .font(.headline)
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item.containerName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(TooltipArea(text: item.containerName))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.imageName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(TooltipArea(text: item.imageName))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.sizeText)
                        .foregroundColor(.secondary)
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.subheadline)
            }
        }
        .padding(12)
        .cardBackground(highlight: false)
    }
}

private struct DashboardNetworkCard: View {
    let networks: [DockerNetwork]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Networks")
                .font(.headline)
            if networks.isEmpty {
                Text("-")
                    .foregroundColor(.secondary)
            } else {
                ForEach(networks.prefix(4)) { network in
                    HStack(alignment: .top, spacing: 8) {
                        Text(network.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .background(TooltipArea(text: network.name))
                        Spacer()
                        Text(network.driver)
                            .foregroundColor(.secondary)
                        Text(formattedNetworkDate(network))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(12)
        .cardBackground(highlight: false)
    }
}

private struct DashboardItemRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct DashboardContainerRow: Identifiable {
    let id = UUID()
    let containerName: String
    let imageName: String
    let sizeText: String
}
