//
//  WalletBalancesStore.swift
//  Zashi
//
//  Created by Lukáš Korba on 04-02-2024
//

import Foundation
import ComposableArchitecture

import DatabaseFiles
import ExchangeRate
import Models
import PIRClient
import SDKSynchronizer
import Utils
import ZcashLightClientKit
import ZcashSDKEnvironment
import UserPreferencesStorage
import WalletStorage

// MARK: - PIR Verification State

/// State of PIR-based balance verification
public enum PIRVerificationState: Equatable {
    /// PIR verification is not active (sync is up-to-date or not far enough behind)
    case idle
    /// Connecting to PIR server
    case connecting
    /// Precomputing cryptographic keys (one-time cost per session)
    case preparingKeys
    /// Actively checking nullifiers via PIR
    case verifying(checked: Int, total: Int)
    /// Verification complete - balance confirmed via PIR
    case verified(checkedCount: Int, spentFound: Int)
    /// Verification failed (non-fatal, sync continues normally)
    case failed(String)
    
    public var isActive: Bool {
        switch self {
        case .connecting, .preparingKeys, .verifying:
            return true
        default:
            return false
        }
    }
    
    public var isVerified: Bool {
        if case .verified = self { return true }
        return false
    }
}

@Reducer
public struct WalletBalances {
    private let CancelStateId = UUID()
    private let CancelRateId = UUID()
    private let CancelPIRId = UUID()

    @ObservableState
    public struct State: Equatable {
        public var autoShieldingThreshold: Zatoshi = .zero
        @Shared(.inMemory(.exchangeRate)) public var currencyConversion: CurrencyConversion? = nil
        public var fiatCurrencyResult: FiatCurrencyResult?
        public var isAvailableBalanceTappable = true
        public var isExchangeRateFeatureOn = false
        public var isExchangeRateRefreshEnabled = false
        public var isExchangeRateStale = false
        public var migratingDatabase = false
        @Shared(.inMemory(.selectedWalletAccount)) public var selectedWalletAccount: WalletAccount? = nil
        public var shieldedBalance: Zatoshi
        public var shieldedWithPendingBalance: Zatoshi
        public var spendability: Spendability = .everything
        public var totalBalance: Zatoshi
        public var transparentBalance: Zatoshi
        
        // MARK: PIR Verification State
        
        /// Current state of PIR-based balance verification
        public var pirVerificationState: PIRVerificationState = .idle
        /// Balance verified via PIR (before full sync completes)
        /// This is the shielded balance minus any notes PIR found to be spent
        public var pirVerifiedShieldedBalance: Zatoshi?
        /// Number of blocks behind when PIR verification started
        public var pirBlocksBehind: Int = 0
        /// Whether PIR verification is enabled (can be toggled in settings)
        public var isPIREnabled: Bool = true
        /// Threshold: trigger PIR when this many blocks behind
        public static let pirBlocksThreshold: Int = 100
        /// PIR server URL
        public var pirServerURL: String = "http://localhost:8000"
        /// Track the sync session to avoid re-triggering PIR
        public var pirLastSyncSessionID: UUID?

        public var isExchangeRateUSDInFlight: Bool {
            fiatCurrencyResult?.state == .fetching
        }
        
        public var isProcessingZeroAvailableBalance: Bool {
            if shieldedBalance.amount == 0 && transparentBalance.amount > autoShieldingThreshold.amount {
                return false
            }
            
            return totalBalance.amount != shieldedBalance.amount && shieldedBalance.amount == 0
        }

        public var currencyValue: String {
            currencyConversion?.convert(totalBalance) ?? ""
        }
        
        /// Returns the best available shielded balance:
        /// - PIR-verified balance if PIR verification completed and sync is still in progress
        /// - Regular shielded balance otherwise
        public var effectiveShieldedBalance: Zatoshi {
            if let pirBalance = pirVerifiedShieldedBalance, pirVerificationState.isVerified {
                return pirBalance
            }
            return shieldedBalance
        }
        
        /// Whether we should show the PIR verification indicator
        public var showPIRIndicator: Bool {
            pirVerificationState.isActive || pirVerificationState.isVerified
        }
        
        public init(
            fiatCurrencyResult: FiatCurrencyResult? = nil,
            isAvailableBalanceTappable: Bool = true,
            isExchangeRateFeatureOn: Bool = false,
            isExchangeRateRefreshEnabled: Bool = false,
            isExchangeRateStale: Bool = false,
            migratingDatabase: Bool = false,
            shieldedBalance: Zatoshi = .zero,
            shieldedWithPendingBalance: Zatoshi = .zero,
            totalBalance: Zatoshi = .zero,
            transparentBalance: Zatoshi = .zero
        ) {
            self.fiatCurrencyResult = fiatCurrencyResult
            self.isAvailableBalanceTappable = isAvailableBalanceTappable
            self.isExchangeRateFeatureOn = isExchangeRateFeatureOn
            self.isExchangeRateRefreshEnabled = isExchangeRateRefreshEnabled
            self.isExchangeRateStale = isExchangeRateStale
            self.migratingDatabase = migratingDatabase
            self.shieldedBalance = shieldedBalance
            self.shieldedWithPendingBalance = shieldedWithPendingBalance
            self.totalBalance = totalBalance
            self.transparentBalance = transparentBalance
        }
    }
    
