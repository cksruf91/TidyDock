import SwiftUI

private enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case images = "Images"
    case containers = "Containers"
    case networks = "Networks"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .images: return "square.stack.3d.up"
        case .containers: return "shippingbox"
        case .networks: return "network"
        }
    }
}

struct ContentView: View {
    private let service: DockerService
    @State private var selection: SidebarItem? = .images
    @AppStorage("tidydock.colorScheme") private var colorSchemePreference = "system"
    @Environment(\.colorScheme) private var colorScheme

    init(service: DockerService = DockerHTTPService()) {
        self.service = service
    }

    var body: some View {
        ZStack {
            TidyTheme.canvasBackground(for: colorScheme)
                .ignoresSafeArea()
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(
                    (colorScheme == .light ? TidyTheme.lightPanel : TidyTheme.darkPanel)
                        .opacity(colorScheme == .light ? 0.7 : 1.0)
                )
            } detail: {
                switch selection ?? .images {
                case .images:
                    ImageListView(service: service)
                case .containers:
                    ContainerListView(service: service)
                case .networks:
                    NetworkListView(service: service)
                }
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .preferredColorScheme(preferredScheme)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    toggleScheme()
                } label: {
                    Image(systemName: colorSchemePreference == "dark" ? "sun.max.fill" : "moon.fill")
                }
                .help("Toggle Light/Dark")

                Button {
                    colorSchemePreference = "system"
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Use System Appearance")
            }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func toggleScheme() {
        switch colorSchemePreference {
        case "light":
            colorSchemePreference = "dark"
        case "dark":
            colorSchemePreference = "light"
        default:
            colorSchemePreference = "dark"
        }
    }
}

#Preview {
    ContentView()
}
