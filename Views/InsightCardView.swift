import SwiftUI

struct InsightCardView: View {
    let score: RecoveryScore
    
    var insightText: String {
        switch score.band {
        case .green: return "You are well-recovered and ready to take on strain. Go hard today!"
        case .yellow: return "Your recovery is adequate. Consider moderate activity."
        case .red: return "Your body needs rest. Prioritize recovery and light movement."
        }
    }
    
    private var bandColor: Color {
        Color(hex: score.band.colorHex)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                Text("Actionable Insight")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(insightText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
}
