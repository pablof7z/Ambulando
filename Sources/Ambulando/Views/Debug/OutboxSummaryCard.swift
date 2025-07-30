import SwiftUI

struct OutboxSummaryCard: View {
    let summary: OutboxSummary
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Outbox Summary")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Last update time
                if summary.lastUpdateTime != Date() {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last Updated")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(summary.lastUpdateTime, style: .relative)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Users",
                    value: "\(summary.totalUsers)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Distinct Relays",
                    value: "\(summary.totalRelays)",
                    icon: "network",
                    color: .green
                )
                
                StatCard(
                    title: "Avg Relays/User",
                    value: String(format: "%.1f", summary.averageRelaysPerUser),
                    icon: "chart.bar.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Unknown Users",
                    value: "\(summary.unknownUsersCount)",
                    icon: "questionmark.circle.fill",
                    color: .yellow
                )
            }
            
            // Active Subscriptions
            if summary.activeSubscriptions > 0 {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("\(summary.activeSubscriptions) active subscriptions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

struct OutboxSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        OutboxSummaryCard(
            summary: OutboxSummary(
                totalUsers: 42,
                totalRelays: 12,
                averageRelaysPerUser: 2.5,
                lastUpdateTime: Date().addingTimeInterval(-300),
                unknownUsersCount: 7,
                activeSubscriptions: 3,
                connectedRelaysInfo: []
            )
        )
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}