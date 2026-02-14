import SwiftUI

struct AddAreaCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var areaCode = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    let onAdd: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Area Code (e.g. 212)", text: $areaCode)
                        .keyboardType(.numberPad)
                        .onChange(of: areaCode) { oldValue, newValue in
                            if newValue.count > 3 {
                                areaCode = String(newValue.prefix(3))
                            }
                            // Remove non-numeric characters
                            areaCode = areaCode.filter { $0.isNumber }
                        }
                } header: {
                    Text("Enter Area Code")
                } footer: {
                    Text("Enter a 3-digit North American area code (e.g., 212, 415, 800). All calls from numbers with this area code will be blocked.")
                }

                if BlockedAreaCodesManager.isValidAreaCode(areaCode) {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Will block all (\(areaCode)) XXX-XXXX numbers")
                        }
                    }
                }
            }
            .navigationTitle("Add Area Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAreaCode()
                    }
                    .disabled(!BlockedAreaCodesManager.isValidAreaCode(areaCode))
                }
            }
            .alert("Invalid Area Code", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addAreaCode() {
        let code = areaCode.trimmingCharacters(in: .whitespaces)
        guard BlockedAreaCodesManager.isValidAreaCode(code) else {
            errorMessage = "Please enter a valid 3-digit area code starting with 2-9."
            showingError = true
            return
        }

        let manager = BlockedAreaCodesManager.shared
        if manager.blockedAreaCodes.contains(code) {
            errorMessage = "Area code \(code) is already blocked."
            showingError = true
            return
        }

        if manager.blockedAreaCodes.count >= BlockedAreaCodesManager.maxBlockedAreaCodes {
            errorMessage = "You can block up to \(BlockedAreaCodesManager.maxBlockedAreaCodes) area codes. Remove an existing area code before adding a new one."
            showingError = true
            return
        }

        onAdd(code)
        dismiss()
    }
}
