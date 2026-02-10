import SwiftUI
import ComposableArchitecture

struct ProposalDetailView: View {
    let store: StoreOf<Voting>
    let proposalId: String

    var body: some View {
        WithPerceptionTracking {
            let proposal = store.votingRound.proposals.first { $0.id == proposalId }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let proposal {
                        Text(proposal.title)
                            .font(.title2.bold())
                            .padding(.bottom, 8)

                        if let zipNumber = proposal.zipNumber {
                            Text(zipNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 16)
                        }

                        Text(proposal.description)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.bottom, 16)

                        if let forumURL = proposal.forumURL {
                            Link(destination: forumURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                    Text("Discussion Forum")
                                }
                                .font(.subheadline)
                            }
                            .padding(.bottom, 24)
                        }

                        // Existing vote
                        if let existingVote = store.votes[proposalId] {
                            HStack(spacing: 8) {
                                Image(systemName: existingVote == .support
                                      ? "hand.thumbsup.fill"
                                      : "hand.thumbsdown.fill")
                                Text("You voted: \(existingVote == .support ? "Support" : "Oppose")")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(existingVote == .support ? .green : .red)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((existingVote == .support ? Color.green : Color.red).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Vote buttons
                            VStack(spacing: 12) {
                                Text("Cast Your Vote")
                                    .font(.headline)
                                    .padding(.bottom, 4)

                                HStack(spacing: 12) {
                                    Button {
                                        store.send(.voteChoice(proposalId: proposalId, choice: .support))
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
                                        store.send(.voteChoice(proposalId: proposalId, choice: .oppose))
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
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Proposal")
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
}
