//  Created by Alexander Grebenyuk on 20.02.2021.

import Foundation
import SwiftUI

#if os(macOS)

struct DatePickerButton: View {
    let title: String
    @Binding var date: Date?
    @State private var isPresented = false

    var body: some View {
        let binding = Binding(get: {
            date ?? Date()
        }, set: { newValue in
            date = newValue
        })

        HStack {
            Text(title)
            Button(action: { isPresented.toggle() }){
                Text(date == nil ? "Select" : dateFormatter.string(from: date!))
            }
        }
        .sheet(isPresented: $isPresented) {
            Form {
                Section(header: Text(title)) {
                    DatePicker("", selection: binding)
                    .datePickerStyle(DefaultDatePickerStyle())
                    DatePicker("", selection: binding)
                    .datePickerStyle(GraphicalDatePickerStyle())
                }
            }
            .padding()
            .toolbar {
                Button(action: { date = nil }) {
                    Text("Remove")
                }
                Button(action: { isPresented = false }) {
                    Text("Done")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#endif
