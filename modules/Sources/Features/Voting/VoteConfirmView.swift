import SwiftUI
import ComposableArchitecture

struct VoteConfirmView: View {
    let store: StoreOf<Voting>
    let proposalId: String
    let choice: VoteChoice

    var body: some View {
        WithPerceptionTracking {
            let proposal = store.votingRound.proposals.first { $0.id == proposalId }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: choice == .support
                          ? "hand.thumbsup.fill"
                          : "hand.thumbsdown.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(choice == .support ? .green : .red)

                    Text("Vote \(choice == .support ? "Support" : "Oppose")")
                        .font(.title2.bold())

                    if let proposal {
                        Text("on \"\(proposal.title)\"?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("Voting with")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(store.eligibleZECString) ZEC")
                                .bold()
                        }
                        .font(.subheadline)

                        HStack(spacing: 6) {
                            MockBadge(isLive: false)
                            Text("ZKP #2 + background submission — simulated")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("This cannot be changed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    if store.isGeneratingProof {
                        ProgressView("Generating proof...")
                            .padding(.vertical, 14)
                    } else {
                        Button {
                            store.send(.confirmVote(proposalId: proposalId, choice: choice))
                        } label: {
                            Text("Confirm Vote")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(choice == .support ? .green : .red)

                        Button {
                            store.send(.cancelVote)
                        } label: {
                            Text("Cancel")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Confirm Vote")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(store.isGeneratingProof)
        }
    }
}
