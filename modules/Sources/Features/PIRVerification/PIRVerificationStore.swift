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
import DatabaseFiles
import ZcashSDKEnvironment

// MARK: - User Defaults Keys

private enum PIRUserDefaultsKeys {
    static let serverURL = "pir.serverURL"
    static let selectedProtocol = "pir.selectedProtocol"
    static let showTechnicalDetails = "pir.showTechnicalDetails"
}

// MARK: - Test Nullifiers

/// Known test nullifiers for validating PIR correctness.
public enum TestNullifiers {
    /// Synthetic nullifier that doesn't exist (random bytes)
    /// Expected result: NOT FOUND
    public static let syntheticUnspent = Data([
        0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xDE, 0xAD, 0xBE, 0xEF
    ])
    
    /// Real spent nullifier from block 419,202 (Sapling activation + early spend)
    /// This is an actual nullifier from mainnet that was spent.
    /// Expected result: FOUND at block 419,202, tx 0
    public static let knownSpent = Data([
        0x2a, 0x4f, 0x54, 0xd7, 0x6b, 0x11, 0xb6, 0x37,
        0x3c, 0xa5, 0x47, 0x31, 0xac, 0xfe, 0xa1, 0x19,
        0x4d, 0x71, 0xb9, 0x51, 0xa6, 0x8b, 0x31, 0xc8,
        0xf4, 0x19, 0x98, 0xa1, 0x80, 0xcd, 0xc6, 0x01
    ])
    
    public static let knownSpentBlockHeight: UInt32 = 419_202
    public static let knownSpentTxIndex: UInt16 = 0
}

// MARK: - Timing Metrics

/// Timing breakdown for PIR queries (like password demo pattern)
public struct QueryMetrics: Equatable {
    /// Time to generate query (client-side cryptography)
    public let queryGenerationMs: Int
    /// Network round-trip time
    public let networkMs: Int
    /// Server-side processing time (from response stats)
    public let serverProcessingMs: Int
    /// Time to decrypt response (client-side)
    public let decryptionMs: Int
    /// Total end-to-end time
    public let totalMs: Int
    
    /// Data uploaded (query size)
    public let uploadedBytes: Int
    /// Data downloaded (response size)
    public let downloadedBytes: Int
    /// Number of nullifiers checked
    public let nullifiersChecked: Int
    
    /// Estimated time for traditional sync (for comparison)
    public let estimatedSyncTimeMs: Int
    /// Estimated bytes for traditional sync
    public let estimatedSyncBytes: Int
    
    public var speedupFactor: Int {
        guard totalMs > 0 else { return 0 }
        return estimatedSyncTimeMs / totalMs
    }
    
    public var bandwidthSavingsFactor: Int {
        guard downloadedBytes > 0 else { return 0 }
        return estimatedSyncBytes / downloadedBytes
    }
    
    public var perQueryMs: Double {
        guard nullifiersChecked > 0 else { return 0 }
        return Double(totalMs) / Double(nullifiersChecked)
    }
    
    public init(
        queryGenerationMs: Int = 0,
        networkMs: Int = 0,
        serverProcessingMs: Int = 0,
        decryptionMs: Int = 0,
        totalMs: Int = 0,
        uploadedBytes: Int = 0,
        downloadedBytes: Int = 0,
        nullifiersChecked: Int = 0,
        estimatedSyncTimeMs: Int = 720_000, // 12 min default
        estimatedSyncBytes: Int = 450_000_000 // 450 MB default
    ) {
        self.queryGenerationMs = queryGenerationMs
        self.networkMs = networkMs
        self.serverProcessingMs = serverProcessingMs
        self.decryptionMs = decryptionMs
        self.totalMs = totalMs
        self.uploadedBytes = uploadedBytes
        self.downloadedBytes = downloadedBytes
        self.nullifiersChecked = nullifiersChecked
        self.estimatedSyncTimeMs = estimatedSyncTimeMs
        self.estimatedSyncBytes = estimatedSyncBytes
    }
}

/// Server info from /health endpoint
public struct ServerInfo: Equatable {
    public let protocolName: String
    public let numRecords: Int
    public let numNullifiers: Int
    public let keywordMethod: String
    public let lweDim: Int?
    public let ringDim: Int?
    
