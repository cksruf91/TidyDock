import SwiftUI

struct NetworkListView: View {
    @StateObject private var viewModel: NetworkListViewModel
    @State private var showErrorAlert = false
    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 16)
    ]
    private let cardWidth: CGFloat = 260

    init(service: DockerService) {
        _viewModel = StateObject(wrappedValue: NetworkListViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(title: "Networks")
            if viewModel.isLoading {
                ProgressView()
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.networks) { network in
                        NetworkCard(network: network, width: cardWidth)
                    }
                }
                .padding(.top, 4)
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
