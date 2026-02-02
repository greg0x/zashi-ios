//
//  TxidPirTestStore.swift
//  Zashi
//
//  Minimal test UI for txid PIR integration.
//

import Foundation
import Combine
import ComposableArchitecture
import ZcashLightClientKit
import SDKSynchronizer

@Reducer
public struct TxidPirTest {
    @ObservableState
    public struct State: Equatable {
        // PIR Config (hardcoded for testing - matches SDKSynchronizerLive)
        public var isPirEnhanceEnabled: Bool = true
        public var debugDisableMempoolSync: Bool = true

        // Connection state
        public var connectionState: ConnectionState = .disconnected

        // Server params (when connected)
        public var txLookupParams: TxidLookupParamsInfo?
        public var actionDataParams: TxidActionDataParamsInfo?

        // Query inputs
        public var blockHeightInput: String = "2800000"
        public var txIndexInput: String = "5"
        public var startIndexInput: String = ""
        public var actionCountInput: String = ""

        // Results
        public var txLookupResult: TxLookupResultDisplay?
        public var actionDataResult: [ActionDataDisplay] = []

        // Timing
        public var lastQueryTiming: QueryTimingDisplay?

        // Error
        public var errorMessage: String?

        // Live Enhancement Feed
        public var enhancementEvents: [EnhancementEventDisplay] = []

        // Stats
        public var totalEnhancements: Int = 0
        public var pirSuccessCount: Int = 0
        public var fallbackCount: Int = 0
        public var getTransactionCount: Int = 0

        public var successRate: Double {
            guard totalEnhancements > 0 else { return 0 }
            return Double(pirSuccessCount) / Double(totalEnhancements) * 100
        }

        public enum ConnectionState: Equatable {
            case disconnected
            case connecting
            case paramsLoaded
            case precomputing
            case ready
            case error(String)
        }

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case onDisappear

        // Connection
        case connect
        case connectionSucceeded(TxidLookupParamsInfo, TxidActionDataParamsInfo)
        case connectionFailed(String)
        case precomputeKeys
        case keysReady
        case keysFailed(String)

        // Queries
        case queryTxLookup
        case txLookupCompleted(TxLookupResultDisplay?, QueryTimingDisplay)
        case txLookupFailed(String)

        case queryActionData
        case actionDataCompleted([ActionDataDisplay], QueryTimingDisplay)
        case actionDataFailed(String)

        // Fill from result
        case fillActionDataFromResult

        // Enhancement events (from SDK eventStream)
        case startEventStream
        case pirEnhancementReceived(EnhancementEventDisplay)
        case clearStats
    }

    @Dependency(\.sdkSynchronizer) var sdkSynchronizer

    public init() {}

