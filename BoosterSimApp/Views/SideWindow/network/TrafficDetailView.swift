// TrafficDetailView.swift — Full request/response detail with tabbed sections
import SwiftUI

struct TrafficDetailView: View {

    let event: NetworkEvent
    @State private var selectedTab = DetailTab.summary
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            Divider()

            // Tab content
            ScrollView {
                tabContent
                    .padding(Spacing.md)
            }

            // Footer with cURL copy
            footer
        }
        .overlay {
            if showCopiedToast {
                toast
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.label)
                        .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.08) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .summary:  summaryTab
        case .headers:  headersTab
        case .body:     bodyTab
        case .metrics:  metricsTab
        }
    }

    // MARK: - Summary Tab

    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            detailRow("Method", value: event.method.rawValue)
            detailRow("URL", value: event.url, mono: true)

            if let code = event.statusCode {
                detailRow("Status", value: "\(code)", color: statusCodeColor)
            }
            if let duration = event.duration {
                detailRow("Duration", value: String(format: "%.3fs", duration))
            }
            if let errorMessage = event.error {
                detailRow("Error", value: errorMessage, color: .red)
            }

            detailRow("Host", value: event.host, mono: true)
            detailRow("Path", value: event.path, mono: true)
            detailRow("Started", value: event.requestDate.formatted(date: .omitted, time: .standard))

            if let responseDate = event.responseDate {
                detailRow("Completed", value: responseDate.formatted(date: .omitted, time: .standard))
            }
        }
    }

    // MARK: - Headers Tab

    private var headersTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if !event.requestHeaders.isEmpty {
                sectionHeader("Request Headers")
                keyValueTable(event.requestHeaders)
            }

            if let resp = event.responseHeaders, !resp.isEmpty {
                sectionHeader("Response Headers")
                keyValueTable(resp)
            }

            if event.requestHeaders.isEmpty && event.responseHeaders == nil {
                Text("No headers captured")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Body Tab

    private var bodyTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Request Body")
            bodyBlock(event.prettyRequestBody)

            sectionHeader("Response Body")
            bodyBlock(event.prettyResponseBody)
        }
    }

    // MARK: - Metrics Tab

    private var metricsTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let duration = event.duration {
                timingBar(label: "Total", duration: duration, total: duration)

                Text("Detailed timing requires Pulse integration")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, Spacing.xs)
            } else {
                Text("No timing data available")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                CurlExporter.copyToPasteboard(event)
                showCopiedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopiedToast = false
                }
            } label: {
                Label("Copy as cURL", systemImage: "terminal")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Spacer()

            if let code = event.statusCode {
                Text("\(code)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusCodeColor)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Toast

    private var toast: some View {
        Text("Copied!")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.small))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Spacing.lg)
    }

    // MARK: - Helpers

    private var statusCodeColor: Color {
        guard let code = event.statusCode else { return .secondary }
        switch code {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        default:        return .red
        }
    }

    private func detailRow(_ label: String, value: String, mono: Bool = false, color: Color? = nil) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: mono ? .monospaced : .default))
                .foregroundStyle(color ?? .primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func keyValueTable(_ headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }), id: \.key) { key, value in
                HStack(alignment: .top) {
                    Text(key)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(value)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func bodyBlock(_ content: String) -> some View {
        Text(content)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.xs)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private func timingBar(label: String, duration: TimeInterval, total: TimeInterval) -> some View {
        let ratio = total > 0 ? min(duration / total, 1.0) : 0
        return HStack(spacing: Spacing.xs) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: geo.size.width * CGFloat(ratio))
            }
            .frame(height: 8)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 2))
            Text(String(format: "%.0fms", duration * 1000))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Detail Tab

private enum DetailTab: String, CaseIterable {
    case summary, headers, body, metrics

    var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

// MARK: - Preview

#Preview {
    TrafficDetailView(event: NetworkEvent(
        method: .POST,
        url: "https://api.example.com/v1/users",
        statusCode: 201,
        requestHeaders: ["Content-Type": "application/json", "Authorization": "Bearer abc123"],
        responseHeaders: ["Content-Type": "application/json", "X-Request-Id": "req-789"],
        requestBody: "{\"name\":\"John\"}".data(using: .utf8),
        responseBody: "{\"id\":42,\"name\":\"John\"}".data(using: .utf8),
        duration: 0.342
    ))
    .frame(width: SideWindowMetrics.expandedWidth, height: 400)
}
