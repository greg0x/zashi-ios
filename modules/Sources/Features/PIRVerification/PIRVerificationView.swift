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
            ScrollView {
                VStack(spacing: 16) {
                    // Configuration Section
                    configurationSection()
                    
                    // Test Mode Section
                    testModeSection()
                    
                    // Verification Section
                    verificationSection()
                    
                    // Metrics Section (if available)
                    if let metrics = store.lastQueryMetrics {
                        metricsSection(metrics)
                    }
                    
                    // Spent Notes Found (if any)
                    if !store.spentNotesFound.isEmpty {
                        spentNotesSection()
                    }
                    
                    // Technical Details (expandable)
                    if store.showTechnicalDetails {
                        technicalDetailsSection()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .applyScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .zashiBack()
            .screenTitle("Private Balance Check")
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
    
    // MARK: - Configuration Section
    
    @ViewBuilder
    private func configurationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "⚙️ Configuration")
            
            VStack(spacing: 12) {
                // Connection Status
                HStack {
                    Text("Status")
                        .zFont(.medium, size: 14, style: Design.Text.tertiary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 8, height: 8)
                        Text(store.connectionStatusText)
                            .zFont(.medium, size: 14, style: Design.Text.primary)
                    }
                }
                
                // Connection info
                if !store.connectionState.isConnected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Uses lightwalletd connection (InsPIRe protocol)")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        
                        // Connection error with retry
                        if case .failed(let error) = store.connectionState {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .zFont(size: 12, style: Design.Text.tertiary)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Button {
                                    store.send(.connect)
                                } label: {
                                    Text("Retry")
                                        .zFont(.medium, size: 12, style: Design.Text.primary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } else if store.serverInfo != nil {
                    Text("Using lightwalletd connection (InsPIRe protocol)")
                        .zFont(size: 12, style: Design.Text.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                // Technical Details Toggle
                Button {
                    store.send(.toggleTechnicalDetails)
                } label: {
                    HStack {
                        Text(store.showTechnicalDetails ? "Hide Technical Details" : "Show Technical Details")
                            .zFont(.medium, size: 14, style: Design.Text.primary)
                        Spacer()
                        Image(systemName: store.showTechnicalDetails ? "chevron.up" : "chevron.down")
                            .foregroundColor(Asset.Colors.primary.color)
                    }
                }
            }
        }
        .sectionCard(colorScheme: colorScheme)
    }
    
    private var connectionStatusColor: Color {
        switch store.connectionState {
        case .disconnected, .failed:
            return .red
        case .connecting, .preparingKeys:
            return .orange
        case .connected:
            return .green
        }
    }
    
    // MARK: - Test Mode Section
    
    @ViewBuilder
    private func testModeSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "🔬 Test Mode")
            
            Text("Test PIR with known nullifiers to verify correctness.")
                .zFont(size: 14, style: Design.Text.tertiary)
            
            HStack(spacing: 12) {
                Button {
                    store.send(.runTest(.unspent))
                } label: {
                    HStack {
                        if case .running(.unspent) = store.testResult {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Test Unspent")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                    )
                }
                .disabled(store.isOperationInProgress)
                
                Button {
                    store.send(.runTest(.spent))
                } label: {
                    HStack {
                        if case .running(.spent) = store.testResult {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Test Known Spent")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                    )
                }
                .disabled(store.isOperationInProgress)
            }
            .zFont(.medium, size: 14, style: Design.Text.primary)
            
            // Test Result
            testResultView()
        }
        .sectionCard(colorScheme: colorScheme)
    }
    
    @ViewBuilder
    private func testResultView() -> some View {
        switch store.testResult {
        case .none:
            EmptyView()
            
        case .running(let testType):
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Running \(testType.rawValue) test...")
                    .zFont(size: 14, style: Design.Text.tertiary)
            }
            
        case .passed(let testType, let spentInfo):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Test passed: correctly identified as \(testType == .spent ? "spent" : "unspent")")
                        .zFont(.medium, size: 14, style: Design.Text.primary)
                }
                
                if let info = spentInfo {
                    Text("Block \(info.blockHeight.formatted()) • TX #\(info.txIndex)")
                        .zFont(size: 12, style: Design.Text.tertiary)
                }
            }
            
        case .failed(let testType, let error):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Test failed")
                        .zFont(.medium, size: 14, style: Design.Text.primary)
                }
                Text(error)
                    .zFont(size: 12, style: Design.Text.tertiary)
                
                Button {
                    store.send(.runTest(testType))
                } label: {
                    Text("Retry")
                        .zFont(.medium, size: 12, style: Design.Text.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                        )
                }
            }
        }
    }
    
    // MARK: - Verification Section
    
    @ViewBuilder
    private func verificationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "💰 Verify Wallet")
            
            // Status illustration
            illustration()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            
            // Status message
            Text(store.statusMessage)
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            // Action button
            actionButton()
                .padding(.top, 8)
            
            // Last verified
            if let lastVerified = store.lastVerified {
                Text("Last verified: \(lastVerified, style: .relative) ago")
                    .zFont(size: 12, style: Design.Text.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .sectionCard(colorScheme: colorScheme)
    }
    
    @ViewBuilder
    private func illustration() -> some View {
        ZStack {
            Circle()
                .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                .frame(width: 100, height: 100)
            
            switch store.verificationState {
            case .idle:
                Image(systemName: "shield.fill")
                    .resizable()
                    .foregroundColor(Asset.Colors.primary.color)
                    .frame(width: 40, height: 40)
                
            case .connecting, .preparingKeys:
                ProgressView()
                    .scaleEffect(1.5)
                
            case .verifying:
                ZStack {
                    Circle()
                        .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "shield.fill")
                        .resizable()
                        .foregroundColor(Asset.Colors.primary.color)
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .trim(from: 0, to: progressValue())
                        .stroke(Asset.Colors.primary.color, lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progressValue())
                }
                
            case .completed(_, let newlySpent):
                Image(systemName: newlySpent == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .resizable()
                    .foregroundColor(newlySpent == 0 ? .green : .orange)
                    .frame(width: 40, height: 40)
                
            case .failed:
                Image(systemName: "xmark.shield.fill")
                    .resizable()
                    .foregroundColor(.red)
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    @ViewBuilder
    private func actionButton() -> some View {
        switch store.verificationState {
        case .idle:
            ZashiButton("Verify Balance Privately") {
                store.send(.startVerification)
            }
            .disabled(store.isOperationInProgress)
            
        case .failed:
            VStack(spacing: 12) {
                ZashiButton("Retry Verification") {
                    store.send(.retryLastOperation)
                }
                
                Button {
                    store.send(.verificationStateChanged(.idle))
                } label: {
                    Text("Dismiss")
                        .zFont(.medium, size: 14, style: Design.Text.tertiary)
                }
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
    
    private func progressValue() -> CGFloat {
        if case .verifying(let progress, let total) = store.verificationState {
            return CGFloat(progress) / CGFloat(total)
        }
        return 0
    }
    
    // MARK: - Metrics Section
    
    @ViewBuilder
    private func metricsSection(_ metrics: QueryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "📊 Performance Metrics")
            
            // Timing breakdown with percentages
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing Breakdown")
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
                
                HStack(spacing: 8) {
                    timingColumn("Query Gen", "\(metrics.queryGenerationMs)ms", pct: timingPct(metrics.queryGenerationMs, total: metrics.totalMs))
                    timingColumn("Network", "\(metrics.networkMs)ms", pct: timingPct(metrics.networkMs, total: metrics.totalMs))
                    timingColumn("Server", "\(metrics.serverProcessingMs)ms", pct: timingPct(metrics.serverProcessingMs, total: metrics.totalMs))
                    timingColumn("Decrypt", "\(metrics.decryptionMs)ms", pct: timingPct(metrics.decryptionMs, total: metrics.totalMs))
                }
                
                Text("Total: \(metrics.totalMs)ms for \(metrics.nullifiersChecked) nullifiers (\(String(format: "%.0f", metrics.perQueryMs))ms/query)")
                    .zFont(size: 12, style: Design.Text.tertiary)
                
                // Time comparison vs traditional sync
                let traditionalMs = metrics.estimatedSyncTimeMs
                let pirMs = metrics.totalMs
                
                HStack(spacing: 4) {
                    if traditionalMs > pirMs {
                        let timeMultiplier = Double(traditionalMs) / Double(max(1, pirMs))
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                        Text("**\(String(format: "%.0f", timeMultiplier))x faster** than traditional sync (\(formatTime(traditionalMs)) → \(formatTime(pirMs)))")
                            .zFont(size: 12, style: Design.Text.primary)
                    } else if pirMs > traditionalMs {
                        let timeMultiplier = Double(pirMs) / Double(max(1, traditionalMs))
                        Image(systemName: "tortoise.fill")
                            .foregroundColor(.orange)
                        Text("**\(String(format: "%.1f", timeMultiplier))x slower** than traditional sync (\(formatTime(traditionalMs)) → \(formatTime(pirMs)))")
                            .zFont(size: 12, style: Design.Text.primary)
                    } else {
                        Image(systemName: "equal.circle.fill")
                            .foregroundColor(.gray)
                        Text("Same speed as traditional sync")
                            .zFont(size: 12, style: Design.Text.primary)
                    }
                }
                .padding(.top, 4)
            }
            
            Divider()
            
            // Comparison with traditional sync
            VStack(alignment: .leading, spacing: 8) {
                Text("vs Traditional Sync (oldest note scenario):")
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
                
                // Bandwidth comparison
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Traditional")
                            .zFont(size: 10, style: Design.Text.tertiary)
                        Text(formatBytes(metrics.estimatedSyncBytes))
                            .zFont(.medium, size: 14, style: Design.Text.primary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(Design.Text.tertiary.color(colorScheme))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PIR (\(metrics.nullifiersChecked) notes)")
                            .zFont(size: 10, style: Design.Text.tertiary)
                        Text(formatBytes(metrics.totalPIRBytes))
                            .zFont(.medium, size: 14, style: Design.Text.primary)
                    }
                    
                    Spacer()
                    
                    if metrics.pirIsMoreEfficient {
                        Text("✓ \(metrics.bandwidthSavingsFactor)x less")
                            .zFont(.semiBold, size: 12, style: Design.Utility.SuccessGreen._700)
                    } else {
                        let inverseMultiplier = Double(metrics.totalPIRBytes) / Double(max(1, metrics.estimatedSyncBytes))
                        Text("✗ \(String(format: "%.1f", inverseMultiplier))x more")
                            .zFont(.semiBold, size: 12, style: Design.Utility.ErrorRed._700)
                    }
                }
                
                // Scenario breakdown with multipliers
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bandwidth by scenario:")
                        .zFont(size: 10, style: Design.Text.tertiary)
                    HStack(spacing: 8) {
                        ForEach([TraditionalSyncEstimates.Scenario.oneDay, .oneWeek, .oneMonth], id: \.self) { scenario in
                            let traditionalBytes = scenario.estimatedBytes
                            let pirBytes = metrics.totalPIRBytes
                            VStack(spacing: 1) {
                                Text(scenario.rawValue.replacingOccurrences(of: " offline", with: ""))
                                    .zFont(size: 9, style: Design.Text.tertiary)
                                Text(scenario.description)
                                    .zFont(.medium, size: 10, style: Design.Text.primary)
                                if traditionalBytes > pirBytes {
                                    let multiplier = Double(traditionalBytes) / Double(max(1, pirBytes))
                                    Text("\(String(format: "%.0f", multiplier))x less")
                                        .zFont(.semiBold, size: 9, style: Design.Utility.SuccessGreen._700)
                                } else if pirBytes > traditionalBytes {
                                    let multiplier = Double(pirBytes) / Double(max(1, traditionalBytes))
                                    Text("\(String(format: "%.1f", multiplier))x more")
                                        .zFont(.semiBold, size: 9, style: Design.Utility.ErrorRed._700)
                                } else {
                                    Text("Same")
                                        .zFont(size: 9, style: Design.Text.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            Divider()
            
            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("🔒 Privacy: Server learned nothing")
                        .zFont(.medium, size: 14, style: Design.Text.primary)
                    Text("PIR query reveals nothing about which nullifier was checked")
                        .zFont(size: 11, style: Design.Text.tertiary)
                }
            }
        }
        .sectionCard(colorScheme: colorScheme)
    }
    
    @ViewBuilder
    private func timingColumn(_ label: String, _ value: String, pct: Int? = nil) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .zFont(size: 10, style: Design.Text.tertiary)
            Text(value)
                .zFont(.medium, size: 14, style: Design.Text.primary)
            if let pct = pct {
                Text("\(pct)%")
                    .zFont(size: 9, style: Design.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Design.Surfaces.bgTertiary.color(colorScheme))
        )
    }
    
    /// Calculate percentage of total
    private func timingPct(_ value: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(round(Double(value) / Double(total) * 100))
    }
    
    /// Format milliseconds into human-readable time
    private func formatTime(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else if ms < 60_000 {
            return String(format: "%.1fs", Double(ms) / 1000)
        } else {
            let minutes = ms / 60_000
            let seconds = (ms % 60_000) / 1000
            return "\(minutes)m \(seconds)s"
        }
    }
    
    /// Format bytes into human-readable string (KB, MB, GB)
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1_000
        let mb = kb / 1_000
        let gb = mb / 1_000
        
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
    
    // MARK: - Spent Notes Section
    
    @ViewBuilder
    private func spentNotesSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "⚠️ Found \(store.spentNotesFound.count) Spent Notes")
            
            ForEach(store.spentNotesFound) { note in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block \(note.blockHeight.formatted())")
                            .zFont(.medium, size: 14, style: Design.Text.primary)
                        Text("TX #\(note.txIndex) • \(note.discoveredAt, style: .date)")
                            .zFont(size: 12, style: Design.Text.tertiary)
                    }
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                if note.id != store.spentNotesFound.last?.id {
                    Divider()
                }
            }
            
            Text("Balance updated automatically.")
                .zFont(size: 12, style: Design.Text.tertiary)
        }
        .sectionCard(colorScheme: colorScheme, borderColor: .orange)
    }
    
    // MARK: - Technical Details Section
    
    @ViewBuilder
    private func technicalDetailsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "🔧 Technical Details")
            
            if let info = store.serverInfo {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Protocol")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        Text(info.protocolName)
                            .zFont(size: 12, style: Design.Text.primary)
                    }
                    
                    if let lweDim = info.lweDim, let ringDim = info.ringDim {
                        GridRow {
                            Text("Dimensions")
                                .zFont(size: 12, style: Design.Text.tertiary)
                            Text("LWE: \(lweDim) | Ring: \(ringDim)")
                                .zFont(size: 12, style: Design.Text.primary)
                        }
                    }
                    
                    GridRow {
                        Text("Records")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        Text("\(formatNumber(info.numNullifiers)) nullifiers")
                            .zFont(size: 12, style: Design.Text.primary)
                    }
                    
                    GridRow {
                        Text("Keyword Method")
                            .zFont(size: 12, style: Design.Text.tertiary)
                        Text("\(info.keywordMethod) (2 queries per lookup)")
                            .zFont(size: 12, style: Design.Text.primary)
                    }
                }
            } else {
                Text("Connect to server to see details")
                    .zFont(size: 12, style: Design.Text.tertiary)
            }
        }
        .sectionCard(colorScheme: colorScheme)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .zFont(.semiBold, size: 16, style: Design.Text.primary)
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}

// MARK: - Section Card Modifier

extension View {
    @ViewBuilder
    func sectionCard(colorScheme: ColorScheme, borderColor: Color? = nil) -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Design.Surfaces.bgSecondary.color(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor ?? Color.clear, lineWidth: borderColor != nil ? 2 : 0)
            )
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

#Preview("Connected with Metrics") {
    NavigationView {
        PIRVerificationView(
            store: StoreOf<PIRVerification>(
                initialState: {
                    var state = PIRVerification.State()
                    state.connectionState = .connected
                    state.serverInfo = ServerInfo(
                        protocolName: "YPIR",
                        numRecords: 6_462_500,
                        numNullifiers: 51_700_000,
                        keywordMethod: "Cuckoo",
                        lweDim: 1024,
                        ringDim: 1024
                    )
                    state.verificationState = .completed(checkedCount: 5, newlySpentCount: 0)
                    state.lastQueryMetrics = QueryMetrics(
                        queryGenerationMs: 150,
                        networkMs: 120,
                        serverProcessingMs: 80,
                        decryptionMs: 30,
                        totalMs: 380,
                        uploadedBytes: 1_500_000,
                        downloadedBytes: 800,
                        nullifiersChecked: 5
                    )
                    return state
                }()
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
