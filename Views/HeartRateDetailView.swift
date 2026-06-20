import SwiftUI
import Charts

/// A detail view for today's heart rate, showing a graph of intraday data.
struct HeartRateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let heartRateData: [HealthDataPoint]
    let restingHeartRate: Double?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerView
                        
                        summaryCard
                        
                        chartCard
                            .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
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
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            
            Spacer()
            
            // Placeholder to balance the chevron button
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.clear)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "FF6B6B"))
                .padding(.bottom, 8)
            
            if let current = heartRateData.first?.value {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", current))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("bpm")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text("CURRENT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(2)
            }
            
            if let resting = restingHeartRate {
                Text("Resting HR: \(Int(resting)) bpm")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Chart Card
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HEART RATE TREND")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1.5)
            
            if heartRateData.isEmpty {
                Text("No heart rate data available for today.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(heartRateData) { point in
                        LineMark(
                            x: .value("Time", point.startTime),
                            y: .value("BPM", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color(hex: "FF6B6B").gradient)
                        
                        AreaMark(
                            x: .value("Time", point.startTime),
                            y: .value("BPM", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF6B6B").opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                        AxisTick().foregroundStyle(.gray.opacity(0.5))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.hour()))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                        AxisTick().foregroundStyle(.gray.opacity(0.5))
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text("\(Int(val))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .frame(height: 250)
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
}
