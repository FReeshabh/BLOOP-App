import SwiftUI

/// Strain/Load detail view — gauge, activity summary, HR zones, activities list.
struct LoadDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let strain: StrainData
    @State private var showStrainInfo = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        loadHeader

                        // Strain Gauge
                        StrainGaugeView(strain: strain.dayStrain, band: strain.strainBand)
                            .padding(.top, 10)

                        // Activity Summary Grid
                        activityGrid
                            .padding(.horizontal)

                        // Heart Rate Zones — only shown when zone data is available
                        if strain.totalZoneMinutes > 0 {
                            HeartRateZonesView(
                                zone1: strain.zone1Minutes,
                                zone2: strain.zone2Minutes,
                                zone3: strain.zone3Minutes,
                                zone4: strain.zone4Minutes,
                                zone5: strain.zone5Minutes
                            )
                            .padding(.horizontal)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray.opacity(0.4))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("HR Zone breakdown")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Not available — requires live HR tracking")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                Spacer()
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal)
                        }

                        // Activities List
                        if !strain.activities.isEmpty {
                            activitiesSection
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showStrainInfo) {
                Alert(
                    title: Text("Strain Calculation"),
                    message: Text("Day Strain is calculated using a logarithmic scale from 0 to 21 based on your total cardiovascular load. It heavily weights elevated heart rates (Active Zone Minutes) and lightly factors in daily steps."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var loadHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text("Today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())

            Spacer()

            HStack(spacing: 4) {
                Text("Day Strain")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Button(action: { showStrainInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Activity Grid

    private var activityGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            activityTile(
                icon: "flame.fill",
                color: Color(hex: "FF6B6B"),
                title: "Calories",
                value: String(format: "%.0f", strain.caloriesBurned),
                unit: "kcal"
            )
            activityTile(
                icon: "figure.walk",
                color: Color(hex: "00E08F"),
                title: "Steps",
                value: formatNumber(strain.steps),
                unit: ""
            )
            activityTile(
                icon: "location.fill",
                color: Color(hex: "5B86E5"),
                title: "Distance",
                value: String(format: "%.1f", strain.distance),
                unit: "mi"
            )
            activityTile(
                icon: "heart.circle.fill",
                color: Color(hex: "FFC700"),
                title: "Active Zone",
                value: String(format: "%.0f", strain.activeZoneMinutes),
                unit: "min"
            )
        }
    }

    @ViewBuilder
    private func activityTile(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Activities Section

    private var activitiesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ACTIVITIES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                Spacer()
            }

            ForEach(strain.activities) { activity in
                activityRow(activity: activity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func activityRow(activity: ActivitySession) -> some View {
        let band: StrainBand = {
            if activity.activityStrain >= 18 { return .allOut }
            else if activity.activityStrain >= 14 { return .high }
            else if activity.activityStrain >= 10 { return .moderate }
            else { return .light }
        }()

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: band.colorHex).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: band.colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(SleepData.formatDuration(activity.duration)) • \(Int(activity.caloriesBurned)) kcal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", activity.activityStrain))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: band.colorHex))
                Text("strain")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
