import SwiftUI

struct ContentView: View {
    private let service: DockerService

    init(service: DockerService = DockerHTTPService()) {
        self.service = service
    }

    var body: some View {
        TabView {
            ImageListView(service: service)
                .tabItem { Text("Images") }
            ContainerListView(service: service)
                .tabItem { Text("Containers") }
        }
        .frame(minWidth: 960, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
