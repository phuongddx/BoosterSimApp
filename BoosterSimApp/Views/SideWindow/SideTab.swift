// SideTab.swift — Tab enum for side window navigation
import SwiftUI

enum SideTab: String, CaseIterable {
    case capture
    case design
    case actions
    case network

    var icon: String {
        switch self {
        case .capture: return "camera"
        case .design:  return "paintbrush"
        case .actions: return "bolt"
        case .network: return "network"
        }
    }

    var label: String {
        switch self {
        case .capture: return "Capture"
        case .design:  return "Design"
        case .actions: return "Actions"
        case .network: return "Network"
        }
    }
}
