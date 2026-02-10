import SwiftUI
import ComposableArchitecture

public struct VotingView: View {
    let store: StoreOf<Voting>

    public init(store: StoreOf<Voting>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            screenView(for: store.currentScreen)
                .id(store.screenStack.count)
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.25), value: store.screenStack.count)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func screenView(for screen: Voting.State.Screen) -> some View {
        switch screen {
        case .landing:
            VotingLandingView(store: store)
        case .delegationSetup:
            DelegationSetupView(store: store)
        case .keystoneSigning:
            KeystoneSigningView(store: store)
        case .zkpProgress:
            ZKPProgressView(store: store)
        case .delegationConfirmed:
            DelegationConfirmedView(store: store)
        case .proposalVoting:
            ProposalVotingView(store: store)
        case .voteReview:
            VoteReviewView(store: store)
        case .voteSubmission:
            VoteSubmissionView(store: store)
        case .votesLockedIn:
            VotesLockedInView(store: store)
        }
    }
}

// MARK: - Placeholders

extension Voting.State {
    public static let initial = Voting.State()
}

extension StoreOf<Voting> {
    public static let placeholder = StoreOf<Voting>(
        initialState: .initial
    ) {
        Voting()
    }
}

#Preview {
    NavigationStack {
        VotingView(store: .placeholder)
    }
}
