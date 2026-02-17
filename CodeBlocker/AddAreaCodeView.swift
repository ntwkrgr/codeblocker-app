import SwiftUI

struct AddAreaCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prefix = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    let onAdd: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("e.g. 212, 2124, or 212456", text: $prefix)
                        .keyboardType(.numberPad)
                        .onChange(of: prefix) { oldValue, newValue in
                            if newValue.count > 6 {
                                prefix = String(newValue.prefix(6))
                            }
                            prefix = prefix.filter { $0.isNumber }
                        }
                } header: {
                    Text("Enter Number Prefix")
                } footer: {
                    Text("Enter 3–6 digits to block a range of phone numbers. "
                       + "3 digits blocks an entire area code; more digits narrow the range "
                       + "(e.g., 212 → all of area code 212, 212456 → only exchange 456).")
                }

                if BlockedAreaCodesManager.isValidPrefix(prefix) {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Will block all \(BlockedAreaCodesManager.formatPrefix(prefix)) numbers")
                        }
                        if let count = BlockedAreaCodesManager.entryCount(for: prefix) {
                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(.secondary)
                                Text("~\(formatCount(count)) numbers")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Block Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPrefix()
                    }
                    .disabled(!BlockedAreaCodesManager.isValidPrefix(prefix))
                }
            }
            .alert("Cannot Add", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addPrefix() {
        let code = prefix.trimmingCharacters(in: .whitespaces)
        guard BlockedAreaCodesManager.isValidPrefix(code) else {
            errorMessage = "Please enter 3–6 digits. The first digit must be 2-9."
            showingError = true
            return
        }

        let manager = BlockedAreaCodesManager.shared
        if manager.blockedPrefixes.contains(code) {
            errorMessage = "Prefix \(BlockedAreaCodesManager.formatPrefix(code)) is already blocked."
            showingError = true
            return
        }

        if let conflict = manager.conflictingPrefix(for: code) {
            errorMessage = "Conflicts with existing rule \(BlockedAreaCodesManager.formatPrefix(conflict)). Remove it first."
            showingError = true
            return
        }

        let newEntries = BlockedAreaCodesManager.entryCount(for: code) ?? 0
        if manager.currentTotalEntries + newEntries > BlockedAreaCodesManager.maxTotalEntries {
            errorMessage = "Adding this rule would exceed the system limit. Remove some existing rules first."
            showingError = true
            return
        }

        onAdd(code)
        dismiss()
    }

    private func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
