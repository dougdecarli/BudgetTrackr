import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MonthsTabView()
            }
            .tabItem {
                Label("Meses", systemImage: "calendar")
            }

            NavigationStack {
                TrendsView()
            }
            .tabItem {
                Label("Tendências", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Ajustes", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    RootTabView()
}
