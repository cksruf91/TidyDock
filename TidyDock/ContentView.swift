import SwiftUI

private enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case images = "Images"
    case containers = "Containers"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .images: return "square.stack.3d.up"
        case .containers: return "shippingbox"
        }
    }
}

struct ContentView: View {
    private let service: DockerService
    @State private var selection: SidebarItem? = .images

    init(service: DockerService = DockerHTTPService()) {
        self.service = service
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .listStyle(.sidebar)
        } detail: {
            switch selection ?? .images {
            case .images:
                ImageListView(service: service)
            case .containers:
                ContainerListView(service: service)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
