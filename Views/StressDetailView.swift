import SwiftUI

/// Detail view for Stress, explaining its computation from Recovery and Strain.
struct StressDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let stressLevel: Double
    let strain: StrainData
    let recovery: RecoveryScore
    @State private var showStressInfo = false

    private var stressColor: Color {
        if stressLevel < 33 { return Color(hex: "00E08F") }
        else if stressLevel < 66 { return Color(hex: "FFC700") }
        else { return Color(hex: "FF334B") }
    }
    
    private var stressLabel: String {
        if stressLevel < 20 { return "LOW" }
        else if stressLevel < 40 { return "MILD" }
        else if stressLevel < 60 { return "MED" }
        else if stressLevel < 80 { return "HIGH" }
        else { return "PEAK" }
    }
    
    private var stressDescription: String {
        if stressLevel < 33 { return "Within normal range. Your body is handling the current load well." }
        else if stressLevel < 66 { return "Elevated today. Keep an eye on your recovery." }
        else { return "High stress detected. Prioritize rest and recovery." }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerView
                        
                        mainScoreView
                            .padding(.top, 16)
                            
                        gaugeView
                            .padding(.horizontal)
                        
                        contributingFactorsView
                            .padding(.horizontal)
                        
                        infoSection
                            .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showStressInfo) {
                Alert(
                    title: Text("Stress Calculation"),
                    message: Text("Stress is a derived metric indicating the total physiological load currently placed on your body. It is calculated by weighting your overnight recovery score against your accumulated strain for the day."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
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
                Text("Stress")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Button(action: { showStressInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Main Score
    
    private var mainScoreView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(stressColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 32))
                    .foregroundColor(stressColor)
            }
            .padding(.bottom, 8)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", stressLevel))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(stressLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(stressColor)
            }
            
            Text(stressDescription)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Gauge
    
    private var gaugeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAILY RANGE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1.5)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(hex: "00E08F"), Color(hex: "FFC700"), Color(hex: "FF334B")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(stressLevel / 100.0), height: 16)
                        
                    // Marker
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 4, height: 24)
                        .offset(x: max(0, min(geo.size.width - 4, geo.size.width * CGFloat(stressLevel / 100.0) - 2)))
                }
            }
            .frame(height: 24)
            
            HStack {
                Text("0")
                Spacer()
                Text("100")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.gray.opacity(0.6))
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
    
    // MARK: - Contributing Factors
    
    private var contributingFactorsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTRIBUTING FACTORS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1.5)
            
            VStack(spacing: 0) {
                factorRow(
                    title: "Recovery Score",
                    value: "\(recovery.score)",
                    icon: "battery.100.bolt",
                    color: Color(hex: "5B86E5"),
                    description: "Base resilience state",
                    weight: "60%"
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 44)
                
                factorRow(
                    title: "Day Strain",
                    value: String(format: "%.1f", strain.dayStrain),
                    icon: "figure.run",
                    color: Color(hex: "FFC700"),
                    description: "Accumulated physical load",
                    weight: "40%"
                )
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
    }
    
    @ViewBuilder
    private func factorRow(title: String, value: String, icon: String, color: Color, description: String, weight: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Weight: \(weight)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Info
    
    private var infoSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundColor(.gray)
                .padding(.top, 2)
            
            Text("Stress is a derived metric indicating the total physiological load currently placed on your body. It is calculated by weighting your overnight recovery score against your accumulated strain for the day.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}
