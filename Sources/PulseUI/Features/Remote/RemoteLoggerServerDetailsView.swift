// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Network

@available(iOS 15, *)
struct RemoteLoggerServerDetailsView: View {
    let server: NWBrowser.Result

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        List {
            Section("Details") {
                switch server.endpoint {
                case let .hostPort(host, port):
                    InfoRow(title: "Host", details: "\(host)")
                    InfoRow(title: "Port", details: "\(port)")
                case let .service(name, type, domain, interface):
                    InfoRow(title: "Service", details: name)
                    InfoRow(title: "Type", details: type)
                    InfoRow(title: "Address", details: domain)
                    if let interface {
                        InfoRow(title: "Interface", details: "\(interface)")
                    }
                case let .unix(path):
                    InfoRow(title: "Path", details: path)
                default:
                    Text("Unknown")
                }
            }
            switch server.metadata {
            case .bonjour(let record):
                Section("Metadata") {
                    ForEach(record.dictionary.keys.sorted(by: { $0 < $1 }), id: \.self) {
                        InfoRow(title: $0, details: record.dictionary[$0]!)
                    }
                }
            case .none:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
        .inlineNavigationTitle("Device")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
