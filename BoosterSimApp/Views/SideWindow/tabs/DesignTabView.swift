// DesignTabView.swift — Design tab: comparison tools, grid, safe area, ruler, color picker; artboard drop target
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DesignTabView: View {

    @EnvironmentObject var designOverlayService: DesignOverlayService
    @State private var isDesignExpanded = true
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            CollapsibleSection(title: "Design Comparison", icon: "paintbrush", isExpanded: $isDesignExpanded) {
                DesignComparisonView(service: designOverlayService)
            }
        }
        .background(dropHighlight)
        .onDrop(of: [UTType.image], isTargeted: $isDropTargeted) { providers in
            acceptDrop(providers)
        }
    }

    // MARK: - Drop Target

    /// Image-typed drops only: non-image providers return false and set no state (T-04-04 type spoofing).
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data else { return }
            Task { @MainActor in
                guard let image = NSImage(data: data) else { return }
                designOverlayService.accept(image: image)
            }
        }
        return true
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .stroke(Color.accentColor.opacity(isDropTargeted ? 0.6 : 0), lineWidth: 1)
            .padding(Spacing.xxs)
    }
}
