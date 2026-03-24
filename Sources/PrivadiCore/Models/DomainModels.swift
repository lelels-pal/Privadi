import Foundation

public enum ScanScope: Sendable, Equatable {
    case preview
    case fullLibrary

    public var assetLimit: Int? {
        switch self {
        case .preview:
            30
        case .fullLibrary:
            nil
        }
    }

    public var includesContacts: Bool {
        switch self {
        case .preview:
            false
        case .fullLibrary:
            true
        }
    }
}

public enum PhotoLibraryAccessLevel: Sendable, Equatable {
    case demo
    case limited
    case full
}

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case photo
    case video
    case livePhoto
    case burst
    case screenshot
    case sloMo
}

public struct MediaAsset: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let kind: MediaKind
    public let byteSize: Int64
    public let checksum: String?
    public let similarityKey: String?
    public let qualityScore: Double
    public let eyeClosureScore: Double
    public let width: Int
    public let height: Int
    public let createdAt: Date

    public init(
        id: String,
        name: String,
        kind: MediaKind,
        byteSize: Int64,
        checksum: String? = nil,
        similarityKey: String? = nil,
        qualityScore: Double,
        eyeClosureScore: Double = 0,
        width: Int,
        height: Int,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.byteSize = byteSize
        self.checksum = checksum
        self.similarityKey = similarityKey
        self.qualityScore = qualityScore
        self.eyeClosureScore = eyeClosureScore
        self.width = width
        self.height = height
        self.createdAt = createdAt
    }

    public var isLargeVideoCandidate: Bool {
        (kind == .video || kind == .sloMo || kind == .livePhoto) && byteSize >= 100_000_000
    }

    public var isLowQualityCandidate: Bool {
        qualityScore < 0.45 || eyeClosureScore > 0.75 || width < 1080 || height < 1080
    }
}

public struct DuplicateGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let assets: [MediaAsset]

    public init(id: String, assets: [MediaAsset]) {
        self.id = id
        self.assets = assets
    }

    public var reclaimableAssets: [MediaAsset] {
        Array(assets.sorted(by: { $0.createdAt < $1.createdAt }).dropFirst())
    }
}

public struct SimilarGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let assets: [MediaAsset]

    public init(id: String, assets: [MediaAsset]) {
        self.id = id
        self.assets = assets
    }
}

public struct LibraryAnalysis: Sendable {
    public let assets: [MediaAsset]
    public let duplicateGroups: [DuplicateGroup]
    public let similarGroups: [SimilarGroup]
    public let lowQualityAssets: [MediaAsset]
    public let screenshots: [MediaAsset]
    public let sloMoAssets: [MediaAsset]
    public let largeVideoAssets: [MediaAsset]

    public init(
        assets: [MediaAsset],
        duplicateGroups: [DuplicateGroup],
        similarGroups: [SimilarGroup],
        lowQualityAssets: [MediaAsset],
        screenshots: [MediaAsset],
        sloMoAssets: [MediaAsset],
        largeVideoAssets: [MediaAsset]
    ) {
        self.assets = assets
        self.duplicateGroups = duplicateGroups
        self.similarGroups = similarGroups
        self.lowQualityAssets = lowQualityAssets
        self.screenshots = screenshots
        self.sloMoAssets = sloMoAssets
        self.largeVideoAssets = largeVideoAssets
    }
}

public struct SmartCleanSelection: Sendable {
    public let autoSelectedAssets: [MediaAsset]
    public let reviewSimilarGroups: [SimilarGroup]
    public let estimatedReclaimableBytes: Int64

    public init(
        autoSelectedAssets: [MediaAsset],
        reviewSimilarGroups: [SimilarGroup],
        estimatedReclaimableBytes: Int64
    ) {
        self.autoSelectedAssets = autoSelectedAssets
        self.reviewSimilarGroups = reviewSimilarGroups
        self.estimatedReclaimableBytes = estimatedReclaimableBytes
    }
}

