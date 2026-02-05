//
//  WitnessDemoStore.swift
//  Zashi
//
//  Demo UI for voting proposal verification - generates Merkle witnesses at historical heights.
//

import Foundation
import ComposableArchitecture
import ZcashLightClientKit
import SDKSynchronizer

@Reducer
public struct WitnessDemo {
    @ObservableState
    public struct State: Equatable {
        // Loading state
        public var isLoadingNotes: Bool = false
        public var isGeneratingWitness: Bool = false

        // Notes list
        public var notes: [OrchardNoteDisplay] = []

        // Selected note
        public var selectedNote: OrchardNoteDisplay?

        // Checkpoint height input
        public var checkpointHeightInput: String = ""

        // Witness result
        public var witnessResult: WitnessResultDisplay?

        // Error
        public var errorMessage: String?

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case onDisappear

        // Notes
        case loadNotes
        case notesLoaded([OrchardNoteDisplay])
        case notesFailed(String)
        case selectNote(OrchardNoteDisplay)

        // Witness
        case generateWitness
        case witnessGenerated(WitnessResultDisplay)
        case witnessFailed(String)

        // Clear
        case clearResult
    }

    @Dependency(\.sdkSynchronizer) var sdkSynchronizer

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.loadNotes)

            case .onDisappear:
                return .none

            // MARK: - Notes

            case .loadNotes:
                state.isLoadingNotes = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        let data = try await sdkSynchronizer.listOrchardNotes()
                        let notes = parseOrchardNotes(from: data)
                        await send(.notesLoaded(notes))
                    } catch {
                        await send(.notesFailed(error.localizedDescription))
                    }
                }

            case .notesLoaded(let notes):
                state.isLoadingNotes = false
                state.notes = notes
                return .none

            case .notesFailed(let error):
                state.isLoadingNotes = false
                state.errorMessage = error
                return .none

            case .selectNote(let note):
                state.selectedNote = note
                state.witnessResult = nil
                state.errorMessage = nil
                // Pre-fill checkpoint height with mined height
                state.checkpointHeightInput = String(note.minedHeight)
                return .none

            // MARK: - Witness

            case .generateWitness:
                guard let note = state.selectedNote else {
                    state.errorMessage = "No note selected"
                    return .none
                }

                guard let checkpointHeight = UInt32(state.checkpointHeightInput) else {
                    state.errorMessage = "Invalid checkpoint height"
                    return .none
                }

                if checkpointHeight < note.minedHeight {
                    state.errorMessage = "Checkpoint height must be >= note's mined height (\(note.minedHeight))"
                    return .none
                }

                // Check against chain tip to prevent future block requests
                let latestBlockHeight = sdkSynchronizer.latestState().latestBlockHeight
                if latestBlockHeight > 0 && checkpointHeight > latestBlockHeight {
                    state.errorMessage = "Height \(checkpointHeight) is beyond the current chain tip (\(latestBlockHeight)). Wallet can only prove inclusion for heights it has synced."
                    return .none
                }

                state.isGeneratingWitness = true
                state.errorMessage = nil
                state.witnessResult = nil

                let notePosition = note.position

                return .run { send in
                    do {
                        let startTime = Date()
                        let data = try await sdkSynchronizer.getOrchardWitnessAtHeight(
                            notePosition: notePosition,
                            checkpointHeight: BlockHeight(checkpointHeight)
                        )
                        let elapsed = Date().timeIntervalSince(startTime) * 1000

                        // Fetch expected root for verification
                        var expectedRootHex: String?
                        var rootsMatch: Bool?
                        do {
                            let expectedRoot = try await sdkSynchronizer.getOrchardTreeRoot(at: BlockHeight(checkpointHeight))
                            expectedRootHex = expectedRoot.map { String(format: "%02x", $0) }.joined()
                            // Compare with witness root (bytes 8-39)
                            if data.count >= 40 {
                                let witnessRoot = data.subdata(in: 8..<40)
                                rootsMatch = (witnessRoot == expectedRoot)
                            }
                        } catch {
                            // Verification failed but witness was generated - still show result
                            expectedRootHex = "fetch failed: \(error.localizedDescription)"
                        }

                        let result = parseWitnessResult(from: data, timingMs: elapsed, expectedRootHex: expectedRootHex, rootsMatch: rootsMatch)
                        await send(.witnessGenerated(result))
                    } catch {
                        await send(.witnessFailed(error.localizedDescription))
                    }
                }

            case .witnessGenerated(let result):
                state.isGeneratingWitness = false
                state.witnessResult = result
                return .none

            case .witnessFailed(let error):
                state.isGeneratingWitness = false
                state.errorMessage = error
                return .none

            case .clearResult:
                state.selectedNote = nil
                state.witnessResult = nil
                state.errorMessage = nil
                state.checkpointHeightInput = ""
                return .none
            }
        }
    }
}

