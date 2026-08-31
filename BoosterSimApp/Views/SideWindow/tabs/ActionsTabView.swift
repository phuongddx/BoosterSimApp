// ActionsTabView.swift — Actions tab: searchable catalog of sections over the app-action surface
// Section visibility routes through the PURE AppActionCatalog.filter — zero contains-chains
// in the body. Empty query renders every section in the catalog's fixed order (the tab's
// mount order); a query narrows to matching sections; no-match renders an honest empty state.
import SwiftUI

struct ActionsTabView: View {

    let udid: String?
    let deviceName: String
    @State private var query = ""
    @State private var isDeepLinkExpanded = true

    @EnvironmentObject var envOverrideService: EnvironmentOverrideService
    @EnvironmentObject var deepLinkService: DeepLinkService
    @EnvironmentObject var appActionService: AppActionService
    @EnvironmentObject var userDefaultsEditorService: UserDefaultsEditorService

    // MARK: - Search (pure catalog)

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var matchedActions: [AppAction] {
        AppActionCatalog.filter(query: query)
    }

    /// Matched sections in catalog order, deduplicated — stable between queries by contract.
    private var matchedSections: [AppActionSection] {
        var seen: Set<AppActionSection> = []
        return matchedActions.compactMap { action in
            guard !seen.contains(action.section) else { return nil }
            seen.insert(action.section)
            return action.section
        }
    }

    /// Empty query = every section in the catalog's fixed order (nothing lost to the wiring).
    private var visibleSections: [AppActionSection] {
        isFiltering ? matchedSections : AppActionSection.allCases
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxs) {
                ActionSearchBar(query: $query)
                AppPickerBar()

                if isFiltering, matchedSections.isEmpty {
                    noMatchCaption
                } else {
                    if isFiltering {
                        matchedDisclosure
                    }
                    ForEach(visibleSections) { section in
                        sectionView(section)
                    }
                }
            }
        }
        .onAppear { appActionService.refreshApps(udid: udid) }
        .onChange(of: udid) { _, newUDID in
            appActionService.refreshApps(udid: newUDID)
        }
    }

    // MARK: - Sections (the single mount table — catalog order)

    @ViewBuilder
    private func sectionView(_ section: AppActionSection) -> some View {
        switch section {
        case .environment:
            EnvironmentOverridesView(udid: udid)
        case .deepLinks:
            CollapsibleSection(title: "Deep Link Testing", icon: "link", isExpanded: $isDeepLinkExpanded) {
                DeepLinkSectionView(deepLinkService: deepLinkService, udid: udid)
            }
        case .push:
            PushNotificationSectionView(udidProvider: { udid }, deviceNameProvider: { deviceName })
        case .privacy:
            PrivacySectionView(udidProvider: { udid }, deviceNameProvider: { deviceName })
        case .locale:
            LocaleSectionView(udidProvider: { udid })
        case .location:
            LocationSectionView(udidProvider: { udid })
        case .clipboard:
            ClipboardSectionView(udidProvider: { udid })
        case .defaults:
            UserDefaultsEditorView(udidProvider: { udid })
        case .reset:
            AppResetSectionView(udidProvider: { udid }, deviceNameProvider: { deviceName })
        }
    }

    // MARK: - Search Result Disclosures

    /// Small matched-actions disclosure — titles (and count when truncated).
    private var matchedDisclosure: some View {
        let titles = matchedActions.map(\.title)
        let summary = titles.count > 3
            ? "\(titles.count) matching actions — " + titles.prefix(3).joined(separator: ", ") + "…"
            : titles.joined(separator: ", ")
        return Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .truncationMode(.tail)
            .padding(.horizontal, Spacing.md)
    }

    /// Honest no-match state — never a blank tab.
    private var noMatchCaption: some View {
        Text("No actions match “\(query)”. Clear the search to see every section.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.compactRowHeight, alignment: .leading)
    }
}
