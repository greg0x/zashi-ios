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
    public let lweDim: Int?
    public let ringDim: Int?
    public let recordSize: Int?
    
    public init(
        protocolName: String = "YPIR",
        numNullifiers: Int = 0,
        numBuckets: Int = 0,
        lweDim: Int? = nil,
        ringDim: Int? = nil,
        recordSize: Int? = nil
    ) {
        self.protocolName = protocolName
        self.numNullifiers = numNullifiers
        self.numBuckets = numBuckets
        self.lweDim = lweDim
        self.ringDim = ringDim
        self.recordSize = recordSize
    }
}

// MARK: - PIR Client Dependency

/// TCA dependency for PIR operations.
public struct PIRClient: Sendable {
    /// Create and connect to PIR server
    public var connect: @Sendable (String) async throws -> Void
    
    /// Fetch server info (health check)
    public var fetchServerInfo: @Sendable () async throws -> PIRServerInfo
    
    /// Precompute cryptographic keys
    public var precomputeKeys: @Sendable () async throws -> Void
    
    /// Check if keys are ready
    public var keysReady: @Sendable () -> Bool
    
    /// Check a single nullifier (returns timing info)
    public var checkNullifier: @Sendable (Data) async throws -> SpentInfo?
    
    /// Check a single nullifier with timing breakdown
    public var checkNullifierWithTiming: @Sendable (Data) async throws -> PIRCheckResult
    
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
                client = try NullifierPIRClient(serverURL: serverURL)
            }
            
            func fetchServerInfo() async throws -> PIRServerInfo {
                // For now, return placeholder - would fetch from /health endpoint
                return PIRServerInfo(
                    protocolName: "YPIR",
                    numNullifiers: 51_700_000,
                    numBuckets: 6_462_500,
                    lweDim: 1024,
                    ringDim: 1024,
                    recordSize: 112
                )
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
            
            func checkNullifierWithTiming(_ nullifier: Data) async throws -> PIRCheckResult {
                guard let client else {
                    throw PIRError.clientNotInitialized
                }
                
                let totalStart = DispatchTime.now()
                
                // Query generation timing
                let queryGenStart = DispatchTime.now()
                // Note: In a real implementation, we'd instrument the query generation
                // For now, we estimate based on typical values
                let queryGenMs = 100 // Placeholder
                
                // Network + server timing
                let networkStart = DispatchTime.now()
                let result = try await client.checkNullifier(nullifier)
                let networkEnd = DispatchTime.now()
                
                // Calculate network time (includes server processing)
                let networkNanos = networkEnd.uptimeNanoseconds - networkStart.uptimeNanoseconds
                let networkMs = Int(networkNanos / 1_000_000)
                
                // Server processing (would come from response headers in a real impl)
                let serverMs = 50 // Placeholder
                
                // Decryption timing
                let decryptMs = 20 // Placeholder
                
                let totalEnd = DispatchTime.now()
                let totalMs = Int((totalEnd.uptimeNanoseconds - totalStart.uptimeNanoseconds) / 1_000_000)
                
                return PIRCheckResult(
                    spentInfo: result,
                    timing: PIRQueryTiming(
                        queryGenerationMs: queryGenMs,
                        networkMs: networkMs - serverMs - decryptMs,
                        serverProcessingMs: serverMs,
                        decryptionMs: decryptMs,
                        totalMs: totalMs,
                        uploadBytes: 1_500_000, // ~1.5MB query (estimated)
                        downloadBytes: 800 // ~800 bytes response (estimated)
                    )
                )
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
            fetchServerInfo: {
                try await state.fetchServerInfo()
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
            checkNullifierWithTiming: { nullifier in
                print("🔍 PIRClient: Checking nullifier \(nullifier.prefix(4).hexEncodedString()) with timing...")
                let result = try await state.checkNullifierWithTiming(nullifier)
                print("📋 PIRClient: Result = \(result.spentInfo != nil ? "SPENT" : "not spent"), total: \(result.timing.totalMs)ms")
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
        fetchServerInfo: { 
            PIRServerInfo(
                protocolName: "YPIR",
                numNullifiers: 51_700_000,
                numBuckets: 6_462_500,
                lweDim: 1024,
                ringDim: 1024
            )
        },
        precomputeKeys: { },
        keysReady: { true },
        checkNullifier: { _ in nil },
        checkNullifierWithTiming: { _ in 
            PIRCheckResult(
                spentInfo: nil,
                timing: PIRQueryTiming(
                    queryGenerationMs: 100,
                    networkMs: 80,
                    serverProcessingMs: 50,
                    decryptionMs: 20,
                    totalMs: 250
                )
            )
        },
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
