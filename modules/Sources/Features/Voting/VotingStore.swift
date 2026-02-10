import Foundation
import ComposableArchitecture

@Reducer
public struct Voting {
    @ObservableState
    public struct State: Equatable {
        // Navigation
        public enum Screen: Equatable {
            case landing
            case delegationSetup
            case keystoneSigning
            case zkpProgress
            case delegationConfirmed
            case proposalVoting(index: Int)
            case voteReview
            case voteSubmission
            case votesLockedIn
        }

        var screenStack: [Screen] = [.landing]

        // Data
        var votingRound: VotingRound
        var delegationNotes: [DelegationNote]
        var votingWeight: UInt64
        var votes: [String: VoteChoice] = [:]

        // Status
        var votingStatus: VotingStatus = .notStarted

        // Delegation progress
        var zkpStep: ZKPStep = .generatingProof
        var zkpCompleted: Bool = false

        // Vote submission
        var isSubmitting: Bool = false

        // Current screen
        var currentScreen: Screen {
            screenStack.last ?? .landing
        }

        // Computed
        var votingWeightZECString: String {
            let zec = Double(votingWeight) / 100_000_000.0
            return String(format: "%.2f", zec)
        }

        var isEligible: Bool {
            // Minimum 0.125 ZEC = 12_500_000 zatoshi
            votingWeight >= 12_500_000
        }

        var currentProposalIndex: Int {
            if case .proposalVoting(let index) = currentScreen {
                return index
            }
            return 0
        }

        var currentProposal: Proposal? {
            let idx = currentProposalIndex
            guard idx >= 0 && idx < votingRound.proposals.count else { return nil }
            return votingRound.proposals[idx]
        }

        var totalProposals: Int {
            votingRound.proposals.count
        }

        public init(
            votingRound: VotingRound = MockVotingService.votingRound,
            delegationNotes: [DelegationNote] = MockVotingService.delegationNotes,
            votingWeight: UInt64 = MockVotingService.votingWeight
        ) {
            self.votingRound = votingRound
            self.delegationNotes = delegationNotes
            self.votingWeight = votingWeight
        }
    }

    public enum ZKPStep: Equatable {
        case generatingProof
        case submitting
        case confirmed
    }

    public enum Action {
        // Navigation
        case dismissFlow
        case goBack

        // Landing
        case setUpVotingTapped
        case voteNowTapped
        case viewStatusTapped

        // Delegation setup
        case signWithKeystoneTapped

        // Keystone signing
        case keystoneApproved
        case keystoneRejected

        // ZKP progress
        case zkpStepAdvanced(ZKPStep)
        case zkpCompleted

        // Delegation confirmed
        case voteNowFromDelegation
        case voteLaterTapped

        // Proposal voting
        case castVote(proposalId: String, choice: VoteChoice)
        case skipProposal(proposalId: String)
        case previousProposal

        // Vote review
        case submitVotesTapped
        case editVote(proposalIndex: Int)

        // Vote submission
        case submissionCompleted

        // Votes locked in
        case doneTapped
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            // MARK: - Navigation

            case .dismissFlow:
                return .none

            case .goBack:
                if state.screenStack.count > 1 {
                    state.screenStack.removeLast()
                }
                return .none

            // MARK: - Landing

            case .setUpVotingTapped:
                state.screenStack.append(.delegationSetup)
                return .none

            case .voteNowTapped:
                state.screenStack.append(.proposalVoting(index: 0))
                return .none

            case .viewStatusTapped:
                state.screenStack.append(.votesLockedIn)
                return .none

            // MARK: - Delegation Setup

            case .signWithKeystoneTapped:
                state.screenStack.append(.keystoneSigning)
                return .none

            // MARK: - Keystone Signing

            case .keystoneApproved:
                // Replace keystone screen with ZKP progress
                state.screenStack.removeLast()
                state.screenStack.append(.zkpProgress)
                state.zkpStep = .generatingProof
                state.zkpCompleted = false
                return .run { send in
                    // Step 1: Generating proof (~3 seconds)
                    try await Task.sleep(for: .seconds(3))
                    await send(.zkpStepAdvanced(.submitting))
                    // Step 2: Submitting (~1 second)
                    try await Task.sleep(for: .seconds(1))
                    await send(.zkpStepAdvanced(.confirmed))
                    // Brief pause then complete
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.zkpCompleted)
                }

            case .keystoneRejected:
                state.screenStack.removeLast()
                return .none

            // MARK: - ZKP Progress

            case .zkpStepAdvanced(let step):
                state.zkpStep = step
                return .none

            case .zkpCompleted:
                state.zkpCompleted = true
                state.votingStatus = .delegated
                // Replace ZKP progress with delegation confirmed
                state.screenStack.removeLast()
                state.screenStack.append(.delegationConfirmed)
                return .none

            // MARK: - Delegation Confirmed

            case .voteNowFromDelegation:
                // Reset stack to landing + first proposal
                state.screenStack = [.landing, .proposalVoting(index: 0)]
                return .none

            case .voteLaterTapped:
                // Pop back to landing
                state.screenStack = [.landing]
                return .none

            // MARK: - Proposal Voting

            case .castVote(let proposalId, let choice):
                state.votes[proposalId] = choice
                return advanceToNextProposal(state: &state)

            case .skipProposal(let proposalId):
                state.votes[proposalId] = .skip
                return advanceToNextProposal(state: &state)

            case .previousProposal:
                if case .proposalVoting(let index) = state.currentScreen, index > 0 {
                    state.screenStack.removeLast()
                    state.screenStack.append(.proposalVoting(index: index - 1))
                }
                return .none

            // MARK: - Vote Review

            case .submitVotesTapped:
                state.screenStack.append(.voteSubmission)
                state.isSubmitting = true
                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    await send(.submissionCompleted)
                }

            case .editVote(let proposalIndex):
                state.screenStack.append(.proposalVoting(index: proposalIndex))
                return .none

            // MARK: - Vote Submission

            case .submissionCompleted:
                state.isSubmitting = false
                state.votingStatus = .votesSubmitted
                // Replace submission screen with locked in
                state.screenStack.removeLast()
                state.screenStack.append(.votesLockedIn)
                return .none

            // MARK: - Votes Locked In

            case .doneTapped:
                state.screenStack = [.landing]
                return .none
            }
        }
    }

    private func advanceToNextProposal(state: inout State) -> Effect<Action> {
        if case .proposalVoting(let index) = state.currentScreen {
            let nextIndex = index + 1
            if nextIndex < state.votingRound.proposals.count {
                state.screenStack.removeLast()
                state.screenStack.append(.proposalVoting(index: nextIndex))
            } else {
                // All proposals done, go to review
                state.screenStack.removeLast()
                state.screenStack.append(.voteReview)
            }
        }
        return .none
    }
}
