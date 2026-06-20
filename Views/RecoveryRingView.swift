import SwiftUI

struct RecoveryRingView: View {
    let score: RecoveryScore
    
    @State private var animatedProgress: CGFloat = 0
    
    private var bandColor: Color {
        Color(hex: score.band.colorHex)
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 18)
            
            // Animated progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            bandColor.opacity(0.6),
                            bandColor
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Inner glow
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(bandColor.opacity(0.3), lineWidth: 30)
                .blur(radius: 12)
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 4) {
                Text("\(score.score)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                
                Text("RESILIENCE (EST.)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text(score.band.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(bandColor)
                    .tracking(1.5)
                    .padding(.top, 2)
            }
        }
        .frame(width: 220, height: 220)
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                animatedProgress = CGFloat(score.score) / 100.0
            }
        }
        .onChange(of: score.score) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = CGFloat(newValue) / 100.0
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
