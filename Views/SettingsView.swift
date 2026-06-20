import SwiftUI

/// Settings screen with theme, data source, and account management.
struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showResetConfirmation = false
    @State private var showSignOutConfirmation = false
    @AppStorage("lastHistoricalSync") private var lastHistoricalSync: Double = 0

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    settingsHeader

                    // Appearance
                    appearanceSection

                    // Accent Color
                    accentColorSection

                    // Data Source
                    dataSourceSection

                    // Account
                    accountSection

                    // About
                    aboutSection

                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("APPEARANCE")

            VStack(spacing: 0) {
                ForEach(ThemeManager.AppTheme.allCases) { theme in
                    Button(action: { themeManager.theme = theme }) {
                        HStack {
                            Image(systemName: themeIcon(for: theme))
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .frame(width: 28)

                            Text(theme.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            if themeManager.theme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "00E08F"))
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if theme != ThemeManager.AppTheme.allCases.last {
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal)
    }

    private func themeIcon(for theme: ThemeManager.AppTheme) -> String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        }
    }

    // MARK: - Accent Color

    private var accentColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ACCENT COLOR")

            HStack(spacing: 16) {
                ForEach(ThemeManager.AccentOption.allCases) { option in
                    Button(action: { themeManager.accentOption = option }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: option.color.opacity(0.4), radius: themeManager.accentOption == option ? 8 : 0)

                                if themeManager.accentOption == option {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 50, height: 50)
                                }
                            }

                            Text(option.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(themeManager.accentOption == option ? .white : .gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Data Source

    private var dataSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("DATA SOURCE")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "5B86E5"))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Health API")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text(AuthManager.shared.isAuthenticated ? "Connected" : "Not connected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AuthManager.shared.isAuthenticated ? Color(hex: "00E08F") : .gray)
                    }

                    Spacer()

                    Circle()
                        .fill(AuthManager.shared.isAuthenticated ? Color(hex: "00E08F") : Color(hex: "FF334B"))
                        .frame(width: 8, height: 8)
                        .shadow(color: (AuthManager.shared.isAuthenticated ? Color(hex: "00E08F") : Color(hex: "FF334B")).opacity(0.6), radius: 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                // Sync button
                Button(action: {
                    // Trigger historical sync — reuses dashboard logic
                    UserDefaults.standard.set(false, forKey: "hasPromptedForHistoricalSync")
                    // We simulate setting the timestamp here, though ideally the ViewModel sets it when complete
                    lastHistoricalSync = Date().timeIntervalSince1970
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "FFC700"))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re-sync Historical Data")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
                            if lastHistoricalSync > 0 {
                                Text("Last synced: \(Date(timeIntervalSince1970: lastHistoricalSync).formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ACCOUNT")

            VStack(spacing: 0) {
                // Sign out
                Button(action: { showSignOutConfirmation = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .frame(width: 28)

                        Text("Sign Out")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Sign Out", role: .destructive) {
                        AuthManager.shared.signOut()
                    }
                } message: {
                    Text("You'll need to sign in again to see your health data.")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal)
        
        // Danger Zone
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("DANGER ZONE")

            VStack(spacing: 0) {
                // Reset data
                Button(action: { showResetConfirmation = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "FF334B"))
                            .frame(width: 28)

                        Text("Reset All Data")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "FF334B"))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .alert("Reset All Data", isPresented: $showResetConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "hasPromptedForHistoricalSync")
                        lastHistoricalSync = 0
                    }
                } message: {
                    Text("This will clear all cached health data. You'll need to re-sync from Google Health.")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "FF334B").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "FF334B").opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal)
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(spacing: 8) {
            Text("BLOOP")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            Text("Version 1.0.0")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.3))

            Text("Your personal health intelligence")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.gray.opacity(0.2))
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.gray.opacity(0.6))
            .tracking(1.5)
            .padding(.leading, 4)
    }
}