public enum CleanupCategoryKind: String, Codable, Sendable {
    case mediaDelete
    case compressionReview
    case contactReview
}

public struct CleanupReviewCategory: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let kind: CleanupCategoryKind
    public let title: String
    public let metric: String
    public let subtitle: String
    public let icon: String
    public let detailLines: [String]
    public let estimatedBytes: Int64
    public let eligibleAssets: [MediaAsset]
    public let isDestructive: Bool
    public let isSelectable: Bool

    public init(
        id: String,
        kind: CleanupCategoryKind,
        title: String,
        metric: String,
        subtitle: String,
        icon: String,
        detailLines: [String],
        estimatedBytes: Int64,
        eligibleAssets: [MediaAsset],
        isDestructive: Bool,
        isSelectable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.metric = metric
        self.subtitle = subtitle
        self.icon = icon
        self.detailLines = detailLines
        self.estimatedBytes = estimatedBytes
        self.eligibleAssets = eligibleAssets
        self.isDestructive = isDestructive
        self.isSelectable = isSelectable
    }
}

public struct CleanupReviewPlan: Sendable, Equatable {
    public let categories: [CleanupReviewCategory]
    public let selectedCategoryIDs: Set<String>
    public let deleteCandidates: [MediaAsset]
    public let estimatedReclaimableBytes: Int64

    public init(
        categories: [CleanupReviewCategory],
        selectedCategoryIDs: Set<String>,
        deleteCandidates: [MediaAsset],
        estimatedReclaimableBytes: Int64
    ) {
        self.categories = categories
        self.selectedCategoryIDs = selectedCategoryIDs
        self.deleteCandidates = deleteCandidates
        self.estimatedReclaimableBytes = estimatedReclaimableBytes
    }
}

public struct CleanupExecutionFailure: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let assetID: String
    public let assetName: String
    public let reason: String

    public init(assetID: String, assetName: String, reason: String) {
        self.id = assetID
        self.assetID = assetID
        self.assetName = assetName
        self.reason = reason
    }
}

public struct CleanupExecutionResult: Sendable, Equatable {
    public let deletedAssetIDs: [String]
    public let deletedCount: Int
    public let reclaimedBytes: Int64
    public let failures: [CleanupExecutionFailure]

    public init(
        deletedAssetIDs: [String],
        deletedCount: Int,
        reclaimedBytes: Int64,
        failures: [CleanupExecutionFailure]
    ) {
        self.deletedAssetIDs = deletedAssetIDs
        self.deletedCount = deletedCount
        self.reclaimedBytes = reclaimedBytes
        self.failures = failures
    }
}

public struct CompressionEstimate: Sendable {
    public let originalBytes: Int64
    public let optimizedBytes: Int64

    public init(originalBytes: Int64, optimizedBytes: Int64) {
        self.originalBytes = originalBytes
        self.optimizedBytes = optimizedBytes
    }

    public var savingsBytes: Int64 {
        originalBytes - optimizedBytes
    }
}

public struct DashboardSummary: Sendable {
    public let totalItems: Int
    public let reclaimableBytes: Int64
    public let duplicateGroupCount: Int
    public let similarGroupCount: Int
    public let lowQualityCount: Int
    public let largeVideoCount: Int
    public let screenshotCount: Int
    public let sloMoCount: Int
    public let contactSuggestionCount: Int
    public let vaultItemCount: Int

    public init(
        totalItems: Int,
        reclaimableBytes: Int64,
        duplicateGroupCount: Int,
        similarGroupCount: Int,
        lowQualityCount: Int,
        largeVideoCount: Int,
        screenshotCount: Int,
        sloMoCount: Int,
        contactSuggestionCount: Int,
        vaultItemCount: Int
    ) {
        self.totalItems = totalItems
        self.reclaimableBytes = reclaimableBytes
        self.duplicateGroupCount = duplicateGroupCount
        self.similarGroupCount = similarGroupCount
        self.lowQualityCount = lowQualityCount
        self.largeVideoCount = largeVideoCount
        self.screenshotCount = screenshotCount
        self.sloMoCount = sloMoCount
        self.contactSuggestionCount = contactSuggestionCount
        self.vaultItemCount = vaultItemCount
    }
}

