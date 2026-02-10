import SwiftUI
import ComposableArchitecture

struct DelegationProgressView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    if store.isDelegated {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                    } else {
                        ProgressView()
                            .scaleEffect(2.0)
                            .padding(.bottom, 8)
                    }

                    Text(store.isDelegated ? "Delegation Complete" : "Generating Delegation Proof...")
                        .font(.title3.bold())

                    HStack(spacing: 6) {
                        MockBadge(isLive: false)
                        Text("ZKP #1 — simulated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        ProgressView(value: store.delegationProgress)
                            .tint(store.isDelegated ? .green : .blue)

                        Text("\(Int(store.delegationProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 40)

                    if store.isDelegated {
                        Text("You can now vote on proposals.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if store.isDelegated {
                    Button {
                        store.send(.continueToProposalsTapped)
                    } label: {
                        Text("Continue to Proposals")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Delegation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(!store.isDelegated)
        }
    }
}
