import Foundation

public struct VotingRound: Equatable {
    public let id: String
    public let title: String
    public let snapshotHeight: UInt64
    public let deadline: Date
    public let proposals: [Proposal]

    public init(
        id: String,
        title: String,
        snapshotHeight: UInt64,
        deadline: Date,
        proposals: [Proposal]
    ) {
        self.id = id
        self.title = title
        self.snapshotHeight = snapshotHeight
        self.deadline = deadline
        self.proposals = proposals
    }
}