    public init(
        protocolName: String = "YPIR",
        numRecords: Int = 0,
        numNullifiers: Int = 0,
        keywordMethod: String = "Cuckoo",
        lweDim: Int? = nil,
        ringDim: Int? = nil
    ) {
        self.protocolName = protocolName
        self.numRecords = numRecords
        self.numNullifiers = numNullifiers
        self.keywordMethod = keywordMethod
        self.lweDim = lweDim
        self.ringDim = ringDim
    }
}

/// Info about a spent note discovered via PIR
public struct SpentNoteInfo: Equatable, Identifiable {
    public let id: UUID
    public let blockHeight: UInt32
    public let txIndex: UInt16
    public let discoveredAt: Date
    
    public init(
        id: UUID = UUID(),
        blockHeight: UInt32,
        txIndex: UInt16,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.blockHeight = blockHeight
        self.txIndex = txIndex
        self.discoveredAt = discoveredAt
    }
}

// MARK: - Main Reducer

@Reducer
public struct PIRVerification {
    @ObservableState
    public struct State: Equatable {
        // MARK: Protocol Selection
        
        public enum PIRProtocolSelection: String, CaseIterable, Equatable {
            case inspire = "InsPIRe"
            case ypir = "YPIR"
            
            public var displayName: String { rawValue }
            
            public var description: String {
                switch self {
                case .inspire:
                    return "~416 KB queries, ~3s key prep"
                case .ypir:
                    return "~5.8 MB queries, ~25s key prep"
                }
            }
            
            /// Convert to SDK protocol type
            public var sdkProtocol: ZcashLightClientKit.PIRProtocol {
                switch self {
                case .ypir: return .ypir
                case .inspire: return .inspire
                }
            }
        }
        
        // MARK: Connection State
        
        public enum ConnectionState: Equatable {
            case disconnected
            case connecting
            case connected
            case preparingKeys(progress: Double?)
            case failed(String)
            
            public var isConnected: Bool {
                if case .connected = self { return true }
                return false
            }
        }
        
        // MARK: Test Mode
        
        public enum TestType: String, Equatable {
            case unspent = "Unspent"
            case spent = "Known Spent"
        }
        
        public enum TestResult: Equatable {
            case none
            case running(TestType)
            case passed(TestType, SpentInfo?)
            case failed(TestType, String)
            
            public var isRunning: Bool {
                if case .running = self { return true }
                return false
            }
        }
        
        // MARK: Verification State
        
        public enum VerificationState: Equatable {
            case idle
            case connecting
            case preparingKeys
            case verifying(progress: Int, total: Int)
            case completed(checkedCount: Int, newlySpentCount: Int)
            case failed(String)
        }
        
        // MARK: State Properties
        
        // Configuration (loaded from UserDefaults)
        public var selectedProtocol: PIRProtocolSelection = .inspire
        public var serverURL: String = "http://localhost:8000"
        public var showTechnicalDetails: Bool = false
        
        // UI state
        public var showRetryOption: Bool = false
        
        // Connection
        public var connectionState: ConnectionState = .disconnected
        public var keysReady: Bool = false
        
        // Test mode
        public var testResult: TestResult = .none
        
        // Verification
        public var verificationState: VerificationState = .idle
        public var lastVerified: Date?
        public var spentNotesFound: [SpentNoteInfo] = []
        
        // Metrics
        public var lastQueryMetrics: QueryMetrics?
        
        // Server info
        public var serverInfo: ServerInfo?
        
        // Alert
        @Presents public var alert: AlertState<Action.Alert>?
        
        // MARK: Initializer
        
        public init() {
            // Load persisted settings
            let defaults = UserDefaults.standard
            
            if let savedURL = defaults.string(forKey: PIRUserDefaultsKeys.serverURL), !savedURL.isEmpty {
                self.serverURL = savedURL
            }
            
            if let savedProtocol = defaults.string(forKey: PIRUserDefaultsKeys.selectedProtocol),
               let proto = PIRProtocolSelection(rawValue: savedProtocol) {
                self.selectedProtocol = proto
            }
            
            self.showTechnicalDetails = defaults.bool(forKey: PIRUserDefaultsKeys.showTechnicalDetails)
        }
        
        // MARK: Persistence
        
