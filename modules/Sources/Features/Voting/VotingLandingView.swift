import SwiftUI
import ComposableArchitecture

struct VotingLandingView: View {
    let store: StoreOf<Voting>

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PrototypeBanner()
                        .padding(.bottom, 24)

                    Text(store.votingRound.title)
                        .font(.title2.bold())
                        .padding(.bottom, 8)

                    HStack(spacing: 6) {
                        MockBadge(isLive: true)
                        Text(deadlineText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Eligible Balance")
                                .font(.headline)
                            MockBadge(isLive: true)
                        }
                        Text("\(store.eligibleZECString) ZEC")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    .padding(.bottom, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Text("Delegation Status")
                                .font(.headline)
                            MockBadge(isLive: false)
                        }

                        if store.isDelegated {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Ready (\(store.delegatedZECString) ZEC)")
                                    .font(.subheadline)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                                Text("Not set up")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.bottom, 32)

                    if store.isDelegated {
                        Button {
                            store.send(.viewProposalsTapped)
                        } label: {
                            Text("View Proposals")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    } else {
                        Button {
                            store.send(.setUpVotingTapped)
                        } label: {
                            Text("Set Up Voting")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Governance Voting")
            .onReceive(timer) { _ in
                now = Date()
            }
        }
    }

    private var deadlineText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a zzz"
        let dateStr = formatter.string(from: store.votingRound.deadline)

        let remaining = store.votingRound.deadline.timeIntervalSince(now)
        guard remaining > 0 else {
            return "\(dateStr) — Voting ended"
        }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if days > 0 {
            return "\(dateStr) — \(days)d \(hours)h remaining"
        } else if hours > 0 {
            return "\(dateStr) — \(hours)h \(minutes)m remaining"
        } else {
            return "\(dateStr) — \(minutes)m remaining"
        }
    }
}
