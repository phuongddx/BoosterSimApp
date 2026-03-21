// StatusBadge.swift — Visual badge indicating permission/connection status
import SwiftUI

enum BadgeStatus {
    case granted   // Green checkmark
    case needed    // Yellow warning
    case skipped   // Gray minus
}

struct StatusBadge: View {

    let status: BadgeStatus

    private var icon: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .needed:  return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .granted: return .green
        case .needed:  return .yellow
        case .skipped: return .secondary
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundStyle(color)
    }
}
