import Foundation

public struct VoteSubmission: Equatable, Identifiable {
    public let id: String
    public let proposalId: String
    public let choice: VoteChoice
    public let amount: UInt64
    public var splits: [SplitSubmission]

    public init(
        id: String = UUID().uuidString,
        proposalId: String,
        choice: VoteChoice,
        amount: UInt64,
        splits: [SplitSubmission]
    ) {
        self.id = id
        self.proposalId = proposalId
        self.choice = choice
        self.amount = amount
        self.splits = splits
    }
}

public struct SplitSubmission: Equatable, Identifiable {
    public let id: String
    public let amount: UInt64
    public var status: SubmissionStatus

    public init(
        id: String = UUID().uuidString,
        amount: UInt64,
        status: SubmissionStatus = .pending
    ) {
        self.id = id
        self.amount = amount
        self.status = status
    }
}

public enum SubmissionStatus: Equatable {
    case pending
    case submitted
    case confirmed
}
