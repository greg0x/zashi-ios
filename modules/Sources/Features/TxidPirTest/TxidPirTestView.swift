//
//  TxidPirTestView.swift
//  Zashi
//
//  Minimal test UI for txid PIR integration.
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct TxidPirTestView: View {
    @Perception.Bindable var store: StoreOf<TxidPirTest>

    public init(store: StoreOf<TxidPirTest>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 20) {
                    connectionSection
                    txLookupSection
                    actionDataSection
                    timingSection
                    errorSection
                }
                .padding(16)
            }
            .applyScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .zashiBack()
            .screenTitle("Txid PIR Test")
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
        }
    }

    // MARK: - Connection Section

    @ViewBuilder
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .zFont(.semiBold, size: 16, style: Design.Text.primary)

            // Server URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Server URL")
                    .zFont(size: 12, style: Design.Text.tertiary)
                TextField("Server URL", text: $store.serverURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // Status
            HStack {
                Text("Status:")
                    .zFont(size: 14, style: Design.Text.tertiary)
                Spacer()
                Text(connectionStatusText)
                    .zFont(.medium, size: 14, style: Design.Text.primary)
            }

            // Params info (when loaded)
            if let params = store.txLookupParams {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TX DB: \(params.txCount) txs, blocks \(params.startHeight)-\(params.endHeight)")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    Text("InSPIRe: \(params.inspire.dbRows)x\(params.inspire.dbCols), n=\(params.inspire.polyLen)")
                        .zFont(size: 12, style: Design.Text.tertiary)
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Connect") {
                    store.send(.connect)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)

                Button("Precompute Keys") {
                    store.send(.precomputeKeys)
                }
                .buttonStyle(.bordered)
                .disabled(store.connectionState != .paramsLoaded)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - TX Lookup Section

    @ViewBuilder
    private var txLookupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TX Lookup Query")
                .zFont(.semiBold, size: 16, style: Design.Text.primary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block Height")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    TextField("Block Height", text: $store.blockHeightInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TX Index")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    TextField("TX Index", text: $store.txIndexInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }

            Button("Query TX Lookup") {
                store.send(.queryTxLookup)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.connectionState != .ready)

            // Result
            if let result = store.txLookupResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Result:")
                        .zFont(.medium, size: 14, style: Design.Text.primary)
                    Text("Start Index: \(result.startIndex)")
                        .zFont(size: 13, style: Design.Text.secondary)
                    Text("Action Count: \(result.actionCount)")
                        .zFont(size: 13, style: Design.Text.secondary)

                    Button("Use for Action Data Query") {
                        store.send(.fillActionDataFromResult)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Action Data Section

    @ViewBuilder
    private var actionDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Data Query")
                .zFont(.semiBold, size: 16, style: Design.Text.primary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Index")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    TextField("Start Index", text: $store.startIndexInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Action Count")
                        .zFont(size: 12, style: Design.Text.tertiary)
                    TextField("Count", text: $store.actionCountInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }

            Button("Query Action Data") {
                store.send(.queryActionData)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.connectionState != .ready)

            // Results
            if !store.actionDataResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions Retrieved: \(store.actionDataResult.count)")
                        .zFont(.medium, size: 14, style: Design.Text.primary)

                    ForEach(store.actionDataResult.prefix(3)) { action in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("cv: \(action.cvHex)")
                                .zFont(size: 11, style: Design.Text.tertiary)
                                .lineLimit(1)
                            Text("out: \(action.outCiphertextHex)...")
                                .zFont(size: 11, style: Design.Text.tertiary)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)))
                    }

                    if store.actionDataResult.count > 3 {
                        Text("... and \(store.actionDataResult.count - 3) more")
                            .zFont(size: 12, style: Design.Text.tertiary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Timing Section

    @ViewBuilder
    private var timingSection: some View {
        if let timing = store.lastQueryTiming {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Query Timing")
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                Group {
                    timingRow("Query Gen", timing.queryGenMs)
                    timingRow("Network", timing.networkMs)
                    timingRow("Server", timing.serverMs)
                    timingRow("Decrypt", timing.decryptMs)
                    Divider()
                    timingRow("Total", timing.totalMs, bold: true)
                }

                HStack {
                    Text("Upload: \(formatBytes(timing.uploadBytes))")
                    Spacer()
                    Text("Download: \(formatBytes(timing.downloadBytes))")
                }
                .zFont(size: 12, style: Design.Text.tertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error = store.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                        .zFont(.semiBold, size: 14, style: Design.Text.primary)
                }
                Text(error)
                    .zFont(size: 13, style: Design.Text.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
        }
    }

    // MARK: - Helpers

    private var connectionStatusText: String {
        switch store.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .paramsLoaded: return "Params Loaded"
        case .precomputing: return "Precomputing Keys..."
        case .ready: return "Ready"
        case .error: return "Error"
        }
    }

    private var isConnecting: Bool {
        if case .connecting = store.connectionState { return true }
        if case .precomputing = store.connectionState { return true }
        return false
    }

    @ViewBuilder
    private func timingRow(_ label: String, _ ms: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .zFont(bold ? .semiBold : .regular, size: 13, style: Design.Text.secondary)
            Spacer()
            Text(String(format: "%.1f ms", ms))
                .zFont(bold ? .semiBold : .regular, size: 13, style: Design.Text.primary)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TxidPirTestView(
            store: Store(initialState: TxidPirTest.State()) {
                TxidPirTest()
            }
        )
    }
}
