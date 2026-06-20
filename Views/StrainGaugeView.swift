import SwiftUI

/// Arc-style gauge for the 0–21 WHOOP strain scale.
struct StrainGaugeView: View {
    let strain: Double
    let band: StrainBand
    
    @State private var animatedProgress: CGFloat = 0
    
    private var bandColor: Color {
        Color(hex: band.colorHex)
    }
    
    var body: some View {
        ZStack {
            // Background arc
            ArcShape(startAngle: -210, endAngle: 30)
                .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 18, lineCap: .round))
            
            // Filled arc
            ArcShape(startAngle: -210, endAngle: -210 + 240 * Double(animatedProgress))
                .stroke(
                    LinearGradient(
                        colors: [bandColor.opacity(0.6), bandColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
            
            // Glow
            ArcShape(startAngle: -210, endAngle: -210 + 240 * Double(animatedProgress))
                .stroke(bandColor.opacity(0.3), style: StrokeStyle(lineWidth: 30, lineCap: .round))
                .blur(radius: 12)
            
            // Center content
            VStack(spacing: 4) {
                Text(String(format: "%.1f", strain))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("STRAIN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text(band.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(bandColor)
                    .tracking(1.5)
                    .padding(.top, 2)
            }
            
            // Scale labels
            scaleLabels
        }
        .frame(width: 240, height: 200)
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                animatedProgress = CGFloat(min(strain, 21) / 21.0)
            }
        }
    }
    
    private var scaleLabels: some View {
        ZStack {
            // "0" at bottom-left
            Text("0")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.gray.opacity(0.5))
                .offset(x: -110, y: 70)
            
            // "21" at bottom-right
            Text("21")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.gray.opacity(0.5))
                .offset(x: 110, y: 70)
        }
    }
}

/// A custom arc shape for the strain gauge.
struct ArcShape: Shape {
    var startAngle: Double
    var endAngle: Double
    
    var animatableData: Double {
        get { endAngle }
        set { endAngle = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + 20)
        let radius = min(rect.width, rect.height) / 2 - 20
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}
