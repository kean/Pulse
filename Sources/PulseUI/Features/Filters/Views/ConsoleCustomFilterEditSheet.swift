// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleCustomFilterEditSheet: View {
    var fieldGroups: [ConsoleCustomFilter.FieldGroup]
    var onSave: (ConsoleCustomFilter) -> Void
    var onDelete: (() -> Void)?

    @State private var draft: ConsoleCustomFilter

    package init(filter: ConsoleCustomFilter, fieldGroups: [ConsoleCustomFilter.FieldGroup], onSave: @escaping (ConsoleCustomFilter) -> Void, onDelete: (() -> Void)? = nil) {
        self._draft = State(initialValue: filter)
        self.fieldGroups = fieldGroups
        self.onSave = onSave
        self.onDelete = onDelete
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isValueFocused: Bool
    @State private var regexError: String?

    package var body: some View {
        NavigationView {
            Form {
                Section {
                    StringSearchCompactOptionsView(options: $draft.match)
                        .frame(height: 16)
                }
                Section {
                    Picker("Field", selection: $draft.field) {
                        ForEach(Array(fieldGroups.enumerated()), id: \.offset) { _, group in
                            Section {
                                ForEach(group.fields, id: \.self) { field in
                                    Text(field.title).tag(field)
                                }
                            }
                        }
                    }
                    TextField("Value", text: $draft.value, axis: .vertical)
                        .lineLimit(1...10)
                        .disableAutocorrection(true)
#if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
#endif
                        .focused($isValueFocused)
                        .onSubmit { performSave() }
                }
                Section {
                    Toggle("Inverted", isOn: $draft.isNegated)
                }
            }
            .animation(.snappy, value: draft.match.kind == .regex)
            .alert("Invalid Regular Expression", isPresented: Binding(get: { regexError != nil }, set: { if !$0 { regexError = nil } })) {
                Button("OK", role: .cancel) { regexError = nil }
            }
            .navigationTitle(onDelete != nil ? "Edit Filter" : "Add Filter")
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    makeButton(role: .cancel) { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    makeButton(role: .confirm) { performSave() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
#endif
        }
#if os(iOS) || os(visionOS)
        .presentationDetents([.medium])
#endif
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isValueFocused = true
            }
        }
    }

    private var canSave: Bool {
        !draft.value.isEmpty
    }

    private func performSave() {
        guard canSave else { return }
        if draft.match.kind == .regex {
            do {
                _ = try NSRegularExpression(pattern: draft.value)
            } catch {
                regexError = "Invalid regular expression"
                return
            }
        }
        onSave(draft)
        dismiss()
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    ConsoleCustomFilterEditSheet(
        filter: .defaultNetworkFilter(),
        fieldGroups: ConsoleCustomFilter.networkFieldGroups,
        onSave: { _ in }
    )
}
#endif
