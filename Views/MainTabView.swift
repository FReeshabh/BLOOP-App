import SwiftUI

struct MainTabView: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case trends   = "Trends"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .overview: return "house.fill"
            case .trends:   return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewDashboardView()
                .tabItem {
                    Label(Tab.overview.rawValue, systemImage: Tab.overview.icon)
                }
                .tag(Tab.overview)

            TrendsView()
                .tabItem {
                    Label(Tab.trends.rawValue, systemImage: Tab.trends.icon)
                }
                .tag(Tab.trends)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.theme.colorScheme ?? .dark)
        .environmentObject(themeManager)
    }
}
