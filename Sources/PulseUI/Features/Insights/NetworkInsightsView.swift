// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import PulseCore
import SwiftUI

#if swift(>=5.7)
import Charts
#endif

#if os(iOS)

public struct NetworkInsightsView: View {
    @ObservedObject var viewModel: NetworkInsightsViewModel

    private var insights: NetworkLoggerInsights { viewModel.insights }

    public var body: some View {
        List {
            Section(header: Text("Transfer Size")) {
                NetworkInspectorTransferInfoView(viewModel: .init(transferSize: insights.transferSize))
                    .padding(.vertical, 8)
            }
            durationSection
            Section(header: HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Redirects")
            }) {
                HStack {
                    Image(systemName: "arrowshape.zigzag.right")
                    Text("Redirect Count")
                    Spacer()
                    Text("2")
                }
                HStack {
                    Image(systemName: "clock")
                    Text("Total Time Lost")
                    Spacer()
                    Text("2.6s")
                }
                NavigationLink(destination: Text("Request")) {
                    ConsoleNetworkRequestView(viewModel: .init(request: LoggerStore.preview.entity(for: .createAPI), store: .preview))
                }
                NavigationLink(destination: Text("ViewAll")) {
                    Text("View All")
                }
            }
        }
        .listStyle(.automatic)
        .backport.navigationTitle("Insights")
    }

    private var durationSection: some View {
        Section(header: Text("Duration")) {
            HStack {
                Image(systemName: "clock")
                Text("Median Duration")
                Spacer()
                Text(viewModel.medianDuration)
            }
            HStack {
                Image(systemName: "chart.bar")
                Text("Duration Range")
                Spacer()
                Text(viewModel.durationRange)
            }
            durationChart
            NavigationLink(destination: Text("Not implemented")) {
                Text("Show Slowest Requests")
            }
        }
    }

    @ViewBuilder
    private var durationChart: some View {
#if swift(>=5.7)
        if #available(iOS 16.0, *) {
            Chart {
                BarMark(
                    x: .value("Duration", "<100ms"),
                    y: .value("Count", 10)
                ).foregroundStyle(.green)
                BarMark(
                    x: .value("Duration", "<200ms"),
                    y: .value("Count", 20)
                ).foregroundStyle(.green)
                BarMark(
                    x: .value("Duration", "<500ms"),
                    y: .value("Count", 5)
                ).foregroundStyle(.green)
                BarMark(
                    x: .value("Duration", "<1s"),
                    y: .value("Count", 5)
                ).foregroundStyle(.yellow)
                BarMark(
                    x: .value("Duration", "<3s"),
                    y: .value("Count", 5)
                ).foregroundStyle(.orange)
                BarMark(
                    x: .value("Duration", "3+s"),
                    y: .value("Count", 5)
                ).foregroundStyle(.red)
            }
            .padding(.vertical, 8)
            .frame(height: 140)
        }
#endif
    }
}

final class NetworkInsightsViewModel: ObservableObject {
    let insights: NetworkLoggerInsights
    private var cancellables: [AnyCancellable] = []

    var medianDuration: String {
        guard let median = insights.duration.median else { return "–" }
        return DurationFormatter.string(from: median, isPrecise: false)
    }

    var durationRange: String {
        guard let min = insights.duration.minimum,
              let max = insights.duration.maximum else {
            return "–"
        }
        if min == max {
            return DurationFormatter.string(from: min, isPrecise: false)
        }
        return "\(DurationFormatter.string(from: min, isPrecise: false)) – \(DurationFormatter.string(from: max, isPrecise: false))"
    }

    init(store: LoggerStore) {
        self.insights = store.insights
        store.insights.didUpdate.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
}

struct NetworkInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInsightsView(viewModel: .init(store: LoggerStore.mock))
        }
    }
}

#endif
