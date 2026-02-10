import SwiftUI
import ComposableArchitecture

struct VotesLockedInView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)

                    Text("Your votes are locked in")
                        .font(.title3.bold())

                    Text("Your votes will be submitted to the chain privately over the coming hours.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Status
                    HStack(spacing: 8) {
                        switch store.votingStatus {
                        case .votesSubmitted:
                            ProgressView()
                                .frame(width: 16, height: 16)
                            Text("In progress...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        case .complete:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Complete")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 6) {
                        MockBadge(isLive: false)
                        Text("On-chain status: mocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    store.send(.doneTapped)
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Status")
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
}
