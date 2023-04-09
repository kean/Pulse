// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if PULSE_STANDALONE_APP

import SwiftUI
import Combine
import Pulse
import Network

struct RemoteLoggerClientStatusView: View {
    @ObservedObject var client: RemoteLoggerClient
    @State var isShowingDetails = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Image(systemName: client.systemIconName)
                .background(iconBackground)
                .frame(height: 18, alignment: .center)
                .padding(.trailing, 8)
            VStack(alignment: .leading) {
                ((Text(client.deviceInfo.name).foregroundColor(Color.primary) + Text(" (\(client.deviceInfo.systemName + " " + client.deviceInfo.systemVersion))")).foregroundColor(Color.secondary))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !client.isConnected {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
        .frame(width: 200)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator, lineWidth: 0.5)
        )
        .help(client.details)
        .onTapGesture { isShowingDetails = true }
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            if #available(macOS 13, *) {
                RemoteClientInfoView(client: client)
            }
        }
    }

    @ViewBuilder
    private var iconBackground: some View {
        if client.isConnected && !client.isPaused {
            AnimatedWavesView()
        }
    }
}

struct RemoteLoggerTooglePlayButton: View {
    @ObservedObject var client: RemoteLoggerClient

    var body: some View {
        Button(action: client.togglePlay, label: {
            Image(systemName: client.isPaused ? "play" : "pause")
        }).help(client.isPaused ? "Start Streaming (⇧⌘S)" : "Stop Streaming (⇧⌘S)")
    }
}

private struct AnimatedWavesView: View {
    @State var scale: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(Array(0..<3), id: \.self) { WaveView(index: $0) }
        }
    }
}

private struct WaveView: View {
    let index: Int
    @State var scale: CGFloat = 0

    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 44, height: 44)
            .opacity(scale)
            .animation(Animation.easeInOut(duration: 0.8).delay(1).repeatForever(autoreverses: true), value: scale)
            .scaleEffect(scale)
            .animation(Animation.easeInOut(duration: 1.6).delay(2).repeatForever(autoreverses: false), value: scale)
            .onAppear {
                let delay = index * 300
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                    scale = 1
                }
            }
    }
}

struct Previews_RemoteClientStatusView_Previews: PreviewProvider {
    static var previews: some View {
        RemoteLoggerClientStatusView(client: .mock())
            .frame(width: 220)
    }
}

#endif
