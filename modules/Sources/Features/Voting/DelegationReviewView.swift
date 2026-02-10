import SwiftUI
import ComposableArchitecture

struct DelegationReviewView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PrototypeBanner()
                        .padding(.bottom, 24)

                    Text("Authorize Voting Key")
                        .font(.title2.bold())
                        .padding(.bottom, 8)

                    Text("Authorize your ZEC for governance voting")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        infoRow(label: "Action", value: "Delegate full balance", isLive: false)
                        infoRow(label: "Eligible Balance", value: "\(store.eligibleZECString) ZEC", isLive: true)
                        infoRow(label: "Snapshot Height", value: "\(store.votingRound.snapshotHeight)", isLive: false)
                        infoRow(label: "Voting Round", value: store.votingRound.title, isLive: false)
                    }
                    .padding(.bottom, 24)

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("This does not move your funds. You are authorizing a voting key to vote with your full balance.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 32)

                    HStack(spacing: 6) {
                        MockBadge(isLive: false)
                        Text("Using dummy Orchard self-send (not governance circuit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 16)

                    Button {
                        store.send(.delegationAuthorized)
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Authorize with Keystone")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Delegation Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.send(.goBack) } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, isLive: Bool) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline.bold())
                MockBadge(isLive: isLive)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
