import SwiftUI

@MainActor
final class ActivitiesViewModel: ObservableObject {
    @Published var activities: [ActivitySession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let healthService: HealthDataProvider
    private let authManager: AuthManager
    
    init(healthService: HealthDataProvider = AppEnvironment.shared.healthService,
         authManager: AuthManager = AppEnvironment.shared.authManager) {
        self.healthService = healthService
        self.authManager = authManager
    }
    
    func loadActivities() async {
        isLoading = true
        errorMessage = nil
        do {
            if !authManager.isAuthenticated {
                try await authManager.signIn()
            }
            // Fetch last 30 days
            let calendar = Calendar.current
            let now = Date()
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
            
            if let googleService = healthService as? GoogleHealthService {
                let fetched = try await googleService.fetchExerciseSessions(from: thirtyDaysAgo, to: now)
                self.activities = fetched.sorted { $0.startTime > $1.startTime }
            }
        } catch is CancellationError {
            // Ignore cancellation
            return
        } catch let err as URLError where err.code == .cancelled {
            // Ignore cancellation
            return
        } catch {
            self.errorMessage = "Failed to load activities: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct ActivitiesLogView: View {
    @StateObject private var viewModel = ActivitiesViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading && viewModel.activities.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "FF334B"))
                        Text(error)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            Task { await viewModel.loadActivities() }
                        }
                    }
                } else if viewModel.activities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.walk.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Activities Logged")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Your recent exercises for the last 30 days will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.activities) { activity in
                                ActivityRowView(activity: activity)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Activity Log")
            .refreshable {
                await viewModel.loadActivities()
            }
            .task {
                if viewModel.activities.isEmpty {
                    await viewModel.loadActivities()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
