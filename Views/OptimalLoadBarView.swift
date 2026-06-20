import SwiftUI

/// Hearth-style horizontal bar showing today's load position within optimal range.
struct OptimalLoadBarView: View {
    let currentLoad: Double       // 0–100
    let optimalRange: ClosedRange<Double>  // e.g. 55...77

    private var statusLabel: String {
        if currentLoad < optimalRange.lowerBound {
            return "Room for more"
        } else if currentLoad > optimalRange.upperBound {
            return "Overreaching"
        } else {
            return "In the zone"
        }
    }

    private var statusColor: Color {
        if currentLoad < optimalRange.lowerBound {
            return Color(hex: "5B86E5")  // blue/neutral — room to push, not a problem
        } else if currentLoad > optimalRange.upperBound {
            return Color(hex: "FF334B")  // red — overreaching
        } else {
            return Color(hex: "00E08F")  // green — in the ideal zone
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("Optimal load today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(statusColor)
            }

            // Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Full background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    // Optimal zone highlight
                    let startX = geometry.size.width * CGFloat(optimalRange.lowerBound / 100.0)
                    let endX   = geometry.size.width * CGFloat(optimalRange.upperBound / 100.0)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "5B86E5").opacity(0.35))
                        .frame(width: endX - startX, height: 8)
                        .offset(x: startX)

                    // Current position marker
                    let markerX = geometry.size.width * CGFloat(min(max(currentLoad, 0), 100) / 100.0)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 3, height: 16)
                        .offset(x: markerX - 1.5)
                        .shadow(color: .white.opacity(0.4), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 16)

            // Scale labels
            HStack {
                Text("easy")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))

                Spacer()

                Text("optimal \(Int(optimalRange.lowerBound))–\(Int(optimalRange.upperBound))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "5B86E5"))

                Spacer()

                Text("all-out")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
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
        .padding(.horizontal)
    }
}
