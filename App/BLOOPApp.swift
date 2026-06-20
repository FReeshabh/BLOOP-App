import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct BLOOPApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HealthDataPointEntity.self,
            RecoveryScoreEntity.self,
            UserBaselineEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            #if DEBUG
            print("Failed to load ModelContainer: \(error). Attempting to delete store and retry...")
            let url = modelConfiguration.url
            let fileManager = FileManager.default
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                let shmUrl = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
                if fileManager.fileExists(atPath: shmUrl.path) {
                    try fileManager.removeItem(at: shmUrl)
                }
                let walUrl = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
                if fileManager.fileExists(atPath: walUrl.path) {
                    try fileManager.removeItem(at: walUrl)
                }
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Failed to recreate ModelContainer after deletion: \(error)")
            }
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "1003427991918-863ivqeis6fdfn9g0e4d4uq0i7r6sgdo.apps.googleusercontent.com")
                    Task {
                        await MainActor.run {
                            AuthManager.shared.restorePreviousSignIn()
                        }
                    }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
