// ConnectSetupView.swift — Setup instructions for BoosterSimConnect framework
import SwiftUI

struct ConnectSetupView: View {

    @State private var showCopied = false

    private let codeSnippet = """
    #if DEBUG && targetEnvironment(simulator)
    Bundle(path: "/Applications/BoosterSim.app/Contents/Resources/BoosterSimConnect.framework")?.load()
    #endif
    """

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.xs) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                Text("Connect to Simulator App")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, Spacing.md)

            // Instructions
            VStack(alignment: .leading, spacing: Spacing.sm) {
                stepRow(1, text: "Add this code to your app's entry point:")
                codeBlock
                stepRow(2, text: "Run your app in the Simulator")
                stepRow(3, text: "Network traffic will appear here")
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Step Row

    private func stepRow(_ number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Text("\(number).")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16, alignment: .leading)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Code Block

    private var codeBlock: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Text(codeSnippet)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            // Copy button
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(codeSnippet, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopied = false
                }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(showCopied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.xs)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.leading, Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    ConnectSetupView()
        .frame(width: SideWindowMetrics.expandedWidth)
}
