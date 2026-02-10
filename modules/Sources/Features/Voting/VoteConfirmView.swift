import SwiftUI
import ComposableArchitecture

struct VoteSubmissionView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(2.0)
                        .padding(.bottom, 8)

                    Text("Submitting your votes...")
                        .font(.title3.bold())

                    Text("Your votes are being submitted privately. This may take a moment.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        MockBadge(isLive: false)
                        Text("Simulated submission")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Submitting")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
}