        public func saveToUserDefaults() {
            let defaults = UserDefaults.standard
            defaults.set(serverURL, forKey: PIRUserDefaultsKeys.serverURL)
            defaults.set(selectedProtocol.rawValue, forKey: PIRUserDefaultsKeys.selectedProtocol)
            defaults.set(showTechnicalDetails, forKey: PIRUserDefaultsKeys.showTechnicalDetails)
        }
        
        // MARK: Computed Properties
        
        public var isOperationInProgress: Bool {
            switch verificationState {
            case .connecting, .preparingKeys, .verifying:
                return true
            default:
                return testResult.isRunning
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
                if checkedCount == 0 {
                    return "No unspent notes to verify.\nYour wallet may be empty or fully synced."
                } else if newlySpentCount == 0 {
                    return "✓ Verified \(checkedCount) notes.\nYour balance is accurate."
                } else {
                    return "Found \(newlySpentCount) newly spent note(s) out of \(checkedCount) checked.\nBalance has been updated."
                }
            case .failed(let error):
                return "Verification failed: \(error)"
            }
        }
        
        public var connectionStatusText: String {
            switch connectionState {
            case .disconnected:
                return "Disconnected"
            case .connecting:
                return "Connecting..."
            case .connected:
                return "Connected"
            case .preparingKeys:
                return "Preparing Keys..."
            case .failed(let msg):
                return "Failed: \(msg)"
            }
        }
        
        public var connectionStatusColor: String {
            switch connectionState {
            case .disconnected, .failed:
                return "red"
            case .connecting, .preparingKeys:
                return "orange"
            case .connected:
                return "green"
            }
        }
    }
    
    // MARK: - Actions
    
    public enum Action: Equatable {
        case alert(PresentationAction<Alert>)
        case cancelRequested
        case cancelVerification
        case onAppear
        case onDisappear
        
        // Protocol & Configuration
        case selectProtocol(State.PIRProtocolSelection)
        case updateServerURL(String)
        case toggleTechnicalDetails
        
        // Connection
        case connect
        case connectionSucceeded(ServerInfo)
        case connectionFailed(String)
        case keysReady
        
        // Test mode
        case runTest(State.TestType)
        case testCompleted(State.TestType, SpentInfo?)
        case testFailed(State.TestType, String)
        
        // Verification
        case startVerification
        case verificationCompleted(checkedCount: Int, newlySpentCount: Int, spentNotes: [SpentNoteInfo])
        case verificationFailed(String)
        case verificationProgress(Int, Int)
        case verificationStateChanged(State.VerificationState)
        
        // Metrics
        case updateMetrics(QueryMetrics)
        
        // Retry
        case retryLastOperation
        
        @CasePathable
        public enum Alert: Equatable {
            case cancel
        }
    }
    
    private enum CancelID { case verification, test }
    
    @Dependency(\.pirClient) var pirClient
    @Dependency(\.date) var date
    @Dependency(\.databaseFiles) var databaseFiles
    @Dependency(\.zcashSDKEnvironment) var zcashSDKEnvironment
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Auto-connect if we have a server URL
                if state.connectionState == .disconnected && !state.serverURL.isEmpty {
                    return .send(.connect)
                }
                return .none
                
            case .onDisappear:
                pirClient.disconnect()
                return .merge(
                    .cancel(id: CancelID.verification),
                    .cancel(id: CancelID.test)
                )
                
            // MARK: Protocol & Configuration
                
            case .selectProtocol(let proto):
                state.selectedProtocol = proto
                state.saveToUserDefaults()
                // Disconnect and reconnect when protocol changes
                if state.connectionState.isConnected {
                    pirClient.disconnect()
                    state.connectionState = .disconnected
                    state.keysReady = false
                }
                return .none
                
            case .updateServerURL(let url):
                state.serverURL = url
                state.saveToUserDefaults()
                return .none
                
            case .toggleTechnicalDetails:
                state.showTechnicalDetails.toggle()
                state.saveToUserDefaults()
                return .none
                
            // MARK: Connection
                
            case .connect:
                state.connectionState = .connecting
                let serverURL = state.serverURL
                let pirProtocol = state.selectedProtocol.sdkProtocol
                let protocolName = state.selectedProtocol.displayName
                