// MARK: - Parsing Helpers

/// Parse the serialized orchard notes from FFI.
/// Format: 4 bytes count + N * (8 + 8 + 8 + 4) bytes per note
private func parseOrchardNotes(from data: Data) -> [OrchardNoteDisplay] {
    guard data.count >= 4 else { return [] }

    let count = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    var notes: [OrchardNoteDisplay] = []
    var offset = 4

    for _ in 0..<count {
        guard offset + 28 <= data.count else { break }

        let noteId = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int64.self) }
        offset += 8

        let position = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }
        offset += 8

        let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }
        offset += 8

        let minedHeight = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
        offset += 4

        notes.append(OrchardNoteDisplay(
            noteId: noteId,
            position: position,
            valueZats: value,
            minedHeight: minedHeight
        ))
    }

    return notes
}

/// Parse the serialized witness result from FFI.
/// Format: position (8) + root (32) + path_len (4) + auth_path (32*32)
private func parseWitnessResult(from data: Data, timingMs: Double, expectedRootHex: String? = nil, rootsMatch: Bool? = nil) -> WitnessResultDisplay {
    guard data.count >= 44 else {
        return WitnessResultDisplay(
            position: 0,
            rootHex: "invalid",
            pathLength: 0,
            authPathPreview: "invalid",
            timingMs: timingMs,
            expectedRootHex: expectedRootHex,
            rootsMatch: rootsMatch
        )
    }

    let position = data.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }

    let rootData = data.subdata(in: 8..<40)
    let rootHex = rootData.map { String(format: "%02x", $0) }.joined()

    let pathLength = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 40, as: UInt32.self) }

    // Show first 2 path elements as preview
    var authPathPreview = ""
    if data.count >= 108 { // 44 + 64 (2 elements)
        let firstElement = data.subdata(in: 44..<76)
        let secondElement = data.subdata(in: 76..<108)
        authPathPreview = firstElement.prefix(8).map { String(format: "%02x", $0) }.joined()
            + "... "
            + secondElement.prefix(8).map { String(format: "%02x", $0) }.joined()
            + "..."
    }

    return WitnessResultDisplay(
        position: position,
        rootHex: rootHex,
        pathLength: pathLength,
        authPathPreview: authPathPreview,
        timingMs: timingMs,
        expectedRootHex: expectedRootHex,
        rootsMatch: rootsMatch
    )
}

// MARK: - Display Types

public struct OrchardNoteDisplay: Equatable, Identifiable {
    public var id: Int64 { noteId }
    public let noteId: Int64
    public let position: UInt64
    public let valueZats: UInt64
    public let minedHeight: UInt32

    public var valueZEC: Double {
        Double(valueZats) / 100_000_000.0
    }
}

public struct WitnessResultDisplay: Equatable {
    public let position: UInt64
    public let rootHex: String
    public let pathLength: UInt32
    public let authPathPreview: String
    public let timingMs: Double
    // Verification
    public let expectedRootHex: String?
    public let rootsMatch: Bool?
}
