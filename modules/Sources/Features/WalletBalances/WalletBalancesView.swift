//
//  WalletBalancesView.swift
//  Zashi
//
//  Created by Lukáš Korba on 04-02-2024
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct WalletBalancesView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @Perception.Bindable var store: StoreOf<WalletBalances>
    let tokenName: String
    let couldBeHidden: Bool
    let shortened: Bool

    public init(
        store: StoreOf<WalletBalances>,
        tokenName: String,
        couldBeHidden: Bool = false,
        shortened: Bool = false
    ) {
        self.store = store
        self.tokenName = tokenName
        self.couldBeHidden = couldBeHidden
        self.shortened = shortened
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                balanceContent()
                    .padding(.top, 40)
                    .anchorPreference(
                        key: ExchangeRateFeaturePreferenceKey.self,
                        value: .bounds
                    ) { $0 }
                    .accessDebugMenuWithHiddenGesture {
                        store.send(.debugMenuStartup)
                    }

                if shortened {
                    exchangeRate()
                }

                if store.migratingDatabase {
                    Text(L10n.Home.migratingDatabases)
                        .font(.custom(FontFamily.Inter.regular.name, size: 14))
                        .foregroundColor(Asset.Colors.primary.color)
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                } else if store.isPIREnabled {
                    // PIR status bar - always visible when PIR is enabled for testing
                    pirVerificationStatus()
                        .padding(.top, shortened ? 8 : 12)
                        .padding(.bottom, shortened ? 8 : 30)
                } else if store.spendability != .everything && !shortened {
                    Button {
                        store.send(.availableBalanceTapped)
                    } label: {
                        AvailableBalanceView(
                            balance: store.shieldedBalance,
                            showIndicator: store.isProcessingZeroAvailableBalance
                        )
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    }
                } else if !shortened {
                    Color.clear
                        .padding(.bottom, 30)
                }
            }
            .foregroundColor(Asset.Colors.primary.color)
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
        }
    }
    
    @ViewBuilder private func balanceContent() -> some View {
        HStack(spacing: 0) {
            ZcashSymbol()
                .frame(width: 32, height: 32)
                .zForegroundColor(Design.Text.primary)
            
            if shortened {
                ZatoshiText(store.totalBalance, .abbreviated)
                    .zFont(.semiBold, size: 48, style: Design.Text.primary)
            } else {
                ZatoshiRepresentationView(
                    balance: store.totalBalance,
                    fontName: FontFamily.Inter.semiBold.name,
                    mostSignificantFontSize: 48,
                    leastSignificantFontSize: 20,
                    format: .expanded,
                    couldBeHidden: couldBeHidden
                )
            }
        }
    }
    
    private func exchangeRate() -> some View {
        Group {
            if store.isExchangeRateFeatureOn {
                if store.currencyConversion == nil && !store.isExchangeRateStale {
                    HStack(spacing: 8) {
                        Text(L10n.General.loading)
                            .font(.custom(FontFamily.Inter.semiBold.name, size: 14))
                            .foregroundColor(Asset.Colors.primary.color)

                        ProgressView()
                    }
                    .frame(height: 36)
                    .padding(.top, 10)
                    .padding(.vertical, 5)
                }
                
                if store.currencyConversion != nil || store.isExchangeRateStale {
                    Button {
                        store.send(.exchangeRateRefreshTapped)
                    } label: {
                        if store.isExchangeRateStale {
                            HStack {
                                Text(L10n.Tooltip.ExchangeRate.title)
                                    .font(.custom(FontFamily.Inter.semiBold.name, size: 14))
                                    .foregroundColor(Asset.Colors.primary.color)

                                Asset.Assets.infoCircle.image
                                    .zImage(size: 20, color: Asset.Colors.primary.color)
                            }
                            .frame(maxWidth: .infinity)
                            .anchorPreference(
                                key: ExchangeRateStaleTooltipPreferenceKey.self,
                                value: .bounds
                            ) { $0 }
                        } else if store.isExchangeRateRefreshEnabled {
                            HStack {
                                Text(store.currencyValue)
                                    .hiddenIfSet()
                                    .font(.custom(FontFamily.Inter.semiBold.name, size: 14))
                                    .foregroundColor(Asset.Colors.primary.color)

                                if store.isExchangeRateUSDInFlight {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Asset.Assets.refreshCCW.image
                                        .zImage(size: 20, color: Asset.Colors.primary.color)
                                }
                            }
                            .padding(8)
                            .padding(.horizontal, 6)
                            .background {
                                RoundedRectangle(cornerRadius: Design.Radius._lg)
                                    .stroke(Design.Surfaces.strokePrimary.color(colorScheme))
                                    .background {
                                        Design.Surfaces.bgSecondary.color(colorScheme)
                                            .cornerRadius(10)
                                    }
                            }
                        } else {
                            HStack {
                                Text(store.currencyValue)
                                    .hiddenIfSet()
                                    .font(.custom(FontFamily.Inter.semiBold.name, size: 14))
                                    .foregroundColor(Asset.Colors.primary.color)

                                if store.isExchangeRateUSDInFlight {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 11, height: 14)
                                } else {
                                    Asset.Assets.refreshCCW.image
                                        .zImage(size: 20, color: Asset.Colors.shade72.color)
                                }
                            }
                            .padding(8)
                            .padding(.horizontal, 6)
                        }
                    }
                    .frame(height: 36)
                    .padding(.top, 10)
                    .padding(.vertical, 5)
                }
            }
        }
    }
    
    // MARK: - PIR Verification Status Bar
    
    /// PIR status bar - always visible when PIR is enabled, tappable to trigger verification
    @ViewBuilder private func pirVerificationStatus() -> some View {
        Button {
            store.send(.pirTriggerManually)
        } label: {
            HStack(spacing: 8) {
                pirStatusIcon()
                pirStatusText()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(pirStatusBackground())
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(pirStatusBorderColor(), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.pirVerificationState.isActive)
    }
    
    @ViewBuilder private func pirStatusIcon() -> some View {
        switch store.pirVerificationState {
        case .idle:
            Image(systemName: "shield.lefthalf.filled")
                .foregroundColor(Asset.Colors.shade55.color)
        case .connecting, .preparingKeys, .verifying:
            ProgressView()
                .scaleEffect(0.7)
        case .verified(_, let spentFound):
            if spentFound == 0 {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(Design.Utility.SuccessGreen._600.color(colorScheme))
            } else {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(Asset.Colors.ZDesign.errorRed500.color)
            }
        case .failed:
            Image(systemName: "xmark.shield.fill")
                .foregroundColor(Asset.Colors.shade55.color)
        }
    }
    
    @ViewBuilder private func pirStatusText() -> some View {
        switch store.pirVerificationState {
        case .idle:
            VStack(alignment: .leading, spacing: 2) {
                Text("PIR Preview")
                    .font(.custom(FontFamily.Inter.semiBold.name, size: 12))
                    .foregroundColor(Asset.Colors.shade55.color)
                Text("Tap to verify balance")
                    .font(.custom(FontFamily.Inter.regular.name, size: 11))
                    .foregroundColor(Asset.Colors.shade55.color.opacity(0.8))
            }
        case .connecting:
            Text("Connecting...")
                .font(.custom(FontFamily.Inter.regular.name, size: 12))
                .foregroundColor(Asset.Colors.shade55.color)
        case .preparingKeys:
            Text("Preparing keys...")
                .font(.custom(FontFamily.Inter.regular.name, size: 12))
                .foregroundColor(Asset.Colors.shade55.color)
        case .verifying(let checked, let total):
            Text("Verifying \(checked)/\(total)")
                .font(.custom(FontFamily.Inter.regular.name, size: 12))
                .foregroundColor(Asset.Colors.shade55.color)
        case .verified(let checkedCount, let spentFound):
            if spentFound == 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verified")
                        .font(.custom(FontFamily.Inter.semiBold.name, size: 12))
                        .foregroundColor(Design.Utility.SuccessGreen._600.color(colorScheme))
                    Text("\(checkedCount) notes checked")
                        .font(.custom(FontFamily.Inter.regular.name, size: 11))
                        .foregroundColor(Asset.Colors.shade55.color)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(spentFound) spent")
                        .font(.custom(FontFamily.Inter.semiBold.name, size: 12))
                        .foregroundColor(Asset.Colors.ZDesign.errorRed500.color)
                    Text("Sync to update")
                        .font(.custom(FontFamily.Inter.regular.name, size: 11))
                        .foregroundColor(Asset.Colors.shade55.color)
                }
            }
        case .failed(let error):
            VStack(alignment: .leading, spacing: 2) {
                Text("PIR unavailable")
                    .font(.custom(FontFamily.Inter.semiBold.name, size: 12))
                    .foregroundColor(Asset.Colors.shade55.color)
                Text(error.prefix(30) + (error.count > 30 ? "..." : ""))
                    .font(.custom(FontFamily.Inter.regular.name, size: 10))
                    .foregroundColor(Asset.Colors.shade55.color.opacity(0.8))
            }
        }
    }
    
    private func pirStatusBackground() -> Color {
        switch store.pirVerificationState {
        case .verified(_, let spentFound) where spentFound == 0:
            return Design.Utility.SuccessGreen._50.color(colorScheme).opacity(0.5)
        case .verified:
            return Asset.Colors.ZDesign.errorRed500.color.opacity(0.1)
        default:
            return Design.Surfaces.bgSecondary.color(colorScheme).opacity(0.8)
        }
    }
    
    private func pirStatusBorderColor() -> Color {
        switch store.pirVerificationState {
        case .verified(_, let spentFound) where spentFound == 0:
            return Design.Utility.SuccessGreen._600.color(colorScheme).opacity(0.3)
        case .verified:
            return Asset.Colors.ZDesign.errorRed500.color.opacity(0.3)
        default:
            return Design.Surfaces.strokePrimary.color(colorScheme).opacity(0.5)
        }
    }
}

// MARK: - Previews

#Preview {
    WalletBalancesView(store: WalletBalances.initial, tokenName: "ZEC")
}

// MARK: - Store

extension WalletBalances {
    public static var initial = StoreOf<WalletBalances>(
        initialState: .initial
    ) {
        WalletBalances()
    }
}

// MARK: - Placeholders

extension WalletBalances.State {
    public static let initial = WalletBalances.State(
        shieldedBalance: .zero
    )
}