                return .run { send in
                    do {
                        try await pirClient.connect(serverURL, pirProtocol)
                        
                        // Build server info (would be fetched from /health endpoint)
                        let serverInfo = ServerInfo(
                            protocolName: protocolName,
                            numRecords: 0,
                            numNullifiers: 51_700_000,
                            keywordMethod: "Cuckoo",
                            lweDim: 1024,
                            ringDim: 1024
                        )
                        
                        await send(.connectionSucceeded(serverInfo))
                    } catch {
                        await send(.connectionFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.verification)
                
            case .connectionSucceeded(let info):
                state.connectionState = .connected
                state.serverInfo = info
                return .none
                
            case .connectionFailed(let error):
                state.connectionState = .failed(error)
                return .none
                
            case .keysReady:
                state.keysReady = true
                state.connectionState = .connected
                return .none
                
            // MARK: Test Mode
                
            case .runTest(let testType):
                guard state.connectionState.isConnected || state.connectionState == .disconnected else {
                    return .none
                }
                
                state.testResult = .running(testType)
                let serverURL = state.serverURL
                let pirProtocol = state.selectedProtocol.sdkProtocol
                let nullifier = testType == .spent ? TestNullifiers.knownSpent : TestNullifiers.syntheticUnspent
                
                return .run { send in
                    do {
                        // Connect if needed
                        try await pirClient.connect(serverURL, pirProtocol)
                        
                        // Precompute keys if needed
                        if !pirClient.keysReady() {
                            try await pirClient.precomputeKeys()
                        }
                        
                        // Check the nullifier with timing
                        let result = try await pirClient.checkNullifierWithTiming(nullifier)
                        
                        // Update metrics
                        let metrics = QueryMetrics(
                            queryGenerationMs: result.timing.queryGenerationMs,
                            networkMs: result.timing.networkMs,
                            serverProcessingMs: result.timing.serverProcessingMs,
                            decryptionMs: result.timing.decryptionMs,
                            totalMs: result.timing.totalMs,
                            uploadedBytes: result.timing.uploadBytes,
                            downloadedBytes: result.timing.downloadBytes,
                            nullifiersChecked: 1
                        )
                        await send(.updateMetrics(metrics))
                        await send(.testCompleted(testType, result.spentInfo))
                        
                    } catch {
                        await send(.testFailed(testType, error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.test)
                
            case .testCompleted(let testType, let spentInfo):
                // Validate the result
                switch testType {
                case .unspent:
                    if spentInfo == nil {
                        state.testResult = .passed(testType, nil)
                    } else {
                        state.testResult = .failed(testType, "Expected unspent, but found spent!")
                    }
                case .spent:
                    if let info = spentInfo {
                        // Verify block height matches expected
                        if info.blockHeight == TestNullifiers.knownSpentBlockHeight {
                            state.testResult = .passed(testType, info)
                        } else {
                            state.testResult = .failed(testType, "Wrong block height: \(info.blockHeight) vs expected \(TestNullifiers.knownSpentBlockHeight)")
                        }
                    } else {
                        state.testResult = .failed(testType, "Expected spent, but not found!")
                    }
                }
                state.keysReady = true
                state.connectionState = .connected
                return .none
                
            case .testFailed(let testType, let error):
                state.testResult = .failed(testType, error)
                return .none
                
            // MARK: Verification
                
            case .startVerification:
                state.verificationState = .connecting
                let serverURL = state.serverURL
                let pirProtocol = state.selectedProtocol.sdkProtocol
                let network = zcashSDKEnvironment.network
                let dataDbURL = databaseFiles.dataDbURLFor(network)
                
                return .run { send in
                    do {
                        // Step 1: Connect to PIR server
                        try await pirClient.connect(serverURL, pirProtocol)
                        
                        // Step 2: Precompute keys
                        await send(.verificationStateChanged(.preparingKeys))
                        try await pirClient.precomputeKeys()
                        
                        // Step 3: Get real wallet nullifiers
                        let walletNullifiers = try await pirClient.getUnspentNullifiers(
                            dataDbURL,
                            network.networkType
                        )
                        let totalNotes = walletNullifiers.count
                        
                        // If no nullifiers, we're done
                        guard totalNotes > 0 else {
                            await send(.verificationCompleted(
                                checkedCount: 0,
                                newlySpentCount: 0,
                                spentNotes: []
                            ))
                            return
                        }
                        
                        var spentCount = 0
                        var spentNotes: [SpentNoteInfo] = []
                        
                        // Accumulated timing
                        var totalQueryGenMs = 0
                        var totalNetworkMs = 0
                        var totalServerMs = 0
                        var totalDecryptMs = 0
                        var totalUploadBytes = 0
                        var totalDownloadBytes = 0
                        
                        let verificationStart = DispatchTime.now()
                        
                        // Step 4: Check each nullifier with timing
                        for (index, nullifier) in walletNullifiers.enumerated() {
                            await send(.verificationProgress(index + 1, totalNotes))
                            
                            let result = try await pirClient.checkNullifierWithTiming(nullifier)
                            
                            // Accumulate timing
                            totalQueryGenMs += result.timing.queryGenerationMs
                            totalNetworkMs += result.timing.networkMs
                            totalServerMs += result.timing.serverProcessingMs
                            totalDecryptMs += result.timing.decryptionMs
                            totalUploadBytes += result.timing.uploadBytes
                            totalDownloadBytes += result.timing.downloadBytes
                            
                            if let spentInfo = result.spentInfo {
                                spentCount += 1
                                spentNotes.append(SpentNoteInfo(
                                    blockHeight: UInt32(spentInfo.blockHeight),
                                    txIndex: UInt16(spentInfo.txIndex)
                                ))
                            }
                        }
                        
                        let verificationEnd = DispatchTime.now()
                        let totalMs = Int((verificationEnd.uptimeNanoseconds - verificationStart.uptimeNanoseconds) / 1_000_000)
                        
                        // Update metrics
                        let metrics = QueryMetrics(
                            queryGenerationMs: totalQueryGenMs,
                            networkMs: totalNetworkMs,
                            serverProcessingMs: totalServerMs,
                            decryptionMs: totalDecryptMs,
                            totalMs: totalMs,
                            uploadedBytes: totalUploadBytes,
                            downloadedBytes: totalDownloadBytes,
                            nullifiersChecked: totalNotes
                        )
                        await send(.updateMetrics(metrics))
                        
                        await send(.verificationCompleted(
                            checkedCount: totalNotes,
                            newlySpentCount: spentCount,
                            spentNotes: spentNotes
                        ))
                        
                    } catch {
                        await send(.verificationFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.verification)
                
            case .cancelRequested:
                state.alert = AlertState {
                    TextState("Cancel Operation?")
                } actions: {
                    ButtonState(role: .destructive, action: .cancel) {
                        TextState("Cancel")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Continue")
                    }
                } message: {
                    TextState("The operation is in progress. Are you sure you want to cancel?")
                }
                return .none
                
            case .alert(.presented(.cancel)):
                state.verificationState = .idle
                state.testResult = .none
                pirClient.disconnect()
                return .merge(
                    .cancel(id: CancelID.verification),
                    .cancel(id: CancelID.test)
                )
                
            case .alert(.dismiss):
                return .none
                
            case .cancelVerification:
                state.verificationState = .idle
                pirClient.disconnect()
                return .cancel(id: CancelID.verification)
                
            case .verificationStateChanged(let newState):
                state.verificationState = newState
                return .none
                
            case .verificationProgress(let current, let total):
                state.verificationState = .verifying(progress: current, total: total)
                return .none
                
            case .verificationCompleted(let checkedCount, let newlySpentCount, let spentNotes):
                state.verificationState = .completed(checkedCount: checkedCount, newlySpentCount: newlySpentCount)
                state.spentNotesFound = spentNotes
                state.lastVerified = date.now
                state.keysReady = true
                state.connectionState = .connected
                return .none
                
            case .verificationFailed(let error):
                state.verificationState = .failed(error)
                return .none
                
            // MARK: Metrics
                
            case .updateMetrics(let metrics):
                state.lastQueryMetrics = metrics
                return .none
                
            // MARK: Retry
                
            case .retryLastOperation:
                // Reset failed state and retry
                switch state.verificationState {
                case .failed:
                    state.verificationState = .idle
                    return .send(.startVerification)
                default:
                    break
                }
                
                if case .failed = state.testResult {
                    state.testResult = .none
                    // Can't easily know which test failed, so just reset
                }
                
                if case .failed = state.connectionState {
                    state.connectionState = .disconnected
                    return .send(.connect)
                }
                
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Test Data Generation

/// Generate synthetic test nullifiers for testing PIR infrastructure.
/// These are NOT real nullifiers - used only for test mode validation.
/// Real wallet verification uses WalletNullifiers.getUnspentNullifiers().
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
