// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation
import Combine
import Pulse
import SwiftUI
import CoreData
import Charts

struct InsightsView: View {
    @ObservedObject var viewModel: InsightsViewModel

    private var insights: NetworkLoggerInsights { viewModel.insights }

    var body: some View {
        Form {
            contents
        }
#if os(iOS)
        .navigationTitle("Insights")
#endif
        .onAppear { viewModel.isViewVisible = true }
        .onDisappear { viewModel.isViewVisible = false }
    }

    @ViewBuilder
    private var contents: some View {
        ConsoleSection(isDividerHidden: true, header: { SectionHeaderView(title: "Transfer Size") }) {
            NetworkInspectorTransferInfoView(viewModel: .init(transferSize: insights.transferSize))
                .padding(.vertical, 8)
        }
        durationSection
        if insights.failures.count > 0 {
            failuresSection
        }
        redirectsSection
    }

    // MARK: - Duration

    private var durationSection: some View {
        ConsoleSection(header: { SectionHeaderView(title: "Duration") }) {
            InfoRow(title: "Median Duration", details: viewModel.medianDuration)
            InfoRow(title: "Duration Range", details: viewModel.durationRange)
            durationChart
            NavigationLink(destination: TopSlowestRequestsViw(viewModel: viewModel)) {
                Text("Show Slowest Requests")
            }.disabled(insights.duration.topSlowestRequests.isEmpty)
        }
    }

    @ViewBuilder
    private var durationChart: some View {
        if #available(iOS 16, macOS 13, *) {
            if insights.duration.values.isEmpty {
                Text("No network requests yet")
                    .foregroundColor(.secondary)
                    .frame(height: 140)
            } else {
                Chart(viewModel.durationBars) {
                    BarMark(
                        x: .value("Duration", $0.range),
                        y: .value("Count", $0.count)
                    ).foregroundStyle(barMarkColor(for: $0.range.lowerBound))
                }
                .chartXScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 8)) { value in
                        AxisValueLabel() {
                            if let value = value.as(TimeInterval.self) {
                                Text(DurationFormatter.string(from: TimeInterval(value), isPrecise: false))
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(height: 140)
            }
        }
    }

    private func barMarkColor(for duration: TimeInterval) -> Color {
        if duration < 1.0 {
            return Color.green
        } else if duration < 1.9 {
            return Color.yellow
        } else {
            return Color.red
        }
    }

    // MARK: - Redirects

    @ViewBuilder
    private var redirectsSection: some View {
        ConsoleSection(header: {
            SectionHeaderView(systemImage: "exclamationmark.triangle.fill", title: "Redirects")
        }) {
            InfoRow(title: "Redirect Count", details: "\(insights.redirects.count)")
            InfoRow(title: "Total Time Lost", details: DurationFormatter.string(from: insights.redirects.timeLost, isPrecise: false))
            NavigationLink(destination: RequestsWithRedirectsView(viewModel: viewModel)) {
                Text("Show Requests with Redirects")
            }.disabled(insights.duration.topSlowestRequests.isEmpty)
        }
    }

    // MARK: - Failures

    @ViewBuilder
    private var failuresSection: some View {
        ConsoleSection(header: {
            SectionHeaderView(systemImage: "xmark.octagon.fill", title: "Failures")
        }) {
            NavigationLink(destination: FailingRequestsListView(viewModel: viewModel)) {
                HStack {
                    Text("Failed Requests")
                    Spacer()
                    Text("\(insights.failures.count)")
                        .foregroundColor(.secondary)
                }
            }.disabled(insights.duration.topSlowestRequests.isEmpty)
        }
    }
}

private struct TopSlowestRequestsViw: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ConsolePlainList( viewModel.topSlowestRequests())
            .inlineNavigationTitle("Slowest Requests")
    }
}

private struct RequestsWithRedirectsView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ConsolePlainList( viewModel.requestsWithRedirects())
            .inlineNavigationTitle("Redirects")
    }
}

private struct FailingRequestsListView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ConsolePlainList( viewModel.failedRequests())
            .inlineNavigationTitle("Failed Requests")
    }
}

#if DEBUG
struct NetworkInsightsView_Previews: PreviewProvider {
    static var previews: some View {
            InsightsView(viewModel: .init(store: .mock, context: .init(), criteria: .init(criteria: .init(), index: .init(store: .mock))))
#if os(macOS)
                .frame(width: 320, height: 800)
#endif
    }
}
#endif

#endif
