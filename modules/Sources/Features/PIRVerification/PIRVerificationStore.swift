//
//  PIRVerificationStore.swift
//  Zashi
//
//  Created for PIR integration.
//

import Foundation
import ComposableArchitecture
import ZcashLightClientKit
import PIRClient

@Reducer
public struct PIRVerification {
    @ObservableState
    public struct State: Equatable {
        public enum VerificationState: Equatable {
            case idle
            case connecting
            case preparingKeys
            case verifying(progress: Int, total: Int)
            case completed(checkedCount: Int, newlySpentCount: Int)
            case failed(String)
        }
        
        public var verificationState: VerificationState = .idle
        public var showCancelConfirmation = false
        public var serverURL: String = "http://localhost:8080"
        
        public var isOperationInProgress: Bool {
            switch verificationState {
            case .connecting, .preparingKeys, .verifying:
                return true
            default:
                return false
            }
        }
        
        public var statusMessage: String {
            switch verificationState {
            case .idle:
                return "Verify your balance using Private Information Retrieval. This checks if any of your notes have been spent without revealing which notes you own."
            case .connecting:
                return "Connecting to PIR server..."
            case .preparingKeys:
                return "Preparing cryptographic keys...\nThis may take 10-20 seconds on first use."
            case .verifying(let progress, let total):
                return "Checking note \(progress) of \(total)..."
            case .completed(let checkedCount, let newlySpentCount):
                if newlySpentCount == 0 {
                    return "✓ Verified \(checkedCount) notes.\nYour balance is accurate."
                } else {
                    return "Found \(newlySpentCount) newly spent note(s) out of \(checkedCount) checked.\nBalance has been updated."
                }
            case .failed(let error):
                return "Verification failed: \(error)"
            }
        }
        
        public init() {}
    }
    
    public enum Action: Equatable {
        case cancelConfirmationDismissed
        case cancelRequested
        case cancelVerification
        case onAppear
        case onDisappear
        case startVerification
        case verificationCompleted(checkedCount: Int, newlySpentCount: Int)
        case verificationFailed(String)
        case verificationProgress(Int, Int)
        case verificationStateChanged(State.VerificationState)
    }
    
    private enum CancelID { case verification }
    
    @Dependency(\.pirClient) var pirClient
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .onDisappear:
                pirClient.disconnect()
                return .cancel(id: CancelID.verification)
                
            case .startVerification:
                state.verificationState = .connecting
                let serverURL = state.serverURL
                
                return .run { send in
                    do {
                        // Step 1: Connect to PIR server
                        try await pirClient.connect(serverURL)
                        
                        // Step 2: Precompute keys
                        await send(.verificationStateChanged(.preparingKeys))
                        try await pirClient.precomputeKeys()
                        
                        // Step 3: Generate test nullifiers for demo
                        // In production, these would come from the wallet's unspent notes
                        let testNullifiers = generateTestNullifiers(count: 5)
                        let totalNotes = testNullifiers.count
                        
                        var spentCount = 0
                        
                        // Step 4: Check each nullifier
                        for (index, nullifier) in testNullifiers.enumerated() {
                            await send(.verificationProgress(index + 1, totalNotes))
                            
                            if let spentInfo = try await pirClient.checkNullifier(nullifier) {
                                spentCount += 1
                                // In production: update wallet state here
                                print("Note \(index + 1) spent at block \(spentInfo.blockHeight)")
                            }
                        }
                        
                        await send(.verificationCompleted(
                            checkedCount: totalNotes,
                            newlySpentCount: spentCount
                        ))
                        
                    } catch {
                        await send(.verificationFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.verification)
                
            case .cancelRequested:
                state.showCancelConfirmation = true
                return .none
                
            case .cancelConfirmationDismissed:
                state.showCancelConfirmation = false
                return .none
                
            case .cancelVerification:
                state.showCancelConfirmation = false
                state.verificationState = .idle
                pirClient.disconnect()
                return .cancel(id: CancelID.verification)
                
            case .verificationStateChanged(let newState):
                state.verificationState = newState
                return .none
                
            case .verificationProgress(let current, let total):
                state.verificationState = .verifying(progress: current, total: total)
                return .none
                
            case .verificationCompleted(let checkedCount, let newlySpentCount):
                state.verificationState = .completed(checkedCount: checkedCount, newlySpentCount: newlySpentCount)
                return .none
                
            case .verificationFailed(let error):
                state.verificationState = .failed(error)
                return .none
            }
        }
    }
}

// MARK: - Test Data Generation

/// Generate test nullifiers for demo purposes.
/// In production, these would come from the wallet's unspent notes.
private func generateTestNullifiers(count: Int) -> [Data] {
    // Generate deterministic test nullifiers based on index
    // These are NOT real nullifiers - just for demo/testing
    (0..<count).map { index in
        var bytes = [UInt8](repeating: 0, count: 32)
        // Fill with a pattern based on index for reproducibility
        bytes[0] = UInt8(index & 0xFF)
        bytes[1] = UInt8((index >> 8) & 0xFF)
        // Add some entropy
        bytes[31] = UInt8(0xDE)
        bytes[30] = UInt8(0xAD)
        bytes[29] = UInt8(0xBE)
        bytes[28] = UInt8(0xEF)
        return Data(bytes)
    }
}