    private enum CancelID { case pirOperation }

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.startEventStream)

            case .onDisappear:
                return .run { [sdkSynchronizer] _ in
                    if let client = sharedTxidPirClientHolder.getOrCreate(from: sdkSynchronizer) {
                        await client.disconnect()
                    }
                }

            // MARK: - Connection

            case .connect:
                state.connectionState = .connecting
                state.errorMessage = nil

                return .run { [sdkSynchronizer] send in
                    do {
                        guard let client = sharedTxidPirClientHolder.getOrCreate(from: sdkSynchronizer) else {
                            await send(.connectionFailed("Failed to create PIR client - synchronizer not ready"))
                            return
                        }
                        // connect() uses gRPC via lightwalletd
                        try await client.connect()
                        if let txParams = await client.txLookupParams,
                           let actionParams = await client.actionDataParams {
                            await send(.connectionSucceeded(txParams, actionParams))
                        } else {
                            await send(.connectionFailed("Failed to get params"))
                        }
                    } catch {
                        await send(.connectionFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.pirOperation)

            case .connectionSucceeded(let txParams, let actionParams):
                state.connectionState = .paramsLoaded
                state.txLookupParams = txParams
                state.actionDataParams = actionParams
                return .none

            case .connectionFailed(let error):
                state.connectionState = .error(error)
                state.errorMessage = error
                return .none

            case .precomputeKeys:
                state.connectionState = .precomputing
                state.errorMessage = nil

                return .run { [sdkSynchronizer] send in
                    do {
                        guard let client = sharedTxidPirClientHolder.getOrCreate(from: sdkSynchronizer) else {
                            await send(.keysFailed("PIR client not available"))
                            return
                        }
                        try await client.precomputeKeys()
                        await send(.keysReady)
                    } catch {
                        await send(.keysFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.pirOperation)

            case .keysReady:
                state.connectionState = .ready
                return .none

            case .keysFailed(let error):
                state.connectionState = .error(error)
                state.errorMessage = error
                return .none

            // MARK: - TX Lookup Query

            case .queryTxLookup:
                guard state.connectionState == .ready else {
                    state.errorMessage = "Not ready - connect and precompute keys first"
                    return .none
                }

                guard let blockHeight = UInt32(state.blockHeightInput),
                      let txIndex = UInt16(state.txIndexInput) else {
                    state.errorMessage = "Invalid block height or tx index"
                    return .none
                }

                state.errorMessage = nil
                state.txLookupResult = nil

                return .run { [sdkSynchronizer] send in
                    do {
                        guard let client = sharedTxidPirClientHolder.getOrCreate(from: sdkSynchronizer) else {
                            await send(.txLookupFailed("PIR client not available"))
                            return
                        }
                        let result = try await client.queryTxLookup(
                            blockHeight: blockHeight,
                            txIndex: txIndex
                        )

                        let display = result.result.map {
                            TxLookupResultDisplay(
                                startIndex: $0.startIndex,
                                actionCount: $0.actionCount
                            )
                        }

                        let timing = QueryTimingDisplay(
                            queryGenMs: result.timing.queryGenMs,
                            networkMs: result.timing.networkMs,
                            serverMs: result.timing.serverMs,
                            decryptMs: result.timing.decryptMs,
                            uploadBytes: result.bandwidth.uploadBytes,
                            downloadBytes: result.bandwidth.downloadBytes
                        )

                        await send(.txLookupCompleted(display, timing))
                    } catch {
                        await send(.txLookupFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.pirOperation)

            case .txLookupCompleted(let result, let timing):
                state.txLookupResult = result
                state.lastQueryTiming = timing
                return .none

            case .txLookupFailed(let error):
                state.errorMessage = error
                return .none

            // MARK: - Action Data Query

            case .queryActionData:
                guard state.connectionState == .ready else {
                    state.errorMessage = "Not ready - connect and precompute keys first"
                    return .none
                }

                guard let startIndex = UInt64(state.startIndexInput),
                      let actionCount = UInt16(state.actionCountInput) else {
                    state.errorMessage = "Invalid start index or action count"
                    return .none
                }

                state.errorMessage = nil
                state.actionDataResult = []

                return .run { [sdkSynchronizer] send in
                    do {
                        guard let client = sharedTxidPirClientHolder.getOrCreate(from: sdkSynchronizer) else {
                            await send(.actionDataFailed("PIR client not available"))
                            return
                        }
                        let result = try await client.queryActionData(
                            startIndex: startIndex,
                            actionCount: actionCount
                        )

                        let actions = result.actions.map {
                            ActionDataDisplay(
                                encCiphertextTailHex: $0.encCiphertextTail.prefix(16).hexEncodedString(),
                                outCiphertextHex: $0.outCiphertext.prefix(16).hexEncodedString(),
                                cvHex: $0.cv.hexEncodedString()
                            )
                        }

                        let timing = QueryTimingDisplay(
                            queryGenMs: result.timing.queryGenMs,
                            networkMs: result.timing.networkMs,
                            serverMs: result.timing.serverMs,
                            decryptMs: result.timing.decryptMs,
                            uploadBytes: result.bandwidth.uploadBytes,
                            downloadBytes: result.bandwidth.downloadBytes
                        )

                        await send(.actionDataCompleted(actions, timing))
                    } catch {
                        await send(.actionDataFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.pirOperation)

            case .actionDataCompleted(let actions, let timing):
                state.actionDataResult = actions
                state.lastQueryTiming = timing
                return .none

            case .actionDataFailed(let error):
                state.errorMessage = error
                return .none

            case .fillActionDataFromResult:
                if let result = state.txLookupResult {
                    state.startIndexInput = String(result.startIndex)
                    state.actionCountInput = String(result.actionCount)
                }
                return .none

            // MARK: - Enhancement Events

            case .startEventStream:
                return .run { [sdkSynchronizer] send in
                    for await event in sdkSynchronizer.eventStream().values {
                        if case .pirEnhancement(let pirEvent) = event {
                            let display = EnhancementEventDisplay(
                                txId: pirEvent.txId.prefix(8).map { String(format: "%02x", $0) }.joined() + "...",
                                blockHeight: pirEvent.blockHeight,
                                method: pirEvent.method,
                                success: pirEvent.success,
                                actionCount: pirEvent.actionCount,
                                timingMs: pirEvent.timingMs,
                                timestamp: Date()
                            )
                            await send(.pirEnhancementReceived(display))
                        }
                    }
                }
                .cancellable(id: CancelID.pirOperation, cancelInFlight: false)

            case .pirEnhancementReceived(let event):
                // Add to the front of the list, keep max 20 events
                state.enhancementEvents.insert(event, at: 0)
                if state.enhancementEvents.count > 20 {
                    state.enhancementEvents.removeLast()
                }

                // Update stats
                state.totalEnhancements += 1
                switch event.method {
                case .pir:
                    state.pirSuccessCount += 1
                case .fallback:
                    state.fallbackCount += 1
                case .getTransaction:
                    state.getTransactionCount += 1
                }
                return .none

            case .clearStats:
                state.enhancementEvents = []
                state.totalEnhancements = 0
                state.pirSuccessCount = 0
                state.fallbackCount = 0
                state.getTransactionCount = 0
                return .none
            }
        }
    }
}

// MARK: - Display Types

public struct TxLookupResultDisplay: Equatable {
    public let startIndex: UInt64
    public let actionCount: UInt16
}

public struct ActionDataDisplay: Equatable, Identifiable {
    public let id = UUID()
    public let encCiphertextTailHex: String
    public let outCiphertextHex: String
    public let cvHex: String
}

public struct QueryTimingDisplay: Equatable {
    public let queryGenMs: Double
    public let networkMs: Double
    public let serverMs: Double
    public let decryptMs: Double
    public let uploadBytes: Int
    public let downloadBytes: Int

    public var totalMs: Double {
        queryGenMs + networkMs + serverMs + decryptMs
    }
}

public struct EnhancementEventDisplay: Equatable, Identifiable {
    public let id = UUID()
    public let txId: String  // Truncated hex string
    public let blockHeight: UInt32
    public let method: PirEnhancementMethod
    public let success: Bool
    public let actionCount: Int
    public let timingMs: Double?
    public let timestamp: Date

    public var methodSymbol: String {
        switch method {
        case .pir: return "✓ PIR"
        case .fallback: return "⚠️ Fallback"
        case .getTransaction: return "✗ GetTx"
        }
    }
}

// MARK: - Data Extension

extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Dependency

/// Shared TxidPirClient instance - created lazily from SDKSynchronizer
private final class TxidPirClientHolder: @unchecked Sendable {
    private var _client: TxidPirClient?
    private let lock = NSLock()

    func getOrCreate(from sdkSynchronizer: SDKSynchronizerClient) -> TxidPirClient? {
        lock.lock()
        defer { lock.unlock() }
        if _client == nil {
            _client = sdkSynchronizer.createTxidPirClient()
        }
        return _client
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        _client = nil
    }
}

private let sharedTxidPirClientHolder = TxidPirClientHolder()
