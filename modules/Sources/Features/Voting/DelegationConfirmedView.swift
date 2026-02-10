import SwiftUI
import ComposableArchitecture

struct DelegationConfirmedView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)

                    Text("Your voting hotkey is active")
                        .font(.title3.bold())

                    Text("\(store.votingWeightZECString) ZEC delegated for \(store.votingRound.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("You can vote now or return later. Your hotkey is saved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        store.send(.voteNowFromDelegation)
                    } label: {
                        Text("Vote Now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button {
                        store.send(.voteLaterTapped)
                    } label: {
                        Text("Vote Later")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Delegation Complete")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
}
