import SwiftUI
import ComposableArchitecture

struct ProposalVotingView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            if let proposal = store.currentProposal {
                let index = store.currentProposalIndex

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Progress indicator
                            Text("Question \(index + 1) of \(store.totalProposals)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)

                            ProgressView(value: Double(index + 1), total: Double(store.totalProposals))
                                .tint(.blue)
                                .padding(.bottom, 24)

                            // Proposal title
                            Text(proposal.title)
                                .font(.title2.bold())
                                .padding(.bottom, 12)

                            // Description
                            Text(proposal.description)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding(.bottom, 16)

                            // ZIP number
                            if let zipNumber = proposal.zipNumber {
                                Text(zipNumber)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 8)
                            }

                            // Forum link
                            if let forumURL = proposal.forumURL {
                                Link(destination: forumURL) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                        Text("View full proposal")
                                    }
                                    .font(.subheadline)
                                }
                                .padding(.bottom, 16)
                            }

                            // Existing vote indicator
                            if let existingVote = store.votes[proposal.id], existingVote != .skip {
                                HStack(spacing: 6) {
                                    Image(systemName: existingVote == .support ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                        .font(.caption)
                                    Text("Previously: \(existingVote.label)")
                                        .font(.caption)
                                }
                                .foregroundStyle(existingVote == .support ? .green : .red)
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }

                    // Vote buttons
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                store.send(.castVote(proposalId: proposal.id, choice: .support))
                            } label: {
                                HStack {
                                    Image(systemName: "hand.thumbsup.fill")
                                    Text("Support")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            Button {
                                store.send(.castVote(proposalId: proposal.id, choice: .oppose))
                            } label: {
                                HStack {
                                    Image(systemName: "hand.thumbsdown.fill")
                                    Text("Oppose")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }

                        Button {
                            store.send(.skipProposal(proposalId: proposal.id))
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .navigationTitle("Vote")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if index > 0 {
                            Button { store.send(.previousProposal) } label: {
                                Image(systemName: "chevron.left")
                            }
                        } else {
                            Button { store.send(.goBack) } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                    }
                }
            }
        }
    }
}
