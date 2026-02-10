import SwiftUI
import ComposableArchitecture

public struct VotingView: View {
    let store: StoreOf<Voting>

    public init(store: StoreOf<Voting>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                screenView(for: store.currentScreen)
                    .animation(.default, value: store.currentScreen)
            }
        }
    }

    @ViewBuilder
    private func screenView(for screen: Voting.State.Screen) -> some View {
        switch screen {
        case .landing:
            VotingLandingView(store: store)
        case .delegationReview:
            DelegationReviewView(store: store)
        case .delegationProgress:
            DelegationProgressView(store: store)
        case .proposalList:
            ProposalListView(store: store)
        case .proposalDetail(let proposalId):
            ProposalDetailView(store: store, proposalId: proposalId)
        case .voteConfirm(let proposalId, let choice):
            VoteConfirmView(store: store, proposalId: proposalId, choice: choice)
        case .submissionStatus:
            SubmissionStatusView(store: store)
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
    VotingView(store: .placeholder)
}
