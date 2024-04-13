// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Network

@available(iOS 15, visionOS 1.0, *)
struct RemoteLoggerErrorView: View {
    let error: NWError

    var body: some View {
        switch error {
        case .dns(let error):
            switch Int(error) {
            case kDNSServiceErr_NoAuth:
                RemoteLoggerNoAuthView()
            case kDNSServiceErr_PolicyDenied:
                RemoteLoggerPolicyDeniedView()
            default:
                RemoteLoggerPolicyGenericErrorView(error: self.error)
            }
        default:
            RemoteLoggerPolicyGenericErrorView(error: error)
        }
    }
}

private struct RemoteLoggerPolicyGenericErrorView: View {
    let error: NWError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices browser failed")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
        }
    }
}

private struct RemoteLoggerPolicyDeniedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local network access denied")
                .font(.headline)
            Text("Open **Settings** / **Privacy** / **Local Network** and check that the app is listed and the toggle is enabled")
                .font(.subheadline)
        }
#if os(iOS) || os(visionOS)
        Button("Open Settings") {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
#endif
    }
}

@available(iOS 15, visionOS 1.0, *)
private struct RemoteLoggerNoAuthView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Info.plist is misconfigured")
                .font(.headline)
            Text("Add the following to the app’s plist file to allow it to use [local networking](https://kean-docs.github.io/pulse/documentation/pulse/gettingstarted):")
                .font(.subheadline)

            Text(plistContents)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.separator.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.separator, lineWidth: 0.5)
                )
                .padding(.top, 8)
        }
#if os(iOS) || os(visionOS)
        Button("Copy Contents") {
            UXPasteboard.general.string = plistContents
        }
#endif
    }
}

private let plistContents = """
<key>NSLocalNetworkUsageDescription</key>
<string>Debugging purposes</string>
<key>NSBonjourServices</key>
<array>
  <string>_pulse._tcp</string>
</array>
"""

#if DEBUG
@available(iOS 15, visionOS 1.0, *)
struct Previews_RemoteLoggerNoAuthView_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            Section {
                RemoteLoggerPolicyDeniedView()
            }
            Section {
                RemoteLoggerNoAuthView()
            }
        }
    }
}
#endif
