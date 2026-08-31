// UserDefaultsEditorView.swift — Actions tab section: typed UserDefaults editor for the active app
// Writes/deletes go ONLY through UserDefaultsEditorService (never a raw defaults client).
// Captions carry key names and types only — values never appear in status text (T-03-10).
import SwiftUI

/// Add-row value kinds (picker surface over the typed wrapper).
enum DefaultsKind: String, CaseIterable, Identifiable {
    case string, int, bool, array, json

    var id: String { rawValue }
}

/// Typed parse failure for raw editor text — inline errors, never a write.
private enum ValueTextError: Error {
    case message(String)

    var text: String {
        if case .message(let value) = self { return value }
        return "The value is not valid for this type."
    }
}

struct UserDefaultsEditorView: View {

    let udidProvider: () -> String?

    @EnvironmentObject var appActionService: AppActionService
    @EnvironmentObject var editorService: UserDefaultsEditorService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isExpanded = false
    @State private var keyFilter = ""
    @State private var editingKey: String?
    @State private var editValueText = ""
    @State private var editError: String?
    @State private var newKey = ""
    @State private var newKind: DefaultsKind = .string
    @State private var newValueText = ""
    @State private var addError: String?

    private var activeUDID: String? { udidProvider() }
    private var activeBundleID: String? { appActionService.activeBundleID }
    private var isDisabled: Bool { activeUDID == nil || activeBundleID == nil }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }
    private var trimmedFilter: String { keyFilter.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filteredEntries: [DefaultsEntry] {
        guard !trimmedFilter.isEmpty else { return editorService.entries }
        let needle = trimmedFilter.lowercased()
        return editorService.entries.filter { $0.key.lowercased().contains(needle) }
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Defaults", icon: "gearshape", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if isDisabled {
                    helperBanner("No active Simulator or app — pick an app above to edit its defaults.")
                        .padding(.top, Spacing.sm)
                } else {
                    domainRow.padding(.horizontal, Spacing.md)
                    filterRow.padding(.horizontal, Spacing.md)
                    statusCaption.padding(.horizontal, Spacing.md)
                    entriesList
                    addRow.padding(.horizontal, Spacing.md)
                }
                cfprefsdCaption
                relaunchCaption
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: editorService.entries)
            .animation(animation, value: editorService.operation)
        }
        .onAppear { reload() }
        .onChange(of: activeUDID) { _, _ in reload() }
        .onChange(of: appActionService.activeBundleID) { _, _ in reload() }
    }

    // MARK: - Domain & Reload

    private var domainRow: some View {
        HStack(spacing: Spacing.xs) {
            Text(activeBundleID ?? "—")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: reload) {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(editorService.operation.isWorking)
            .accessibilityLabel("Reload defaults keys")
        }
    }

    // MARK: - Key Filter

    private var filterRow: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            TextField("Filter keys...", text: $keyFilter)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
            if !keyFilter.isEmpty {
                Button {
                    keyFilter = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear the key filter")
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Entries

    @ViewBuilder
    private var entriesList: some View {
        if editorService.entries.isEmpty {
            emptyCaption
        } else if filteredEntries.isEmpty {
            noMatchCaption
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filteredEntries) { entry in
                    if editingKey == entry.key {
                        editRow(entry)
                    } else {
                        entryRow(entry)
                    }
                }
            }
        }
    }

    /// BlockRulesView row anatomy: key + typed capsule + edit/delete with a11y labels.
    /// The capsule carries the value KIND — never the value itself.
    private func entryRow(_ entry: DefaultsEntry) -> some View {
        let editable = isEditable(entry)
        return HStack(spacing: Spacing.sm) {
            Text(entry.key)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(entry.typeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Spacer()

            Button {
                beginEdit(entry)
            } label: {
                Image(systemName: "pencil")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!editable)
            .accessibilityLabel("Edit key \(entry.key)")
            .accessibilityHint(editable ? "" : "Complex JSON or binary values cannot be edited inline")

            Button {
                deleteKey(entry)
            } label: {
                Image(systemName: "trash")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete key \(entry.key)")
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight)
    }

    /// Inline edit row for one entry — writes only through the service on commit.
    private func editRow(_ entry: DefaultsEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(entry.key)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.typeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                Spacer()
            }
            HStack(spacing: Spacing.xs) {
                TextField(valuePlaceholder(newKind(of: entry)), text: $editValueText)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commitEdit)
                Button(action: commitEdit) {
                    Image(systemName: "checkmark")
                        .imageScale(.small)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save the value for \(entry.key)")
                Button(action: cancelEdit) {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel editing \(entry.key)")
            }
            if let editError {
                inlineError(editError)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Add Row

    /// Adding a key requires choosing a type (typed wrapper discipline).
    private var addRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("new.key.name", text: $newKey)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit(addEntry)

            HStack(spacing: Spacing.xs) {
                Picker("Type", selection: $newKind) {
                    ForEach(DefaultsKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: Spacing.xxl * 4)
                .accessibilityLabel("Value type for the new key")

                TextField(valuePlaceholder(newKind), text: $newValueText)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addEntry)

                Button(action: addEntry) {
                    Image(systemName: "plus")
                        .imageScale(.small)
                        .foregroundStyle(canAdd ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add defaults key")
            }
            if let addError {
                inlineError(addError)
            }
        }
    }

    private var canAdd: Bool {
        let key = newKey.trimmingCharacters(in: .whitespaces)
        return !isDisabled
            && !key.isEmpty
            && !newValueText.trimmingCharacters(in: .whitespaces).isEmpty
            && UserDefaultsEditorService.isValidName(key)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusCaption: some View {
        if let loadError = editorService.loadError {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(loadError)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
        if let editedKey = editorService.lastEditedKey {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text("Updated key \(editedKey).")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
        if case .error(let message) = editorService.operation {
            inlineError(message)
        }
    }

    // MARK: - Honest Captions (must-have truth 4)

    private var cfprefsdCaption: some View {
        Text("Writes land via cfprefsd — the plist updates immediately and the list reloads with the new value.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
    }

    private var relaunchCaption: some View {
        Text("Keys read at launch time (locale, feature flags) need an app relaunch to take effect.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
    }

    private var emptyCaption: some View {
        Text("No defaults keys for this app yet — add one below.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
    }

    private var noMatchCaption: some View {
        Text("No keys match “\(trimmedFilter)”.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
    }

    // MARK: - Helpers

    private func reload() {
        guard let udid = activeUDID, let bundle = activeBundleID else { return }
        cancelEdit()
        editorService.loadDomain(udid: udid, bundle: bundle)
    }

    private func newKind(of entry: DefaultsEntry) -> DefaultsKind {
        switch entry.value {
        case .string: return .string
        case .int:    return .int
        case .bool:   return .bool
        case .array:  return .array
        case .json:   return .json
        }
    }

    /// json capsules are binary plists — inline text editing would corrupt them (honest limitation).
    private func isEditable(_ entry: DefaultsEntry) -> Bool {
        if case .json = entry.value { return false }
        return true
    }

    private func valuePlaceholder(_ kind: DefaultsKind) -> String {
        switch kind {
        case .string: return "text value"
        case .int:    return "42"
        case .bool:   return "YES or NO"
        case .array:  return "a, b, c"
        case .json:   return "raw JSON text"
        }
    }

    private func displayText(of value: DefaultsEntryValue) -> String {
        switch value {
        case .string(let text):   return text
        case .int(let number):    return String(number)
        case .bool(let flag):     return flag ? "YES" : "NO"
        case .array(let items):   return items.joined(separator: ", ")
        case .json(let payload):  return String(data: payload, encoding: .utf8) ?? ""
        }
    }

    /// Typed raw-text parse per kind — invalid input is an inline error, never a write.
    private func parseValue(kind: DefaultsKind, raw: String) -> Result<DefaultsEntryValue, ValueTextError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .string:
            return .success(.string(raw))
        case .int:
            guard let number = Int(trimmed) else { return .failure(.message("Enter a whole number, e.g. 42.")) }
            return .success(.int(number))
        case .bool:
            switch trimmed.lowercased() {
            case "yes", "true", "1": return .success(.bool(true))
            case "no", "false", "0": return .success(.bool(false))
            default:                 return .failure(.message("Enter YES or NO."))
            }
        case .array:
            let items = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return .success(.array(items))
        case .json:
            return .success(.json(Data(raw.utf8)))
        }
    }

    private func beginEdit(_ entry: DefaultsEntry) {
        editingKey = entry.key
        editValueText = displayText(of: entry.value)
        editError = nil
    }

    private func cancelEdit() {
        editingKey = nil
        editValueText = ""
        editError = nil
    }

    private func commitEdit() {
        guard let key = editingKey,
              let original = editorService.entries.first(where: { $0.key == key }),
              let udid = activeUDID,
              let bundle = activeBundleID else { return }
        switch parseValue(kind: newKind(of: original), raw: editValueText) {
        case .failure(let error):
            editError = error.text
        case .success(let value):
            editError = nil
            editingKey = nil
            editorService.write(entry: DefaultsEntry(key: key, value: value), udid: udid, bundle: bundle)
        }
    }

    private func deleteKey(_ entry: DefaultsEntry) {
        guard let udid = activeUDID, let bundle = activeBundleID else { return }
        if editingKey == entry.key { cancelEdit() }
        editorService.delete(key: entry.key, udid: udid, bundle: bundle)
    }

    private func addEntry() {
        guard let udid = activeUDID, let bundle = activeBundleID else { return }
        let key = newKey.trimmingCharacters(in: .whitespaces)
        guard UserDefaultsEditorService.isValidName(key) else {
            addError = DefaultsEditorError.invalidKey.message
            return
        }
        switch parseValue(kind: newKind, raw: newValueText) {
        case .failure(let error):
            addError = error.text
        case .success(let value):
            addError = nil
            newKey = ""
            newValueText = ""
            editorService.write(entry: DefaultsEntry(key: key, value: value), udid: udid, bundle: bundle)
        }
    }

    private func helperBanner(_ text: String, icon: String = "exclamationmark.circle") -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
            Text(text).font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Spacing.xs)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Preview

#Preview {
    let simCtl = SimCtlService()
    let appActionService = AppActionService(
        simCtl: simCtl, certificateService: CertificateService(simCtl: simCtl))
    appActionService.activeBundleID = "com.example.app"
    return UserDefaultsEditorView(udidProvider: { "UDID-1" })
        .environmentObject(appActionService)
        .environmentObject(UserDefaultsEditorService(simCtl: simCtl))
        .frame(width: SideWindowMetrics.expandedWidth)
}
