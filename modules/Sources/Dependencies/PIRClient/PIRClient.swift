//
//  PIRClient.swift
//  Zashi
//
//  TCA dependency wrapper for PIR operations.
//

import Foundation
import ComposableArchitecture
import ZcashLightClientKit

// MARK: - Timing Types

/// Timing breakdown for a single PIR query
public struct PIRQueryTiming: Equatable, Sendable {
    /// Time to generate query (client-side cryptography)
    public let queryGenerationMs: Int
    /// Network round-trip time
    public let networkMs: Int
    /// Server-side processing time
    public let serverProcessingMs: Int
    /// Time to decrypt response
    public let decryptionMs: Int
    /// Total end-to-end time
    public let totalMs: Int
    /// Upload size in bytes
    public let uploadBytes: Int
    /// Download size in bytes
    public let downloadBytes: Int
    
    public init(
        queryGenerationMs: Int = 0,
        networkMs: Int = 0,
        serverProcessingMs: Int = 0,
        decryptionMs: Int = 0,
        totalMs: Int = 0,
        uploadBytes: Int = 0,
        downloadBytes: Int = 0
    ) {
        self.queryGenerationMs = queryGenerationMs
        self.networkMs = networkMs
        self.serverProcessingMs = serverProcessingMs
        self.decryptionMs = decryptionMs
        self.totalMs = totalMs
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
    }
}

/// Result of a nullifier check including timing info
public struct PIRCheckResult: Equatable, Sendable {
    /// Spent info if the nullifier was found, nil otherwise
    public let spentInfo: SpentInfo?
    /// Timing breakdown for this query
    public let timing: PIRQueryTiming
    
    public init(spentInfo: SpentInfo?, timing: PIRQueryTiming) {
        self.spentInfo = spentInfo
        self.timing = timing
    }
}

/// Server health/params information
public struct PIRServerInfo: Equatable, Sendable {
    public let protocolName: String
    public let numNullifiers: Int
    public let numBuckets: Int
    public let pirCutoffHeight: BlockHeight
    public let pirReady: Bool
    
    public init(
        protocolName: String = "InsPIRe",
        numNullifiers: Int = 0,
        numBuckets: Int = 0,
        pirCutoffHeight: BlockHeight = 0,
        pirReady: Bool = false
    ) {
        self.protocolName = protocolName
        self.numNullifiers = numNullifiers
        self.numBuckets = numBuckets
        self.pirCutoffHeight = pirCutoffHeight
        self.pirReady = pirReady
    }
}

// MARK: - PIR Client Dependency

/// TCA dependency for PIR operations.
///
/// This client uses the synchronizer's lightwalletd connection for PIR queries,
/// eliminating the need for a separate PIR server URL.
public struct PIRClient: Sendable {
    /// Initialize PIR client using the synchronizer's connection.
    /// This fetches PIR params and precomputes cryptographic keys.
    public var initialize: @Sendable () async throws -> Void
    
    /// Fetch server info (PIR params)
    public var fetchServerInfo: @Sendable () async throws -> PIRServerInfo
    
    /// Check if keys are ready
    public var keysReady: @Sendable () -> Bool
    
    /// Check if PIR should be used for the given sync height
    public var shouldUsePIR: @Sendable (BlockHeight) -> Bool
    
    /// Check a single nullifier
    public var checkNullifier: @Sendable (Data) async throws -> SpentInfo?
    
    /// Check multiple nullifiers
    public var checkNullifiers: @Sendable ([Data]) async throws -> [SpentInfo?]
    
    /// Get unspent nullifiers from the wallet database
    public var getUnspentNullifiers: @Sendable (URL, NetworkType) async throws -> [Data]
    
    /// Disconnect and cleanup
    public var disconnect: @Sendable () -> Void
}

extension PIRClient: DependencyKey {
    public static let liveValue: PIRClient = {
        // Actor to hold the client state
        actor PIRClientState {
            var client: NullifierPIRClient?
            
            @Dependency(\.sdkSynchronizer) var sdkSynchronizer
            
            func initialize() async throws {
                // Create PIR client from synchronizer
                client = sdkSynchronizer.createPIRClient()
                
                // Initialize (fetches params and precomputes keys)
                try await client?.initialize()
            }
            
            func fetchServerInfo() async throws -> PIRServerInfo {
                let params = try await sdkSynchronizer.getPirParams()
                
                return PIRServerInfo(
                    protocolName: "InsPIRe",
                    numNullifiers: Int(params.numNullifiers),
                    numBuckets: Int(params.cuckooParams.numBuckets),
                    pirCutoffHeight: BlockHeight(params.pirCutoffHeight),
                    pirReady: params.pirReady
                )
            }
            
            func keysReady() async -> Bool {
                guard let client else { return false }
                return await client.keysReady
            }
            
            func shouldUsePIR(lastSyncHeight: BlockHeight) async -> Bool {
                guard let client else { return false }
                return await client.shouldUsePIR(lastSyncHeight: lastSyncHeight)
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
            initialize: {
                print("🔌 PIRClient: Initializing using lightwalletd connection...")
                try await state.initialize()
                print("✅ PIRClient: Initialized and keys ready")
            },
            fetchServerInfo: {
                try await state.fetchServerInfo()
            },
            keysReady: {
                // This is synchronous in the interface but we need to bridge
                // For now, return false - the actual check happens async
                false
            },
            shouldUsePIR: { lastSyncHeight in
                // Sync check - use Task for async bridging
                false // Caller should use async version via NullifierPIRClient directly
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
            getUnspentNullifiers: { dataDbURL, networkType in
                print("📖 PIRClient: Getting unspent nullifiers from wallet...")
                let nullifiers = try WalletNullifiers.getUnspentNullifiers(
                    dataDbURL: dataDbURL,
                    networkType: networkType
                )
                print("📖 PIRClient: Found \(nullifiers.count) unspent nullifiers")
                return nullifiers
            },
            disconnect: {
                Task { await state.disconnect() }
            }
        )
    }()
    
    public static let testValue = PIRClient(
        initialize: { },
        fetchServerInfo: { 
            PIRServerInfo(
                protocolName: "InsPIRe",
                numNullifiers: 51_700_000,
                numBuckets: 6_462_500,
                pirCutoffHeight: 2_800_000,
                pirReady: true
            )
        },
        keysReady: { true },
        shouldUsePIR: { _ in true },
        checkNullifier: { _ in nil },
        checkNullifiers: { nullifiers in Array(repeating: nil, count: nullifiers.count) },
        getUnspentNullifiers: { _, _ in
            // Return test nullifiers for testing
            [
                Data(repeating: 0xDE, count: 32),
                Data(repeating: 0xAD, count: 32),
                Data(repeating: 0xBE, count: 32)
            ]
        },
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
