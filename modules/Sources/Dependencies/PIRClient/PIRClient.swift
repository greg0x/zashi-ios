//
//  PIRClient.swift
//  Zashi
//
//  TCA dependency wrapper for PIR operations.
//

import Foundation
import ComposableArchitecture
import ZcashLightClientKit

/// TCA dependency for PIR operations.
public struct PIRClient: Sendable {
    /// Create and connect to PIR server
    public var connect: @Sendable (String) async throws -> Void
    
    /// Precompute cryptographic keys
    public var precomputeKeys: @Sendable () async throws -> Void
    
    /// Check if keys are ready
    public var keysReady: @Sendable () -> Bool
    
    /// Check a single nullifier
    public var checkNullifier: @Sendable (Data) async throws -> SpentInfo?
    
    /// Check multiple nullifiers
    public var checkNullifiers: @Sendable ([Data]) async throws -> [SpentInfo?]
    
    /// Disconnect and cleanup
    public var disconnect: @Sendable () -> Void
}

extension PIRClient: DependencyKey {
    public static let liveValue: PIRClient = {
        // Actor to hold the client state
        actor PIRClientState {
            var client: NullifierPIRClient?
            
            func connect(serverURL: String) async throws {
                client = try await NullifierPIRClient(serverURL: serverURL)
            }
            
            func precomputeKeys() async throws {
                guard let client else {
                    throw PIRError.clientNotInitialized
                }
                try await client.precomputeKeys()
            }
            
            func keysReady() async -> Bool {
                guard let client else { return false }
                return await client.keysReady
            }
            
            func checkNullifier(_ nullifier: Data) async throws -> SpentInfo? {
                guard let client else {
                    throw PIRError.clientNotInitialized
                }
                return try await client.checkNullifier(nullifier)
            }
            
            func checkNullifiers(_ nullifiers: [Data]) async throws -> [SpentInfo?] {
                guard let client else {
                    throw PIRError.clientNotInitialized
                }
                return try await client.checkNullifiers(nullifiers)
            }
            
            func disconnect() {
                client = nil
            }
        }
        
        let state = PIRClientState()
        
        return PIRClient(
            connect: { serverURL in
                print("🔌 PIRClient: Connecting to \(serverURL)")
                try await state.connect(serverURL: serverURL)
                print("✅ PIRClient: Connected successfully")
            },
            precomputeKeys: {
                print("🔑 PIRClient: Precomputing keys...")
                try await state.precomputeKeys()
                print("✅ PIRClient: Keys ready")
            },
            keysReady: {
                // This is synchronous in the interface but we need to bridge
                // For now, return false - the actual check happens async
                false
            },
            checkNullifier: { nullifier in
                print("🔍 PIRClient: Checking nullifier \(nullifier.prefix(4).hexEncodedString())...")
                let result = try await state.checkNullifier(nullifier)
                print("📋 PIRClient: Result = \(result != nil ? "SPENT" : "not spent")")
                return result
            },
            checkNullifiers: { nullifiers in
                try await state.checkNullifiers(nullifiers)
            },
            disconnect: {
                Task { await state.disconnect() }
            }
        )
    }()
    
    public static let testValue = PIRClient(
        connect: { _ in },
        precomputeKeys: { },
        keysReady: { true },
        checkNullifier: { _ in nil },
        checkNullifiers: { nullifiers in Array(repeating: nil, count: nullifiers.count) },
        disconnect: { }
    )
}

extension DependencyValues {
    public var pirClient: PIRClient {
        get { self[PIRClient.self] }
        set { self[PIRClient.self] = newValue }
    }
}

// MARK: - Debug Helpers

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
