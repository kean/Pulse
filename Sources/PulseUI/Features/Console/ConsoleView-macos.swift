//// The MIT License (MIT)
////
//// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).
//
//#if os(macOS)
//
//import SwiftUI
//import CoreData
//import Pulse
//import Combine
//
//public struct ConsoleView: View {
//    @StateObject private var environment: ConsoleEnvironment
//
//    init(environment: ConsoleEnvironment) {
//        _environment = StateObject(wrappedValue: environment)
//    }
//
//    public var body: some View {
//        if #available(macOS 13, *) {
//            _ConsoleView(environment: environment)
//        } else {
//            PlaceholderView(imageName: "xmark.octagon", title: "Unsupported", subtitle: "Pulse requires macOS 13 or later").padding()
//        }
//    }
//}
//
//@available(macOS 13, *)
//private struct _ConsoleView: View {
//    @StateObject private var environment: ConsoleEnvironment
//    @State private var columnVisibility = NavigationSplitViewVisibility.all
//
//    init(environment: ConsoleEnvironment) {
//        _environment = StateObject(wrappedValue: environment)
//    }
//
//    public var body: some View {
//        NavigationStack {
//            ConsoleMainView(environment: environment)
//                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 640)
//        }
//        .injecting(environment)
//        .navigationTitle("")
//    }
//}
//
///// This view contains the console itself along with the details (no sidebar).
//@available(macOS 13, *)
//@MainActor
//private struct ConsoleMainView: View {
//    let environment: ConsoleEnvironment
//
//    @State private var isSharingStore = false
//    @State private var isShowingFilters = false
//
//    @EnvironmentObject var router: ConsoleRouter
//
//    var body: some View {
//        ConsoleListView()
//            .frame(minWidth: 300, idealWidth: 500, minHeight: 120, idealHeight: 480)
//            .toolbar {
//                ToolbarItemGroup(placement: .automatic) {
//                    Button(action: { isSharingStore = true }) {
//                        Image(systemName: "square.and.arrow.up")
//                    }
//                    .help("Share a session")
//                    .popover(isPresented: $isSharingStore, arrowEdge: .bottom) {
//                        ShareStoreView(onDismiss: {})
//                            .frame(width: 240).fixedSize()
//                    }
//
//                    Button(action: { isShowingFilters = true }) {
//                        Label("Show Filters", systemImage: "line.3.horizontal.decrease.circle")
//                    }
//                    .help("Show Filters")
//                    .popover(isPresented: $isShowingFilters) {
//                        ConsoleFiltersView().frame(width: 300).fixedSize()
//                    }
//
//
//            }
//    }
//}
//
//#if DEBUG
//struct ConsoleView_Previews: PreviewProvider {
//    static var previews: some View {
//        ConsoleView(store: .mock)
//            .previewLayout(.fixed(width: 700, height: 400))
//    }
//}
//#endif
//#endif