public struct ContactRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let fullName: String
    public let email: String?
    public let phoneNumber: String?

    public init(id: String, fullName: String, email: String?, phoneNumber: String?) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
    }

    public var isIncomplete: Bool {
        email == nil || phoneNumber == nil || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct ContactMergeSuggestion: Identifiable, Hashable, Sendable {
    public let id: String
    public let primary: ContactRecord
    public let secondary: ContactRecord

    public init(primary: ContactRecord, secondary: ContactRecord) {
        self.id = "\(primary.id)-\(secondary.id)"
        self.primary = primary
        self.secondary = secondary
    }
}

public enum VaultItemType: String, Codable, Sendable {
    case media
    case contact
}

public struct VaultPayload: Codable, Sendable, Hashable {
    public let itemType: VaultItemType
    public let rawData: Data

    public init(itemType: VaultItemType, rawData: Data) {
        self.itemType = itemType
        self.rawData = rawData
    }
}

public struct VaultRecord: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let storedAt: Date
    public let fileName: String
    public let itemType: VaultItemType

    public init(id: UUID, storedAt: Date, fileName: String, itemType: VaultItemType) {
        self.id = id
        self.storedAt = storedAt
        self.fileName = fileName
        self.itemType = itemType
    }
}

public struct VaultConfigurationState: Codable, Sendable, Hashable {
    public let isConfigured: Bool
    public let biometricsEnabled: Bool
    public let canUseBiometrics: Bool

    public init(isConfigured: Bool, biometricsEnabled: Bool, canUseBiometrics: Bool) {
        self.isConfigured = isConfigured
        self.biometricsEnabled = biometricsEnabled
        self.canUseBiometrics = canUseBiometrics
    }
}

public enum VaultUnlockMethod: Sendable, Hashable {
    case passcode(String)
    case biometrics
}

public struct SubscriptionProduct: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let plan: SubscriptionPlan
    public let displayName: String
    public let displayPrice: String
    public let detailText: String

    public init(
        id: String,
        plan: SubscriptionPlan,
        displayName: String,
        displayPrice: String,
        detailText: String
    ) {
        self.id = id
        self.plan = plan
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.detailText = detailText
    }
}

public enum SubscriptionPlan: String, Codable, CaseIterable, Sendable {
    case annual
    case monthly

    public var displayName: String {
        switch self {
        case .annual:
            "Annual"
        case .monthly:
            "Monthly"
        }
    }

    public var productIdentifier: String {
        switch self {
        case .annual:
            "com.privadi.subscription.annual"
        case .monthly:
            "com.privadi.subscription.monthly"
        }
    }
}

public struct SubscriptionState: Sendable {
    public let isActive: Bool
    public let plan: SubscriptionPlan?
    public let renewalDate: Date?
    public let availableProducts: [SubscriptionProduct]
    public let manageSubscriptionsURL: URL?

    public init(
        isActive: Bool,
        plan: SubscriptionPlan?,
        renewalDate: Date?,
        availableProducts: [SubscriptionProduct] = [],
        manageSubscriptionsURL: URL? = nil
    ) {
        self.isActive = isActive
        self.plan = plan
        self.renewalDate = renewalDate
        self.availableProducts = availableProducts
        self.manageSubscriptionsURL = manageSubscriptionsURL
    }
}

public struct BreachCheckResult: Sendable, Hashable {
    public let email: String
    public let isBreached: Bool
    public let matchedHashes: Int

    public init(email: String, isBreached: Bool, matchedHashes: Int) {
        self.email = email
        self.isBreached = isBreached
        self.matchedHashes = matchedHashes
    }
}

public struct AppMetricEvent: Sendable, Hashable {
    public let name: String
    public let recordedAt: Date

    public init(name: String, recordedAt: Date = .now) {
        self.name = name
        self.recordedAt = recordedAt
    }
}
