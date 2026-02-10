import SwiftUI
import ComposableArchitecture

struct VotingLandingView: View {
    let store: StoreOf<Voting>

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PrototypeBanner()
                        .padding(.bottom, 24)

                    // Round title
                    Text(store.votingRound.title)
                        .font(.title2.bold())
                        .padding(.bottom, 8)

                    // Description
                    Text(store.votingRound.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)

                    // Snapshot & voting window info
                    VStack(spacing: 8) {
                        infoRow(label: "Snapshot", value: "Height \(store.votingRound.snapshotHeight) (\(formattedDate(store.votingRound.snapshotDate)))")
                        infoRow(label: "Voting window", value: "\(formattedDate(store.votingRound.votingStart)) — \(formattedDate(store.votingRound.votingEnd))")
                    }
                    .padding(.bottom, 24)

                    // Voting weight
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your voting weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if store.isEligible {
                            Text("\(store.votingWeightZECString) ZEC voting power")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        } else {
                            Text("Ineligible")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                            Text("Minimum 0.125 ZEC required at snapshot height")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 24)

                    // Status banner
                    statusBanner
                        .padding(.bottom, 32)

                    // CTA button
                    ctaButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Governance Voting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.send(.dismissFlow) } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onReceive(timer) { _ in
                now = Date()
            }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        switch store.votingStatus {
        case .notStarted:
            statusRow(
                icon: "circle.dashed",
                iconColor: .gray,
                text: "Not started",
                detail: "Set up your voting hotkey to participate",
                background: Color(.systemGray6)
            )
        case .delegated:
            statusRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                text: "Delegated",
                detail: "\(store.votingWeightZECString) ZEC ready to vote",
                background: Color.green.opacity(0.1)
            )
        case .votesSubmitted:
            statusRow(
                icon: "paperplane.fill",
                iconColor: .blue,
                text: "Votes submitted",
                detail: "Your votes are being distributed privately",
                background: Color.blue.opacity(0.1)
            )
        case .complete:
            statusRow(
                icon: "checkmark.seal.fill",
                iconColor: .green,
                text: "Complete",
                detail: "All votes confirmed on-chain",
                background: Color.green.opacity(0.1)
            )
        }
    }

    @ViewBuilder
    private func statusRow(icon: String, iconColor: Color, text: String, detail: String, background: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - CTA Button

    @ViewBuilder
    private var ctaButton: some View {
        if !store.isEligible { EmptyView() }
        else {
            switch store.votingStatus {
            case .notStarted:
                Button {
                    store.send(.setUpVotingTapped)
                } label: {
                    Text("Set Up Voting")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            case .delegated:
                Button {
                    store.send(.voteNowTapped)
                } label: {
                    Text("Vote Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            case .votesSubmitted:
                Button {
                    store.send(.viewStatusTapped)
                } label: {
                    Text("View Status")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            case .complete:
                EmptyView()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
