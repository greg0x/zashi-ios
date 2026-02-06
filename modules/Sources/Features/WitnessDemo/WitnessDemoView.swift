//
//  WitnessDemoView.swift
//  Zashi
//
//  Demo UI for voting proposal verification - generates Merkle witnesses at historical heights.
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct WitnessDemoView: View {
    @Perception.Bindable var store: StoreOf<WitnessDemo>

    public init(store: StoreOf<WitnessDemo>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 20) {
                    infoSection
                    notesSection
                    if store.selectedNote != nil {
                        witnessSection
                    }
                    resultSection
                    errorSection
                }
                .padding(16)
            }
            .applyScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .zashiBack()
            .screenTitle("Witness Demo")
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voting Proposal Verification")
                .zFont(.semiBold, size: 16, style: Design.Text.primary)

            Text("This demo proves wallets can generate Merkle inclusion proofs at historical heights locally. Select a note, choose a snapshot height, and generate a witness.")
                .zFont(size: 13, style: Design.Text.tertiary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Orchard Notes")
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)
                Spacer()
                if store.isLoadingNotes {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if store.notes.isEmpty && !store.isLoadingNotes {
                Text("No Orchard notes found. Receive some ZEC to an Orchard address first.")
                    .zFont(size: 13, style: Design.Text.tertiary)
                    .italic()
            } else {
                ForEach(store.notes) { note in
                    noteRow(note)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    @ViewBuilder
    private func noteRow(_ note: OrchardNoteDisplay) -> some View {
        let isSelected = store.selectedNote?.noteId == note.noteId

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.8f ZEC", note.valueZEC))
                    .zFont(.medium, size: 14, style: Design.Text.primary)
                Text("Height: \(note.minedHeight) | Pos: \(note.position)")
                    .zFont(size: 11, style: Design.Text.tertiary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemGray5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.selectNote(note))
        }
    }

    // MARK: - Witness Section

    @ViewBuilder
    private var witnessSection: some View {
        if let note = store.selectedNote {
            VStack(alignment: .leading, spacing: 12) {
                Text("Generate Witness")
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Note")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    Text("\(String(format: "%.8f", note.valueZEC)) ZEC at position \(note.position)")
                        .zFont(.medium, size: 14, style: Design.Text.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Checkpoint/Snapshot Height")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    TextField("Height", text: $store.checkpointHeightInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Text("Must be >= \(note.minedHeight) (note's mined height)")
                        .zFont(size: 10, style: Design.Text.tertiary)
                }

                HStack(spacing: 12) {
                    Button {
                        store.send(.generateWitness)
                    } label: {
                        HStack {
                            if store.isGeneratingWitness {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(store.isGeneratingWitness ? "Generating..." : "Get Witness")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isGeneratingWitness)

                    Button("Clear") {
                        store.send(.clearResult)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let result = store.witnessResult {
            VStack(alignment: .leading, spacing: 16) {
                // Witness generation result
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Witness Generated")
                            .zFont(.semiBold, size: 16, style: Design.Text.primary)
                    }

                    Group {
                        resultRow("Position", "\(result.position)")
                        resultRow("Path Length", "\(result.pathLength) (Orchard tree depth)")
                        resultRow("Time", String(format: "%.1f ms", result.timingMs))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note Commitment (leaf)")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        Text(result.noteCommitmentHex)
                            .font(.system(size: 9, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tree Root at Snapshot")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        Text(result.rootHex)
                            .font(.system(size: 9, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))

                // Verification result
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(result.isVerified ? Color.blue : Color.red)
                                .frame(width: 44, height: 44)
                            Image(systemName: result.isVerified ? "checkmark" : "xmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.isVerified ? "Merkle Proof Verified" : "Verification Failed")
                                .zFont(.semiBold, size: 16, style: Design.Text.primary)
                            Text("Recomputed root from commitment + auth path")
                                .zFont(size: 12, style: Design.Text.tertiary)
                        }
                    }

                    Text("The Merkle path was verified by hashing the note commitment up through the auth path siblings. This is exactly what the ZKP circuit will do to prove the note existed at the snapshot height.")
                        .zFont(size: 11, style: Design.Text.tertiary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(result.isVerified ? Color.blue.opacity(0.08) : Color.red.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(result.isVerified ? Color.blue.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .zFont(size: 13, style: Design.Text.tertiary)
            Spacer()
            Text(value)
                .zFont(.medium, size: 13, style: Design.Text.primary)
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error = store.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                        .zFont(.semiBold, size: 14, style: Design.Text.primary)
                }
                Text(error)
                    .zFont(size: 13, style: Design.Text.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        WitnessDemoView(
            store: Store(initialState: WitnessDemo.State()) {
                WitnessDemo()
            }
        )
    }
}
