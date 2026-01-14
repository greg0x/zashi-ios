//
//  PIRVerificationStore.swift
//  Zashi
//
//  Created for PIR integration.
//

import Foundation
import ComposableArchitecture
import ZcashLightClientKit

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
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .onDisappear:
                return .cancel(id: CancelID.verification)
                
            case .startVerification:
                state.verificationState = .connecting
                
                return .run { send in
                    // TODO: Integrate with actual PIR client when available
                    // For now, simulate the verification flow
                    
                    // Simulate connecting
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(.verificationStateChanged(.preparingKeys))
                    
                    // Simulate key preparation
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    
                    // Simulate verification of 5 notes
                    let totalNotes = 5
                    for i in 1...totalNotes {
                        await send(.verificationProgress(i, totalNotes))
                        try await Task.sleep(nanoseconds: 500_000_000)
                    }
                    
                    // Simulate completion
                    await send(.verificationCompleted(checkedCount: totalNotes, newlySpentCount: 0))
                    
                } catch: { error, send in
                    if error is CancellationError {
                        await send(.verificationStateChanged(.idle))
                    } else {
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
