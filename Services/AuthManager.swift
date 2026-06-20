import Foundation
import GoogleSignIn
import UIKit

class AuthManager {
    static let shared = AuthManager()
    
    private var accessToken: String?
    
    private init() {}
    
    func getAccessToken() async throws -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return nil
        }
        
        // Refresh token if needed before using it
        let refreshedUser = try await user.refreshTokensIfNeeded()
        
        // Check if the user actually granted the health scopes
        let requiredScopes = [
            "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
            "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
            "https://www.googleapis.com/auth/googlehealth.sleep.readonly",
            "https://www.googleapis.com/auth/googlehealth.profile.readonly"
        ]
        
        let grantedScopes = refreshedUser.grantedScopes ?? []
        let hasRequiredScopes = requiredScopes.allSatisfy { grantedScopes.contains($0) }
        
        if !hasRequiredScopes {
            // The user didn't check the boxes on the consent screen. We must sign them out to force re-consent.
            self.signOut()
            throw NSError(domain: "AuthManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "You must check all the permission boxes on the Google Sign-In screen to allow BLOOP to access your health data."])
        }
        
        return refreshedUser.accessToken.tokenString
    }
    
    @MainActor
    func signIn() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found."])
        }
        
        let scopes = [
            "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
            "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
            "https://www.googleapis.com/auth/googlehealth.sleep.readonly",
            "https://www.googleapis.com/auth/googlehealth.profile.readonly"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: scopes) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = signInResult?.user else {
                    let err = NSError(domain: "AuthManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No user returned from sign in."])
                    continuation.resume(throwing: err)
                    return
                }
                
                self.accessToken = user.accessToken.tokenString
                continuation.resume(returning: ())
            }
        }
    }
    
    @MainActor
    func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                self.accessToken = user.accessToken.tokenString
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.disconnect { error in
            if let error = error {
                print("Disconnect error: \(error)")
            }
        }
        self.accessToken = nil
    }
    
    var isAuthenticated: Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
}
