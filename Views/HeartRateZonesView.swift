import SwiftUI

/// Horizontal stacked bar showing time in each heart rate zone.
struct HeartRateZonesView: View {
    let zone1: Double
    let zone2: Double
    let zone3: Double
    let zone4: Double
    let zone5: Double
    
    private var totalMinutes: Double {
        zone1 + zone2 + zone3 + zone4 + zone5
    }
    
    private struct ZoneInfo {
        let number: Int
        let name: String
        let minutes: Double
        let colorHex: String
        let hrRange: String
    }
    
    private var zones: [ZoneInfo] {
        [
            ZoneInfo(number: 1, name: "Light", minutes: zone1, colorHex: "8E8E93", hrRange: "50-60%"),
            ZoneInfo(number: 2, name: "Moderate", minutes: zone2, colorHex: "5B86E5", hrRange: "60-70%"),
            ZoneInfo(number: 3, name: "Hard", minutes: zone3, colorHex: "00E08F", hrRange: "70-80%"),
            ZoneInfo(number: 4, name: "Threshold", minutes: zone4, colorHex: "FFC700", hrRange: "80-90%"),
            ZoneInfo(number: 5, name: "Max", minutes: zone5, colorHex: "FF334B", hrRange: "90-100%"),
        ]
    }
    
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("HEART RATE ZONES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                
                Spacer()
                
                Text("\(Int(totalMinutes)) min total")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            // Individual zone bars
            ForEach(zones.reversed(), id: \.number) { zone in
                zoneRow(zone: zone)
            }
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
    }
    
    @ViewBuilder
    private func zoneRow(zone: ZoneInfo) -> some View {
        let color = Color(hex: zone.colorHex)
        let fraction = totalMinutes > 0 ? zone.minutes / totalMinutes : 0
        
        HStack(spacing: 10) {
            // Zone label
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text("Z\(zone.number)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 36, alignment: .leading)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(fraction), height: 6)
                }
            }
            .frame(height: 6)
            
            // Minutes
            Text("\(Int(zone.minutes))m")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 40, alignment: .trailing)
        }
    }
}
