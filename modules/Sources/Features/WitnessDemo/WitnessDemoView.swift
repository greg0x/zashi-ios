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
                // Witness generation success
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
                        Text("Auth Path Preview")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        Text(result.authPathPreview)
                            .zFont(size: 10, style: Design.Text.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))

                // Verification section (separate card)
                verificationSection(result)
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

    @ViewBuilder
    private func verificationSection(_ result: WitnessResultDisplay) -> some View {
        let isVerified = result.rootsMatch == true

        VStack(alignment: .leading, spacing: 12) {
            verificationHeader(result)

            if result.expectedRootHex != nil {
                rootComparisonView(result)
            }

            Text("The wallet computed a Merkle proof locally. We verified it by fetching the tree root at this height from lightwalletd and confirming they match. For voting, this root would be compared against the publicly committed snapshot root.")
                .zFont(size: 11, style: Design.Text.tertiary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(isVerified ? Color.blue.opacity(0.08) : Color(.systemGray6)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isVerified ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
    }

    @ViewBuilder
    private func verificationHeader(_ result: WitnessResultDisplay) -> some View {
        HStack(spacing: 12) {
            if let rootsMatch = result.rootsMatch {
                verificationBadge(success: rootsMatch)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rootsMatch ? "Independent Verification Passed" : "Verification Failed")
                        .zFont(.semiBold, size: 16, style: Design.Text.primary)
                    Text("Root confirmed by lightwalletd")
                        .zFont(size: 12, style: Design.Text.tertiary)
                }
            } else {
                verificationBadge(success: nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verification Pending")
                        .zFont(.semiBold, size: 16, style: Design.Text.primary)
                    Text("Could not fetch root from lightwalletd")
                        .zFont(size: 12, style: Design.Text.tertiary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func verificationBadge(success: Bool?) -> some View {
        let color: Color = {
            switch success {
            case true: return .green
            case false: return .red
            case nil: return .orange
            }
        }()
        let icon: String = {
            switch success {
            case true: return "checkmark"
            case false: return "xmark"
            case nil: return "questionmark"
            }
        }()

        ZStack {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private func rootComparisonView(_ result: WitnessResultDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            rootDisplayBox(icon: "laptopcomputer", label: "Local Witness Root", value: result.rootHex)
            rootDisplayBox(icon: "server.rack", label: "Lightwalletd Tree Root", value: result.expectedRootHex ?? "")

            if let rootsMatch = result.rootsMatch {
                HStack(spacing: 6) {
                    Image(systemName: rootsMatch ? "equal.circle.fill" : "not.equal.circle.fill")
                        .foregroundColor(rootsMatch ? .green : .red)
                    Text(rootsMatch ? "Roots match - witness is valid" : "Roots do not match")
                        .zFont(.medium, size: 12, style: Design.Text.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func rootDisplayBox(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(label)
                    .zFont(.medium, size: 12, style: Design.Text.tertiary)
            }
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)))
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
