import SwiftUI
import ComposableArchitecture

struct DelegationSetupView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PrototypeBanner()
                        .padding(.bottom, 24)

                    Text("Delegation Setup")
                        .font(.title2.bold())
                        .padding(.bottom, 8)

                    Text("You're authorizing a voting hotkey to cast votes with your ZEC balance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)

                    // Notes being delegated
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes being delegated")
                            .font(.headline)
                            .padding(.bottom, 4)

                        ForEach(Array(store.delegationNotes.enumerated()), id: \.element.id) { index, note in
                            HStack {
                                Text("Note \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(note.zecString) ZEC")
                                    .font(.subheadline.bold().monospaced())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        HStack {
                            Text("Total voting weight")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(store.votingWeightZECString) ZEC")
                                .font(.subheadline.bold().monospaced())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.bottom, 16)

                    // Round ID
                    HStack {
                        Text("Voting round")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(store.votingRound.roundIdTruncated)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 24)

                    // Safety note
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("This does NOT move your ZEC. It only proves you own this balance for voting purposes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 32)

                    // Sign button
                    Button {
                        store.send(.signWithKeystoneTapped)
                    } label: {
                        HStack {
                            Image(systemName: "signature")
                            Text("Sign with Keystone")
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
            .navigationTitle("Delegation Setup")
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
