import SwiftUI

/// Horizontal stacked bar showing sleep stage breakdown (Awake | Light | REM | Deep).
struct SleepStagesBarView: View {
    let awake: TimeInterval
    let light: TimeInterval
    let rem: TimeInterval
    let deep: TimeInterval
    
    private var totalDuration: TimeInterval {
        awake + light + rem + deep
    }
    
    private func fraction(for stage: TimeInterval) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        return CGFloat(stage / totalDuration)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    stageSegment(
                        width: geometry.size.width * fraction(for: awake),
                        color: Color(hex: "FF334B"),
                        corners: [.topLeft, .bottomLeft]
                    )
                    stageSegment(
                        width: geometry.size.width * fraction(for: light),
                        color: Color(hex: "5B86E5"),
                        corners: []
                    )
                    stageSegment(
                        width: geometry.size.width * fraction(for: rem),
                        color: Color(hex: "00B4D8"),
                        corners: []
                    )
                    stageSegment(
                        width: geometry.size.width * fraction(for: deep),
                        color: Color(hex: "6C5CE7"),
                        corners: [.topRight, .bottomRight]
                    )
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Legend
            HStack(spacing: 16) {
                stageLegendItem(color: Color(hex: "FF334B"), label: "Awake", duration: awake)
                stageLegendItem(color: Color(hex: "5B86E5"), label: "Light", duration: light)
                stageLegendItem(color: Color(hex: "00B4D8"), label: "REM", duration: rem)
                stageLegendItem(color: Color(hex: "6C5CE7"), label: "Deep", duration: deep)
            }
        }
    }
    
    @ViewBuilder
    private func stageSegment(width: CGFloat, color: Color, corners: UIRectCorner) -> some View {
        if width > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(width - 1, 2))
        }
    }
    
    @ViewBuilder
    private func stageLegendItem(color: Color, label: String, duration: TimeInterval) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            Text(SleepData.formatDuration(duration))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
