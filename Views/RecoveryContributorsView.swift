import SwiftUI

/// Shows how each metric contributes to the overall recovery score
/// using horizontal progress bars.
struct RecoveryContributorsView: View {
    let score: RecoveryScore
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("RECOVERY CONTRIBUTORS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            ContributorBar(
                label: "HRV",
                value: score.hrvContribution,
                color: contributorColor(for: score.hrvContribution)
            )
            
            ContributorBar(
                label: "Resting HR",
                value: score.rhrContribution,
                color: contributorColor(for: score.rhrContribution)
            )
            
            ContributorBar(
                label: "Resp Rate",
                value: score.respRateContribution,
                color: contributorColor(for: score.respRateContribution)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private func contributorColor(for value: Int) -> Color {
        if value >= 67 { return Color(hex: "00E08F") }
        else if value >= 34 { return Color(hex: "FFC700") }
        else { return Color(hex: "FF334B") }
    }
}

struct ContributorBar: View {
    let label: String
    let value: Int
    let color: Color
    
    @State private var animatedWidth: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 72, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    
                    // Filled progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animatedWidth, height: 8)
                        .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                        animatedWidth = geometry.size.width * CGFloat(max(0, min(value, 100))) / 100.0
                    }
                }
                .onChange(of: value) { _, newValue in
                    withAnimation(.easeOut(duration: 0.6)) {
                        animatedWidth = geometry.size.width * CGFloat(max(0, min(newValue, 100))) / 100.0
                    }
                }
            }
            .frame(height: 8)
            
            Text("\(value)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
