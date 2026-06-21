import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    
    let healthService: HealthDataProvider
    let authManager: AuthManager
    
    private init() {
        self.authManager = AuthManager.shared
        self.healthService = GoogleHealthService(authManager: AuthManager.shared)
    }
}
