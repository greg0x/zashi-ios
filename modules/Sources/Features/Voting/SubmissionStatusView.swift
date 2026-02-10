import SwiftUI
import ComposableArchitecture

struct SubmissionStatusView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PrototypeBanner()
                        .padding(.bottom, 16)

                    Text("Submission Details")
                        .font(.title2.bold())
                        .padding(.bottom, 16)

                    let sortedSubmissions = store.submissions.values
                        .sorted { $0.proposalId < $1.proposalId }

                    ForEach(sortedSubmissions) { submission in
                        submissionCard(submission: submission)
                            .padding(.bottom, 12)
                    }

                    if store.submissions.isEmpty {
                        Text("No votes submitted yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Submission Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.send(.goBack) } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func submissionCard(submission: VoteSubmission) -> some View {
        let proposal = store.votingRound.proposals.first { $0.id == submission.proposalId }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(proposal?.title ?? submission.proposalId)
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: submission.choice == .support
                          ? "hand.thumbsup.fill"
                          : "hand.thumbsdown.fill")
                        .font(.caption2)
                    Text(submission.choice == .support ? "Support" : "Oppose")
                        .font(.caption2.bold())
                }
                .foregroundStyle(submission.choice == .support ? .green : .red)
            }

            HStack {
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatZatoshi(submission.amount) + " ZEC")
                    .font(.caption.bold())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    MockBadge(isLive: true)
                    Text("Binary decomposition")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(submission.splits) { split in
                    HStack {
                        Text(formatZatoshi(split.amount) + " ZEC")
                            .font(.caption.monospaced())
                        Spacer()
                        HStack(spacing: 6) {
                            MockBadge(isLive: false)
                            statusLabel(split.status)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 6) {
                MockBadge(isLive: false)
                Text("Server: mock-helper-1.zcash.io")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let confirmedCount = submission.splits.filter { $0.status == .confirmed }.count
            VStack(spacing: 4) {
                ProgressView(value: Double(confirmedCount), total: Double(submission.splits.count))
                    .tint(.green)
                Text("\(confirmedCount)/\(submission.splits.count) confirmed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statusLabel(_ status: SubmissionStatus) -> some View {
        switch status {
        case .pending:
            Text("Pending")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .submitted:
            Text("Submitted")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .confirmed:
            Text("Confirmed")
                .font(.caption2)
                .foregroundStyle(.green)
        }
    }

    private func formatZatoshi(_ zatoshi: UInt64) -> String {
        let zec = Double(zatoshi) / 100_000_000.0
        if zec >= 1.0 {
            return String(format: "%.2f", zec)
        } else {
            return String(format: "%.8f", zec)
                .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        }
    }
}
