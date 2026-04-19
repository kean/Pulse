// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchStatusCodeCell: View {
    @Binding var selection: ValuesRange<String>

#if os(watchOS)
    var body: some View {
        Picker("Status Code", selection: statusCodeOption) {
            ForEach(StatusCodeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
    }

    private var statusCodeOption: Binding<StatusCodeOption> {
        Binding(
            get: { StatusCodeOption(range: selection) },
            set: { selection = $0.range }
        )
    }

    private enum StatusCodeOption: Hashable, CaseIterable, Identifiable {
        case any, success, redirect, clientError, serverError, allErrors

        var id: Self { self }

        var title: String {
            switch self {
            case .any: "Any"
            case .success: "Success (2xx)"
            case .redirect: "Redirects (3xx)"
            case .clientError: "Client Errors (4xx)"
            case .serverError: "Server Errors (5xx)"
            case .allErrors: "All Errors"
            }
        }

        var range: ValuesRange<String> {
            switch self {
            case .any: .empty
            case .success: ValuesRange(lowerBound: "200", upperBound: "299")
            case .redirect: ValuesRange(lowerBound: "300", upperBound: "399")
            case .clientError: ValuesRange(lowerBound: "400", upperBound: "499")
            case .serverError: ValuesRange(lowerBound: "500", upperBound: "599")
            case .allErrors: ValuesRange(lowerBound: "400", upperBound: "599")
            }
        }

        init(range: ValuesRange<String>) {
            self = Self.allCases.first { $0.range == range } ?? .any
        }
    }
#else
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Status Code").lineLimit(1)
                Spacer()
                RangePicker(range: $selection)
            }
            .frame(height: 18) // Ensure cells have consistent height

            quickFilters
        }
    }

    private var quickFilters: some View {
        SuggestionPills {
            SuggestionPill("Success (2xx)") { selection = ValuesRange(lowerBound: "200", upperBound: "299") }
            SuggestionPill("Redirects (3xx)") { selection = ValuesRange(lowerBound: "300", upperBound: "399") }
            SuggestionPill("Client Errors (4xx)") { selection = ValuesRange(lowerBound: "400", upperBound: "499") }
            SuggestionPill("Server Errors (5xx)") { selection = ValuesRange(lowerBound: "500", upperBound: "599") }
            SuggestionPill("All Errors") { selection = ValuesRange(lowerBound: "400", upperBound: "599") }
        }
    }
#endif
}
