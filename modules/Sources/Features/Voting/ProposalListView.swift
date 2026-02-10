import SwiftUI
import ComposableArchitecture

struct ProposalListView: View {
    let store: StoreOf<Voting>

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(store.eligibleZECString + " ZEC")
                                .font(.headline)
                            Spacer()
                            Text("\(store.proposalsVotedCount)/\(store.votingRound.proposals.count) voted")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(deadlineText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 16)

                    // Power user toggle
                    HStack {
                        Spacer()
                        Button {
                            store.send(.toggleSplitDecomposition)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.showSplitDecomposition ? "eye.fill" : "eye.slash")
                                Text("Splits")
                                    .font(.caption)
                            }
                            .foregroundStyle(store.showSplitDecomposition ? .blue : .secondary)
                        }
                    }
                    .padding(.bottom, 8)

                    // Proposal cards
                    ForEach(store.votingRound.proposals) { proposal in
                        proposalCard(proposal: proposal)
                            .padding(.bottom, 8)
                    }

                    // Submission status link
                    if store.showSplitDecomposition && !store.submissions.isEmpty {
                        Button {
                            store.send(.viewSubmissionStatus)
                        } label: {
                            Text("View All Submission Details")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Proposals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.send(.goBack) } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onReceive(timer) { _ in
                now = Date()
            }
        }
    }

    @ViewBuilder
    private func proposalCard(proposal: Proposal) -> some View {
        Button {
            store.send(.selectProposal(proposal.id))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(proposal.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    voteStatusChip(for: proposal.id)
                }

                if let zipNumber = proposal.zipNumber {
                    Text(zipNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Power user: split decomposition for voted proposals
                if store.showSplitDecomposition, let submission = store.submissions[proposal.id] {
                    splitDecompositionView(submission: submission)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func voteStatusChip(for proposalId: String) -> some View {
        if let choice = store.votes[proposalId] {
            HStack(spacing: 4) {
                Image(systemName: choice == .support ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .font(.caption2)
                Text(choice == .support ? "Support" : "Oppose")
                    .font(.caption2.bold())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(choice == .support ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .foregroundStyle(choice == .support ? .green : .red)
            .clipShape(Capsule())
        } else {
            Text("Not voted")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func splitDecompositionView(submission: VoteSubmission) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MockBadge(isLive: true)
                Text("Split decomposition")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 4) {
                ForEach(submission.splits) { split in
                    HStack(spacing: 2) {
                        Text(formatZatoshi(split.amount))
                            .font(.caption2.monospaced())
                        statusDot(split.status)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func statusDot(_ status: SubmissionStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 6, height: 6)
    }

    private func statusColor(_ status: SubmissionStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .submitted: return .orange
        case .confirmed: return .green
        }
    }

    private func formatZatoshi(_ zatoshi: UInt64) -> String {
        let zec = Double(zatoshi) / 100_000_000.0
        if zec >= 1.0 {
            return String(format: "%.0f", zec)
        } else {
            return String(format: "%.8f", zec)
                .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        }
    }

    private var deadlineText: String {
        let remaining = store.votingRound.deadline.timeIntervalSince(now)
        guard remaining > 0 else { return "Voting ended" }
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        if days > 0 {
            return "\(days)d \(hours)h remaining"
        } else {
            let minutes = (Int(remaining) % 3600) / 60
            return "\(hours)h \(minutes)m remaining"
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
