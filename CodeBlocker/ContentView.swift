import SwiftUI
import CallKit

struct ContentView: View {
    @State private var blockedPrefixes: [String] = []
    @State private var showingAddSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var extensionStatus = "Unknown"

    private let manager = BlockedAreaCodesManager.shared

    var body: some View {
        NavigationView {
            VStack {
                extensionStatusBanner

                if blockedPrefixes.isEmpty {
                    emptyStateView
                } else {
                    prefixList
                }

                applyChangesButton
            }
            .navigationTitle("CodeBlocker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddAreaCodeView { newPrefix in
                    manager.addPrefix(newPrefix)
                    loadPrefixes()
                }
            }
            .alert("CodeBlocker", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadPrefixes()
                checkExtensionStatus()
            }
        }
    }

    // MARK: - Subviews

    private var extensionStatusBanner: some View {
        HStack {
            Circle()
                .fill(extensionStatus == "Enabled" ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text("Extension: \(extensionStatus)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "phone.down.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Blocked Numbers")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Tap + to add area codes or number ranges you want to block.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }

    private var prefixList: some View {
        List {
            ForEach(blockedPrefixes, id: \.self) { prefix in
                HStack {
                    Image(systemName: "phone.down.fill")
                        .foregroundColor(.red)
                    Text(BlockedAreaCodesManager.prefixLabel(prefix))
                        .font(.body)
                    Spacer()
                    Text(BlockedAreaCodesManager.formatPrefix(prefix))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deletePrefixes)
        }
    }

    private var applyChangesButton: some View {
        Button(action: applyChanges) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Apply Changes")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Actions

    private func loadPrefixes() {
        blockedPrefixes = manager.blockedPrefixes
    }

    private func deletePrefixes(at offsets: IndexSet) {
        for index in offsets {
            manager.removePrefix(blockedPrefixes[index])
        }
        loadPrefixes()
    }

    private func applyChanges() {
        manager.reloadExtension { error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Failed to apply changes: \(error.localizedDescription)"
                } else {
                    alertMessage = "Changes applied successfully! Blocked numbers are now active."
                }
                showingAlert = true
                checkExtensionStatus()
            }
        }
    }

    private func checkExtensionStatus() {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
            withIdentifier: "com.codeblocker.app.CallBlockerExtension"
        ) { status, _ in
            DispatchQueue.main.async {
                switch status {
                case .enabled:
                    extensionStatus = "Enabled"
                case .disabled:
                    extensionStatus = "Disabled — Enable in Settings → Phone → Call Blocking"
                case .unknown:
                    extensionStatus = "Unknown"
                @unknown default:
                    extensionStatus = "Unknown"
                }
            }
        }
    }
}
