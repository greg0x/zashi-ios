import Foundation

public struct DelegationNote: Equatable, Identifiable {
    public let id: String
    public let amount: UInt64

    public init(id: String = UUID().uuidString, amount: UInt64) {
        self.id = id
        self.amount = amount
    }

    public var zecString: String {
        let zec = Double(amount) / 100_000_000.0
        return String(format: "%.2f", zec)
    }
}

public enum VotingStatus: Equatable, Codable {
    case notStarted
    case delegated
    case votesSubmitted
    case complete
}
