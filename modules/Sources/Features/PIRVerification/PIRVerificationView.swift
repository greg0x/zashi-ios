//
//  PIRVerificationView.swift
//  Zashi
//
//  Created for PIR integration.
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct PIRVerificationView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @Perception.Bindable var store: StoreOf<PIRVerification>
    
    public init(store: StoreOf<PIRVerification>) {
        self.store = store
    }
    
    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        illustration()
                            .padding(.top, 40)
                            .padding(.bottom, 32)
                        
                        statusContent()
                            .padding(.bottom, 24)
                        
                        // Server URL configuration (for testing)
                        if case .idle = store.verificationState {
                            serverUrlField()
                                .padding(.bottom, 24)
                        }
                    }
                }
                
                Spacer()
                
                actionButtons()
                    .padding(.bottom, 24)
            }
            .screenHorizontalPadding()
            .applyScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .zashiBack()
            .screenTitle("Private Balance Check")
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
            .alert(
                "Cancel Verification?",
                isPresented: $store.showCancelConfirmation
            ) {
                Button("Continue", role: .cancel) {
                    store.send(.cancelConfirmationDismissed)
                }
                Button("Cancel", role: .destructive) {
                    store.send(.cancelVerification)
                }
            } message: {
                Text("The verification is in progress. Are you sure you want to cancel?")
            }
        }
    }
    
    @ViewBuilder
    private func serverUrlField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PIR Server URL")
                .zFont(.medium, size: 14, style: Design.Text.tertiary)
            
            TextField("Server URL", text: $store.serverURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .zFont(size: 14, style: Design.Text.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius._lg)
                .fill(Design.Surfaces.bgSecondary.color(colorScheme))
        }
    }
    
    @ViewBuilder
    private func illustration() -> some View {
        ZStack {
            Circle()
                .fill(Design.Surfaces.bgSecondary.color(colorScheme))
                .frame(width: 120, height: 120)
            
            switch store.verificationState {
            case .idle:
                Asset.Assets.Icons.shieldZap.image
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Asset.Colors.primary.color)
                    .frame(width: 48, height: 48)
                
            case .connecting, .preparingKeys:
                ProgressView()
                    .scaleEffect(2.0)
                
            case .verifying:
                ZStack {
                    Circle()
                        .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Asset.Assets.shield.image
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Asset.Colors.primary.color)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: progressValue())
                        .stroke(Asset.Colors.primary.color, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progressValue())
                }
                
            case .completed(_, let newlySpent):
                Image(systemName: newlySpent == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .resizable()
                    .foregroundColor(newlySpent == 0 ? Asset.Colors.primary.color : .orange)
                    .frame(width: 48, height: 48)
                
            case .failed:
                Image(systemName: "xmark.shield.fill")
                    .resizable()
                    .foregroundColor(.red)
                    .frame(width: 48, height: 48)
            }
        }
    }
    
    @ViewBuilder
    private func statusContent() -> some View {
        VStack(spacing: 12) {
            Text(statusTitle())
                .zFont(.semiBold, size: 20, style: Design.Text.primary)
            
            Text(store.statusMessage)
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func actionButtons() -> some View {
        switch store.verificationState {
        case .idle, .failed:
            ZashiButton("Start Private Verification") {
                store.send(.startVerification)
            }
            
        case .connecting, .preparingKeys, .verifying:
            ZashiButton("Cancel", type: .secondary) {
                store.send(.cancelRequested)
            }
            
        case .completed:
            ZashiButton("Verify Again", type: .secondary) {
                store.send(.startVerification)
            }
        }
    }
    
    private func statusTitle() -> String {
        switch store.verificationState {
        case .idle:
            return "Private Balance Verification"
        case .connecting:
            return "Connecting..."
        case .preparingKeys:
            return "Preparing Keys..."
        case .verifying:
            return "Verifying..."
        case .completed:
            return "Verification Complete"
        case .failed:
            return "Verification Failed"
        }
    }
    
    private func progressValue() -> CGFloat {
        if case .verifying(let progress, let total) = store.verificationState {
            return CGFloat(progress) / CGFloat(total)
        }
        return 0
    }
}

// MARK: - Previews

#Preview("Idle") {
    NavigationView {
        PIRVerificationView(
            store: StoreOf<PIRVerification>(
                initialState: PIRVerification.State()
            ) {
                PIRVerification()
            }
        )
    }
}

// MARK: - Placeholders

extension PIRVerification.State {
    public static let initial = PIRVerification.State()
}

extension StoreOf<PIRVerification> {
    public static let initial = StoreOf<PIRVerification>(
        initialState: .initial
    ) {
        PIRVerification()
    }
}
