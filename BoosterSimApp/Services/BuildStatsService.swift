// BuildStatsService.swift — Polls DerivedData LogStoreManifest.plist for Xcode build history
import AppKit
import Combine

@MainActor
final class BuildStatsService: ObservableObject {

    // MARK: - Published State

    @Published var recentBuilds: [BuildRecord] = []
    @Published var isLoading = false

    // MARK: - Private

    private var pollTimer: Timer?
    private var mtimeCache: [URL: Date] = [:]      // manifest URL → last modification date
    private var recordCache: [URL: [BuildRecord]] = [:]  // manifest URL → parsed records

    // MARK: - Public Methods

    func startMonitoring() {
        scanDerivedData()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.scanDerivedData()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Scanning

    private func scanDerivedData() {
        let derivedDataURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard let projects = try? FileManager.default.contentsOfDirectory(
            at: derivedDataURL,
            includingPropertiesForKeys: nil
        ) else { return }

        // Limit to 20 most-recently-modified projects for performance
        let manifests = projects
            .map { $0.appendingPathComponent("Logs/Build/LogStoreManifest.plist") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(20)

        var allRecords: [BuildRecord] = []
        for url in manifests {
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if mtime != mtimeCache[url] {
                mtimeCache[url] = mtime
                let parsed = parseManifest(at: url)
                recordCache[url] = parsed
                allRecords += parsed
            } else {
                allRecords += recordCache[url] ?? []
            }
        }

        recentBuilds = allRecords
            .sorted { $0.startDate > $1.startDate }
            .prefix(30)
            .map { $0 }
    }

    // MARK: - Plist Parsing

    private func parseManifest(at url: URL) -> [BuildRecord] {
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let logs = dict["logs"] as? [String: [String: Any]] else { return [] }

        return logs.compactMap { (key, entry) -> BuildRecord? in
            guard let start = entry["timeStartedRecording"] as? Double,
                  let stop  = entry["timeStoppedRecording"]  as? Double,
                  stop > start else { return nil }

            let scheme    = entry["schemeIdentifier-schemeName"] as? String ?? "Unknown"
            let status    = entry["highLevelStatus"] as? String ?? ""
            let errors    = entry["totalNumberOfErrors"] as? Int ?? 0
            let warnings  = entry["totalNumberOfWarnings"] as? Int ?? 0

            // CoreData epoch: reference date is 2001-01-01
            return BuildRecord(
                id: key,
                schemeName: scheme,
                startDate: Date(timeIntervalSinceReferenceDate: start),
                duration: stop - start,
                succeeded: status == "S",
                errorCount: errors,
                warningCount: warnings
            )
        }
    }
}
