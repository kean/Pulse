// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchLogLevelsCell: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

#if os(macOS)
    var body: some View {
        VStack(alignment: .leading, spacing: -16) {
            HStack {
                Spacer()
                Button(viewModel.isAllLogLevelsEnabled ? "Disable All" : "Enable All") {
                    viewModel.isAllLogLevelsEnabled.toggle()
                }
            }
            HStack(spacing: 24) {
                makeLevelsSection(levels: [.trace, .debug, .info])
                makeLevelsSection(levels: [.notice, .warning])
                makeLevelsSection(levels: [.error, .critical])
            }
            .fixedSize()
        }
    }

    private func makeLevelsSection(levels: [LoggerStore.Level]) -> some View {
        VStack(alignment: .leading) {
            Spacer()
            ForEach(levels, id: \.self) { level in
                Toggle(level.name.capitalized, isOn: viewModel.binding(forLevel: level))
            }
        }
    }
#else
    var body: some View {
        ForEach(LoggerStore.Level.allCases, id: \.self) { level in
            Checkbox(level.name.capitalized, isOn: viewModel.binding(forLevel: level))
        }
        Button(viewModel.isAllLogLevelsEnabled ? "Disable All" : "Enable All") {
            viewModel.isAllLogLevelsEnabled.toggle()
        }
    }
#endif
}
