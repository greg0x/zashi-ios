import Foundation
import ComposableArchitecture

@Reducer
public struct Voting {
    @ObservableState
    public struct State: Equatable {
        // Navigation
        public enum Screen: Equatable {
            case landing
            case delegationReview
            case delegationProgress
            case proposalList
            case proposalDetail(proposalId: String)
            case voteConfirm(proposalId: String, choice: VoteChoice)
            case submissionStatus
        }

        var screenStack: [Screen] = [.landing]

        // Data
        var votingRound: VotingRound
        var votes: [String: VoteChoice] = [:]
        var submissions: [String: VoteSubmission] = [:]
        var eligibleZatoshi: UInt64 = 150_350_000_000 // 1503.5 ZEC mock

        // Delegation
        var isDelegated: Bool = false
        var isDelegating: Bool = false
        var delegationProgress: Double = 0.0

        // Voting flow
        var isGeneratingProof: Bool = false

        // Power user
        var showSplitDecomposition: Bool = false

        // Current screen
        var currentScreen: Screen {
            screenStack.last ?? .landing
        }

        // Computed
        var eligibleZECString: String {
            let zec = Double(eligibleZatoshi) / 100_000_000.0
            return String(format: "%.2f", zec)
        }

        var proposalsVotedCount: Int {
            votes.count
        }

        var delegatedZECString: String {
            isDelegated ? eligibleZECString : "0"
        }

        public init(
            votingRound: VotingRound = MockVotingService.votingRound
        ) {
            self.votingRound = votingRound
        }
    }

    public enum Action {
        // Navigation
        case navigate(State.Screen)
        case goBack
        case popToProposalList

        // Landing
        case setUpVotingTapped
        case viewProposalsTapped

        // Delegation
        case delegationAuthorized
        case delegationProgressTick(Double)
        case delegationCompleted
        case continueToProposalsTapped

        // Voting
        case selectProposal(String)
        case voteChoice(proposalId: String, choice: VoteChoice)
        case confirmVote(proposalId: String, choice: VoteChoice)
        case cancelVote
        case proofGenerationCompleted(proposalId: String)
        case mockSubmissionTick(proposalId: String, splitIndex: Int)

        // Power user
        case toggleSplitDecomposition
        case viewSubmissionStatus
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            // MARK: - Navigation

            case .navigate(let screen):
                state.screenStack.append(screen)
                return .none

            case .goBack:
                if state.screenStack.count > 1 {
                    state.screenStack.removeLast()
                }
                return .none

            case .popToProposalList:
                // Pop back to proposal list
                while let last = state.screenStack.last, last != .proposalList {
                    state.screenStack.removeLast()
                }
                return .none

            // MARK: - Landing

            case .setUpVotingTapped:
                state.screenStack.append(.delegationReview)
                return .none

            case .viewProposalsTapped:
                state.screenStack.append(.proposalList)
                return .none

            // MARK: - Delegation

            case .delegationAuthorized:
                state.isDelegating = true
                state.delegationProgress = 0.0
                // Replace delegation review with delegation progress
                state.screenStack.removeLast()
                state.screenStack.append(.delegationProgress)
                return .run { send in
                    for i in 1...20 {
                        try await Task.sleep(for: .milliseconds(200))
                        await send(.delegationProgressTick(Double(i) / 20.0))
                    }
                    await send(.delegationCompleted)
                }

            case .delegationProgressTick(let progress):
                state.delegationProgress = progress
                return .none

            case .delegationCompleted:
                state.isDelegated = true
                state.isDelegating = false
                state.delegationProgress = 1.0
                return .none

            case .continueToProposalsTapped:
                state.screenStack = [.landing, .proposalList]
                return .none

            // MARK: - Voting

            case .selectProposal(let proposalId):
                state.screenStack.append(.proposalDetail(proposalId: proposalId))
                return .none

            case .voteChoice(let proposalId, let choice):
                state.screenStack.append(.voteConfirm(proposalId: proposalId, choice: choice))
                return .none

            case .confirmVote(let proposalId, let choice):
                state.votes[proposalId] = choice
                state.isGeneratingProof = true

                let splits = MockVotingService.binaryDecomposition(zatoshi: state.eligibleZatoshi)
                    .map { SplitSubmission(amount: $0) }
                let submission = VoteSubmission(
                    proposalId: proposalId,
                    choice: choice,
                    amount: state.eligibleZatoshi,
                    splits: splits
                )
                state.submissions[proposalId] = submission

                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    await send(.proofGenerationCompleted(proposalId: proposalId))
                }

            case .cancelVote:
                state.screenStack.removeLast()
                return .none

            case .proofGenerationCompleted(let proposalId):
                state.isGeneratingProof = false
                // Pop back to proposal list
                state.screenStack = [.landing, .proposalList]

                if let submission = state.submissions[proposalId] {
                    return .run { send in
                        for i in 0..<submission.splits.count {
                            try await Task.sleep(for: .milliseconds(800))
                            await send(.mockSubmissionTick(proposalId: proposalId, splitIndex: i))
                        }
                    }
                }
                return .none

            case .mockSubmissionTick(let proposalId, let splitIndex):
                if var submission = state.submissions[proposalId] {
                    if splitIndex < submission.splits.count {
                        submission.splits[splitIndex].status = .submitted
                        if splitIndex > 0 {
                            submission.splits[splitIndex - 1].status = .confirmed
                        }
                    }
                    // Mark last one as confirmed after submitted
                    if splitIndex == submission.splits.count - 1 {
                        submission.splits[splitIndex].status = .confirmed
                    }
                    state.submissions[proposalId] = submission
                }
                return .none

            // MARK: - Power user

            case .toggleSplitDecomposition:
                state.showSplitDecomposition.toggle()
                return .none

            case .viewSubmissionStatus:
                state.screenStack.append(.submissionStatus)
                return .none
            }
        }
    }
}
