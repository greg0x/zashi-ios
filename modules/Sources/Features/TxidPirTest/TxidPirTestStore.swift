//
//  TxidPirTestStore.swift
//  Zashi
//
//  Minimal test UI for txid PIR integration.
//

import Foundation
import ComposableArchitecture
import ZcashLightClientKit

@Reducer
public struct TxidPirTest {
    @ObservableState
    public struct State: Equatable {
        // Server configuration
        public var serverURL: String = "https://jcrziax9ibr1dp-8081.proxy.runpod.net"

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
    }

    @Dependency(\.txidPirClient) var txidPirClient

    public init() {}

    private enum CancelID { case pirOperation }

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .none

            case .onDisappear:
                return .run { _ in
                    await txidPirClient.disconnect()
                }

            // MARK: - Connection

            case .connect:
                state.connectionState = .connecting
                state.errorMessage = nil

                return .run { send in
                    do {
                        // Note: connect() now uses gRPC via lightwalletd (no serverURL needed)
                        try await txidPirClient.connect()
                        if let txParams = await txidPirClient.txLookupParams,
                           let actionParams = await txidPirClient.actionDataParams {
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

                return .run { send in
                    do {
                        try await txidPirClient.precomputeKeys()
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

                return .run { send in
                    do {
                        let result = try await txidPirClient.queryTxLookup(
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

                return .run { send in
                    do {
                        let result = try await txidPirClient.queryActionData(
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

// MARK: - Data Extension

extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Dependency

private enum TxidPirClientKey: DependencyKey {
    static let liveValue: TxidPirClient = TxidPirClient()
}

extension DependencyValues {
    var txidPirClient: TxidPirClient {
        get { self[TxidPirClientKey.self] }
        set { self[TxidPirClientKey.self] = newValue }
    }
}
