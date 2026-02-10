import SwiftUI

/// Persistent dev banner at the top of the Voting flow
struct PrototypeBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
            Text("Prototype — some features are mocked (see orange badges)")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Small colored badge indicating MOCK (orange) or LIVE (green)
struct MockBadge: View {
    let isLive: Bool

    var body: some View {
        Text(isLive ? "LIVE" : "MOCK")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isLive ? Color.green : Color.orange)
            .clipShape(Capsule())
    }
}
