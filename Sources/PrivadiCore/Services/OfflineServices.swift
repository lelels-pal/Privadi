import CryptoKit
import Foundation

public struct DemoPhotoLibraryService: PhotoLibraryServiceProtocol {
    public init() {}

    public func loadAssets(scope: ScanScope) async throws -> [MediaAsset] {
        let assets = SampleData.mediaAssets
        if let limit = scope.assetLimit {
            return Array(assets.prefix(limit))
        }
        return assets
    }

    public func currentAccessLevel() -> PhotoLibraryAccessLevel {
        .demo
    }
}

public struct HeuristicMediaAnalysisEngine: MediaAnalysisEngineProtocol {
    public init() {}

    public func analyze(assets: [MediaAsset]) async -> LibraryAnalysis {
        let duplicateGroups = Dictionary(grouping: assets.filter { $0.checksum != nil }, by: \.checksum!)
            .values
            .filter { $0.count > 1 }
            .map { DuplicateGroup(id: $0[0].checksum ?? UUID().uuidString, assets: $0) }
            .sorted { $0.assets.count > $1.assets.count }

        let similarGroups = Dictionary(grouping: assets.filter { $0.similarityKey != nil }, by: \.similarityKey!)
            .values
            .filter { $0.count > 1 }
            .map { SimilarGroup(id: $0[0].similarityKey ?? UUID().uuidString, assets: $0) }
            .sorted { $0.assets.count > $1.assets.count }

        let lowQualityAssets = assets.filter(\.isLowQualityCandidate)
        let screenshots = assets.filter { $0.kind == .screenshot }
        let sloMoAssets = assets.filter { $0.kind == .sloMo }
        let largeVideoAssets = assets.filter(\.isLargeVideoCandidate)

        return LibraryAnalysis(
            assets: assets,
            duplicateGroups: duplicateGroups,
            similarGroups: similarGroups,
            lowQualityAssets: lowQualityAssets,
            screenshots: screenshots,
            sloMoAssets: sloMoAssets,
            largeVideoAssets: largeVideoAssets
        )
    }
}

public struct SmartCleanPolicy: SmartCleanPolicyProtocol {
    public init() {}

    public func selection(for analysis: LibraryAnalysis) -> SmartCleanSelection {
        let duplicateAssets = analysis.duplicateGroups.flatMap(\.reclaimableAssets)
        let lowRiskSet = Set(duplicateAssets + analysis.lowQualityAssets + analysis.screenshots + analysis.sloMoAssets + analysis.largeVideoAssets)
        let autoSelectedAssets = Array(lowRiskSet).sorted { $0.byteSize > $1.byteSize }
        let reclaimableBytes = autoSelectedAssets.reduce(0) { $0 + $1.byteSize }

        return SmartCleanSelection(
            autoSelectedAssets: autoSelectedAssets,
            reviewSimilarGroups: analysis.similarGroups,
            estimatedReclaimableBytes: reclaimableBytes
        )
    }
}

public struct CompressionEngine: CompressionEngineProtocol {
    public init() {}

    public func estimateSavings(for assets: [MediaAsset]) async -> CompressionEstimate {
        let originalBytes = assets.reduce(Int64(0)) { $0 + $1.byteSize }
        let optimizedBytes = assets.reduce(Int64(0)) { partial, asset in
            let multiplier: Double
            switch asset.kind {
            case .photo, .screenshot:
                multiplier = 0.50
            case .video, .sloMo:
                multiplier = 0.30
            case .livePhoto:
                multiplier = 0.20
            case .burst:
                multiplier = 0.45
            }
            return partial + Int64(Double(asset.byteSize) * multiplier)
        }

        return CompressionEstimate(originalBytes: originalBytes, optimizedBytes: optimizedBytes)
    }
}

public struct ContactsCleanupService: ContactsCleanupServiceProtocol {
    public init() {}

