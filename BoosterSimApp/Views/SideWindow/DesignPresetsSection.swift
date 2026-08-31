// DesignPresetsSection.swift — Preset save/load/delete UI over the versioned DesignOverlayPresets schema
// Extracted verbatim from DesignComparisonView.swift to hold the file-size standard (docs/code-standards).
import SwiftUI

struct DesignPresetsSection: View {

    @ObservedObject var service: DesignOverlayService

    @State private var presetName: String = ""
    @State private var showSavePreset: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Presets", systemImage: "square.grid.2x2")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    showSavePreset = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            if showSavePreset {
                HStack(spacing: 6) {
                    TextField("Preset name", text: $presetName)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        if !presetName.isEmpty {
                            service.savePreset(name: presetName)
                            presetName = ""
                            showSavePreset = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(presetName.isEmpty)
                }
            }

            if service.presets.isEmpty {
                Text("No presets saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(service.presets) { preset in
                    HStack {
                        Button {
                            service.loadPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .font(.caption)
                                Spacer()
                                Text(preset.mode.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            service.deletePreset(preset)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