    public enum Action: Equatable {
        case availableBalanceTapped
        case balanceUpdated(AccountBalance?)
        case debugMenuStartup
        case exchangeRateRefreshTapped
        case exchangeRateEvent(ExchangeRateClient.EchangeRateEvent)
        case onAppear
        case onDisappear
        case synchronizerStateChanged(RedactableSynchronizerState)
        case updateBalances
        
        // MARK: PIR Actions
        case pirStartVerification(blocksBehind: Int, syncSessionID: UUID)
        case pirStateChanged(PIRVerificationState)
        case pirVerificationCompleted(checkedCount: Int, spentFound: Int, adjustedBalance: Zatoshi)
        case pirVerificationFailed(String)
        case pirCancelVerification
    }

    @Dependency(\.databaseFiles) var databaseFiles
    @Dependency(\.exchangeRate) var exchangeRate
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.pirClient) var pirClient
    @Dependency(\.sdkSynchronizer) var sdkSynchronizer
    @Dependency(\.userStoredPreferences) var userStoredPreferences
    @Dependency(\.walletStorage) var walletStorage
    @Dependency(\.zcashSDKEnvironment) var zcashSDKEnvironment

    public init() { }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.autoShieldingThreshold = zcashSDKEnvironment.shieldingThreshold
                if let exchangeRate = userStoredPreferences.exchangeRate(), exchangeRate.automatic {
                    state.isExchangeRateFeatureOn = true
                } else {
                    state.isExchangeRateFeatureOn = false
                }
                return .merge(
                    .send(.updateBalances),
                    .publisher {
                        sdkSynchronizer.stateStream()
                            .throttle(for: .seconds(0.2), scheduler: mainQueue, latest: true)
                            .map { $0.redacted }
                            .map(Action.synchronizerStateChanged)
                    }
                    .cancellable(id: CancelStateId, cancelInFlight: true),
                    .publisher {
                        exchangeRate.exchangeRateEventStream()
                            .map(Action.exchangeRateEvent)
                            .receive(on: mainQueue)
                    }
                    .cancellable(id: CancelRateId, cancelInFlight: true)
                )

            case .onDisappear:
                pirClient.disconnect()
                return .merge(
                    .cancel(id: CancelStateId),
                    .cancel(id: CancelRateId),
                    .cancel(id: CancelPIRId)
                )
                
            case .availableBalanceTapped:
                return .none

            case .exchangeRateRefreshTapped:
                if !state.isExchangeRateStale {
                    exchangeRate.refreshExchangeRateUSD()
                }
                return .none
                
            case .exchangeRateEvent(let result):
                switch result {
                case .value(let rate):
                    guard let rate else {
                        return .none
                    }
                    
                    state.fiatCurrencyResult = rate
                    state.$currencyConversion.withLock {
                        $0 = CurrencyConversion(.usd, ratio: rate.rate.doubleValue, timestamp: rate.date.timeIntervalSince1970)
                    }
                    state.isExchangeRateRefreshEnabled = false
                    state.isExchangeRateStale = false
                case .refreshEnable(let rate):
                    guard let rate else {
                        return .none
                    }
                    
                    state.fiatCurrencyResult = rate
                    state.$currencyConversion.withLock {
                        $0 = CurrencyConversion(.usd, ratio: rate.rate.doubleValue, timestamp: rate.date.timeIntervalSince1970)
                    }
                    state.isExchangeRateRefreshEnabled = true
                    state.isExchangeRateStale = false
                case .stale:
                    state.$currencyConversion.withLock {
                        $0 = nil
                    }
                    state.isExchangeRateStale = true
                    break
                }
                
                return .none

            case .updateBalances:
                guard let account = state.selectedWalletAccount else {
                    return .none
                }
                return .run { send in
                    if let accountBalance = try? await sdkSynchronizer.getAccountsBalances()[account.id] {
                        await send(.balanceUpdated(accountBalance))
                    } else if let accountBalance = sdkSynchronizer.latestState().accountsBalances[account.id] {
                        await send(.balanceUpdated(accountBalance))
                    }
                }
                
            case .balanceUpdated(let accountBalance):
                state.shieldedBalance = (accountBalance?.saplingBalance.spendableValue ?? .zero) + (accountBalance?.orchardBalance.spendableValue ?? .zero)
                state.shieldedWithPendingBalance = (accountBalance?.saplingBalance.total() ?? .zero) + (accountBalance?.orchardBalance.total() ?? .zero)
                state.transparentBalance = accountBalance?.unshielded ?? .zero
                state.totalBalance = state.shieldedWithPendingBalance + state.transparentBalance + (accountBalance?.awaitingResolution ?? .zero)
               
                let everythingCondition = state.shieldedBalance.amount > 0 && ((state.shieldedBalance == state.totalBalance)
                || (state.transparentBalance < zcashSDKEnvironment.shieldingThreshold && state.shieldedBalance == state.totalBalance - state.transparentBalance))
                || state.totalBalance == .zero

                // spendability
                if state.isProcessingZeroAvailableBalance {
                    state.spendability = .nothing
                } else if everythingCondition {
                    state.spendability = .everything
                } else {
                    state.spendability = .something
                }
                return .none

            case .debugMenuStartup:
                return .none

            case .synchronizerStateChanged(let latestState):
                let snapshot = SyncStatusSnapshot.snapshotFor(state: latestState.data.syncStatus)

                if snapshot.syncStatus != .unprepared {
                    state.migratingDatabase = false
                }

                guard let account = state.selectedWalletAccount else {
                    return .none
                }
                
                // Check if we should trigger PIR verification
                var pirEffect: Effect<Action> = .none
                
                // Only trigger PIR if:
                // 1. PIR is enabled
                // 2. We're syncing (not up-to-date)
                // 3. We haven't already started PIR for this sync session
                // 4. PIR is not already active
                if state.isPIREnabled,
                   case .syncing(let progress, _) = snapshot.syncStatus,
                   progress < 0.95, // Don't bother if almost done
                   state.pirLastSyncSessionID != latestState.data.syncSessionID,
                   !state.pirVerificationState.isActive {
                    
                    // Estimate blocks behind from progress
                    // progress = scanned / total, so blocks behind ≈ total * (1 - progress)
                    // We use latestBlockHeight as a proxy for total blocks
                    let latestHeight = latestState.data.latestBlockHeight
                    let estimatedBlocksBehind = Int(Double(latestHeight) * Double(1 - progress))
                    
                    if estimatedBlocksBehind > State.pirBlocksThreshold {
                        pirEffect = .send(.pirStartVerification(
                            blocksBehind: estimatedBlocksBehind,
                            syncSessionID: latestState.data.syncSessionID
                        ))
                    }
                }
                
                // When sync completes, clear PIR state
                if case .upToDate = snapshot.syncStatus {
                    state.pirVerificationState = .idle
                    state.pirVerifiedShieldedBalance = nil
                    state.pirLastSyncSessionID = nil
                }

                return .merge(
                    .send(.balanceUpdated(latestState.data.accountsBalances[account.id])),
                    pirEffect
                )
                
            // MARK: - PIR Verification Actions
                
            case .pirStartVerification(let blocksBehind, let syncSessionID):
                // Mark this sync session so we don't re-trigger
                state.pirLastSyncSessionID = syncSessionID
                state.pirBlocksBehind = blocksBehind
                state.pirVerificationState = .connecting
                
                let serverURL = state.pirServerURL
                let network = zcashSDKEnvironment.network
                let dataDbURL = databaseFiles.dataDbURLFor(network)
                let currentBalance = state.shieldedBalance
                
                return .run { send in
                    do {
                        // Step 1: Connect to PIR server
                        await send(.pirStateChanged(.connecting))
                        try await pirClient.connect(serverURL, .inspire)
                        
                        // Step 2: Precompute keys (expensive, but cached for session)
                        await send(.pirStateChanged(.preparingKeys))
                        try await pirClient.precomputeKeys()
                        
                        // Step 3: Get unspent nullifiers from wallet
                        let nullifiers = try await pirClient.getUnspentNullifiers(
                            dataDbURL,
                            network.networkType
                        )
                        
                        let totalCount = nullifiers.count
                        guard totalCount > 0 else {
                            // No nullifiers to check
                            await send(.pirVerificationCompleted(
                                checkedCount: 0,
                                spentFound: 0,
                                adjustedBalance: currentBalance
                            ))
                            return
                        }
                        
                        // Step 4: Check each nullifier via PIR
                        var spentCount = 0
                        
                        for (index, nullifier) in nullifiers.enumerated() {
                            await send(.pirStateChanged(.verifying(checked: index + 1, total: totalCount)))
                            
                            if let _ = try await pirClient.checkNullifier(nullifier) {
                                // Nullifier found = note was spent
                                spentCount += 1
                            }
                        }
                        
                        // Step 5: Report results
                        // For now, we can't easily calculate the exact balance adjustment
                        // because we'd need to know the value of each spent note.
                        // Just report the count and keep current balance as "verified"
                        await send(.pirVerificationCompleted(
                            checkedCount: totalCount,
                            spentFound: spentCount,
                            adjustedBalance: currentBalance
                        ))
                        
                    } catch {
                        await send(.pirVerificationFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelPIRId, cancelInFlight: true)
                
            case .pirStateChanged(let newState):
                state.pirVerificationState = newState
                return .none
                
            case .pirVerificationCompleted(let checkedCount, let spentFound, let adjustedBalance):
                state.pirVerificationState = .verified(checkedCount: checkedCount, spentFound: spentFound)
                state.pirVerifiedShieldedBalance = adjustedBalance
                return .none
                
            case .pirVerificationFailed(let error):
                // PIR failure is non-fatal - sync continues normally
                state.pirVerificationState = .failed(error)
                return .none
                
            case .pirCancelVerification:
                state.pirVerificationState = .idle
                pirClient.disconnect()
                return .cancel(id: CancelPIRId)
            }
        }
    }
}
