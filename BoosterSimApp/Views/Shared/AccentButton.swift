// AccentButton.swift — Primary CTA button with accent fill and white text
import SwiftUI

struct AccentButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AccentButton(title: "Open System Settings", action: {})
        .padding()
        .frame(width: 280)
}
