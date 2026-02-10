import Foundation

public enum MockVotingService {
    public static let votingRound = VotingRound(
        id: "nu7-2025",
        title: "NU7 Governance Vote",
        snapshotHeight: 2_800_000,
        deadline: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
        proposals: proposals
    )

    public static let proposals: [Proposal] = [
        Proposal(
            id: "zsa",
            title: "Zcash Shielded Assets (ZSAs)",
            description: "Enable custom tokens on the Zcash network via shielded asset issuance and transfer, expanding Zcash beyond ZEC while preserving privacy.",
            zipNumber: "ZIP-227",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/zsa")
        ),
        Proposal(
            id: "nsm",
            title: "Network Sustainability Mechanism",
            description: "Introduce a smoothed, market-based issuance mechanism to ensure long-term sustainability of network security incentives.",
            zipNumber: "ZIP-234",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/nsm")
        ),
        Proposal(
            id: "crosschain-bridges",
            title: "Zcash ↔ Ethereum Bridge",
            description: "Enable trustless bridging of ZEC and ZSAs between Zcash and Ethereum, unlocking DeFi participation while maintaining privacy.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/bridge")
        ),
        Proposal(
            id: "proof-of-stake",
            title: "Hybrid Proof-of-Stake",
            description: "Transition Zcash to a hybrid PoS consensus mechanism, improving energy efficiency and enabling staking-based governance.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/pos")
        ),
        Proposal(
            id: "zashi-mobile",
            title: "Zashi Mobile Enhancements",
            description: "Fund continued development of the Zashi mobile wallet, including improved sync performance, better UX, and new features.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/zashi")
        ),
        Proposal(
            id: "zcash-memo-standard",
            title: "Structured Memo Fields",
            description: "Standardize memo field formats across the ecosystem for interoperable messaging, payment requests, and metadata.",
            zipNumber: "ZIP-302",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/memo")
        ),
        Proposal(
            id: "shielded-multisig",
            title: "Shielded Multi-Signature",
            description: "Enable threshold-signature spending from shielded pools, allowing organizations to hold and transact ZEC with m-of-n authorization.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/multisig")
        ),
        Proposal(
            id: "privacy-metrics",
            title: "Privacy Metrics Dashboard",
            description: "Fund research and tooling to measure and report on the privacy guarantees of the Zcash network in practice.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/metrics")
        ),
        Proposal(
            id: "dev-tooling",
            title: "Developer Tooling Grants",
            description: "Allocate funds for SDKs, documentation, and developer experience improvements to grow the Zcash builder ecosystem.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/devtools")
        ),
        Proposal(
            id: "regulatory-defense",
            title: "Regulatory & Legal Defense Fund",
            description: "Establish a legal defense fund to protect privacy technology and its users from regulatory overreach.",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/legal")
        ),
        Proposal(
            id: "network-upgrade-cadence",
            title: "Biannual Network Upgrade Cadence",
            description: "Formalize a predictable 6-month network upgrade cycle to improve coordination and reduce risk in protocol development.",
            zipNumber: "ZIP-400",
            forumURL: URL(string: "https://forum.zcashcommunity.com/t/cadence")
        ),
    ]

    /// Binary decomposition of a ZEC amount into powers of 2
    public static func binaryDecomposition(zatoshi: UInt64) -> [UInt64] {
        var result: [UInt64] = []
        var remaining = zatoshi
        var bit: UInt64 = 1

        while remaining > 0 {
            if remaining & 1 == 1 {
                result.append(bit)
            }
            remaining >>= 1
            bit <<= 1
        }

        return result.reversed()
    }
}
