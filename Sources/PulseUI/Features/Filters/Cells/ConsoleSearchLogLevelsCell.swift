// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchLogLevelsCell: View {
    @Binding var selection: Set<LoggerStore.Level>

    var isAllSelected: Bool {
        selection.count == LoggerStore.Level.allCases.count
    }

    func toggleSelectAll() {
        if isAllSelected {
            selection = []
        } else {
            selection = Set(LoggerStore.Level.allCases)
        }
    }

    func binding(forLevel level: LoggerStore.Level) -> Binding<Bool> {
        Binding(get: {
            self.selection.contains(level)
        }, set: { isOn in
            if isOn {
                self.selection.insert(level)
            } else {
                self.selection.remove(level)
            }
        })
    }

#if os(macOS)
    var body: some View {
        VStack(alignment: .leading, spacing: -16) {
            HStack {
                Spacer()
                Button(isAllSelected ? "Deselect All" : "Select All", action: toggleSelectAll)
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
                Toggle(level.name.capitalized, isOn: binding(forLevel: level))
            }
        }
    }
#else
    var body: some View {
        Section {
            ForEach(LoggerStore.Level.allCases, id: \.self) { level in
                HStack {
                    Checkbox(level.name.capitalized, isOn: binding(forLevel: level))
#if os(iOS)
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(Color.textColor(for: level))
#endif
                }
            }
        }
        Section {
            Button(isAllSelected ? "Deselect All" : "Select All", action: toggleSelectAll)
        }
    }
#endif
}
