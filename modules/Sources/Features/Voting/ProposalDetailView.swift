import SwiftUI
import ComposableArchitecture

struct VoteReviewView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Review Your Votes")
                            .font(.title2.bold())
                            .padding(.bottom, 8)

                        Text("Tap any row to change your vote.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 20)

                        // Vote list
                        ForEach(Array(store.votingRound.proposals.enumerated()), id: \.element.id) { index, proposal in
                            Button {
                                store.send(.editVote(proposalIndex: index))
                            } label: {
                                voteRow(proposal: proposal)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 4)
                        }

                        // Total voting weight
                        HStack {
                            Text("Total voting weight")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(store.votingWeightZECString) ZEC")
                                .font(.subheadline.bold().monospaced())
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }

                // Submit button
                Button {
                    store.send(.submitVotesTapped)
                } label: {
                    Text("Submit Votes")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Vote Review")
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
    private func voteRow(proposal: Proposal) -> some View {
        let choice = store.votes[proposal.id]

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(proposal.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if let choice {
                voteChip(choice: choice)
            } else {
                Text("No vote")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func voteChip(choice: VoteChoice) -> some View {
        switch choice {
        case .support:
            Text("Support")
                .font(.caption.bold())
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        case .oppose:
            Text("Oppose")
                .font(.caption.bold())
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
        case .skip:
            Text("Skipped")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}