    public func loadContacts(scope: ScanScope) async throws -> [ContactRecord] {
        guard scope.includesContacts else {
            return []
        }

        return SampleData.contacts
    }

    public func mergeSuggestions(from contacts: [ContactRecord]) -> [ContactMergeSuggestion] {
        let grouped = Dictionary(grouping: contacts) { contact in
            contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        return grouped.values.flatMap { matches -> [ContactMergeSuggestion] in
            guard matches.count > 1 else { return [] }
            let ordered = matches.sorted { $0.id < $1.id }
            guard let first = ordered.first else { return [] }
            return ordered.dropFirst().map { ContactMergeSuggestion(primary: first, secondary: $0) }
        }
    }
}

public enum VaultServiceError: Error {
    case invalidPasscode
    case missingRecord
}

public final class FileVaultService: VaultServiceProtocol {
    private let directoryURL: URL
    private var records: [VaultRecord] = []
    private let fileManager: FileManager

    public init(
        directoryURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("PrivadiVault", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func store(_ payload: VaultPayload, passcode: String) throws -> VaultRecord {
        let key = keyMaterial(from: passcode)
        let sealedBox = try AES.GCM.seal(payload.rawData, using: key)
        let combined = sealedBox.combined ?? Data()
        let record = VaultRecord(
            id: UUID(),
            storedAt: .now,
            fileName: "\(UUID().uuidString).vault",
            itemType: payload.itemType
        )

        try combined.write(to: directoryURL.appendingPathComponent(record.fileName), options: .atomic)
        records.append(record)
        return record
    }

    public func unlock(_ record: VaultRecord, passcode: String) throws -> VaultPayload {
        let url = directoryURL.appendingPathComponent(record.fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            throw VaultServiceError.missingRecord
        }

        let data = try Data(contentsOf: url)
        let key = keyMaterial(from: passcode)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return VaultPayload(itemType: record.itemType, rawData: decrypted)
        } catch {
            throw VaultServiceError.invalidPasscode
        }
    }

    public func listRecords() -> [VaultRecord] {
        records.sorted { $0.storedAt > $1.storedAt }
    }

    private func keyMaterial(from passcode: String) -> SymmetricKey {
        let digest = SHA256.hash(data: Data(passcode.utf8))
        return SymmetricKey(data: Data(digest))
    }
}

public struct LocalHashBreachCheckService: BreachCheckServiceProtocol {
    private let hashes: Set<String>

    public init(hashes: Set<String>) {
        self.hashes = hashes
    }

    public init(bundle: Bundle? = nil) {
        let bundle = bundle ?? .module
        if let url = bundle.url(forResource: "breach_hashes", withExtension: "txt"),
           let contents = try? String(contentsOf: url) {
            let loaded = Set(contents
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            self.hashes = loaded
        } else {
            self.hashes = []
        }
    }

    public func check(email: String) -> BreachCheckResult {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = SHA256.hash(data: Data(normalized.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let breached = hashes.contains(hash)
        return BreachCheckResult(email: normalized, isBreached: breached, matchedHashes: breached ? 1 : 0)
    }
}

public final class MockSubscriptionService: SubscriptionServiceProtocol {
    private var state = SubscriptionState(isActive: false, plan: nil, trialEndsAt: nil)

    public init() {}

    public func currentState() async -> SubscriptionState {
        state
    }

    public func startTrial(plan: SubscriptionPlan) async -> SubscriptionState {
        let trialEndsAt = Calendar.current.date(byAdding: .day, value: 14, to: .now)
        state = SubscriptionState(isActive: true, plan: plan, trialEndsAt: trialEndsAt)
        return state
    }
}

public final class AggregateMetricsService: MetricsServiceProtocol {
    private var storedEvents: [AppMetricEvent] = []

    public init() {}

    public func record(_ event: AppMetricEvent) {
        storedEvents.append(event)
    }

    public func events() -> [AppMetricEvent] {
        storedEvents
    }
}
