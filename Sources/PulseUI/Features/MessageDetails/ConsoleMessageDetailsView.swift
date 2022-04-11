// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(tvOS) || os(watchOS)
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessageDetailsView: View {
    let model: ConsoleMessageDetailsViewModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var isShowingShareSheet = false

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: HStack(spacing: 18) {
                if let badge = model.badge {
                    BadgeView(model: BadgeViewModel(title: badge.title, color: badge.color.opacity(colorScheme == .light ? 0.25 : 0.5)))
                }
                PinButton(model: model.pin, isTextNeeded: false)
                ShareButton {
                    self.isShowingShareSheet = true
                }
            })
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [self.model.prepareForSharing()])
            }
    }
    #elseif os(watchOS)
    var body: some View {
        ScrollView {
            contents
        }.toolbar(content: {
            PinButton(model: model.pin, isTextNeeded: false)
        })
    }
    #elseif os(tvOS)
    var body: some View {
        contents
    }
    #endif

    private var contents: some View {
        VStack {
            tags
            textView
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var textView: some View {
        RichTextView(model: .init(string: model.text))
    }

    #if os(watchOS) || os(tvOS)
    private var tags: some View {
        VStack(alignment: .leading) {
            if let badge = model.badge {
                BadgeView(model: BadgeViewModel(title: badge.title, color: badge.color.opacity(colorScheme == .light ? 0.25 : 0.5)))
            }
            ForEach(model.tags, id: \.title) { tag in
                HStack {
                    Text(tag.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tag.value)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    #else
    private var tags: some View {
        VStack(alignment: .leading) {
            ForEach(model.tags, id: \.title) { tag in
                HStack {
                    Text(tag.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tag.value)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
    }
    #endif
}
#endif
