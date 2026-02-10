import SwiftUI
import ComposableArchitecture

struct ZKPProgressView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    ProgressView()
                        .scaleEffect(2.0)
                        .padding(.bottom, 8)

                    Text("Generating Delegation Proof")
                        .font(.title3.bold())

                    // Step indicators
                    VStack(alignment: .leading, spacing: 16) {
                        stepRow(
                            label: "Generating delegation proof...",
                            step: .generatingProof
                        )
                        stepRow(
                            label: "Submitting to vote chain...",
                            step: .submitting
                        )
                        stepRow(
                            label: "Confirmed",
                            step: .confirmed
                        )
                    }
                    .padding(.horizontal, 40)

                    HStack(spacing: 6) {
                        MockBadge(isLive: false)
                        Text("ZKP #1 — simulated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .navigationTitle("Delegation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }

    @ViewBuilder
    private func stepRow(label: String, step: Voting.ZKPStep) -> some View {
        let currentStep = store.zkpStep
        let isActive = stepOrdinal(step) <= stepOrdinal(currentStep)
        let isCompleted = stepOrdinal(step) < stepOrdinal(currentStep)

        HStack(spacing: 12) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else if isActive {
                ProgressView()
                    .frame(width: 22, height: 22)
            } else {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 2)
                    .frame(width: 22, height: 22)
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    private func stepOrdinal(_ step: Voting.ZKPStep) -> Int {
        switch step {
        case .generatingProof: return 0
        case .submitting: return 1
        case .confirmed: return 2
        }
    }
}
