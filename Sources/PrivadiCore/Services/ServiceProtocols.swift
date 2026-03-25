import Foundation

public protocol MediaFingerprintingServiceProtocol: Sendable {
    func cachedFingerprint(for key: String) async -> String?
    func storeFingerprint(_ fingerprint: String, for key: String) async
}

public protocol PhotoLibraryServiceProtocol: Sendable {
    func loadAssets(scope: ScanScope) async throws -> [MediaAsset]
    func currentAccessLevel() -> PhotoLibraryAccessLevel
}

public protocol MediaAnalysisEngineProtocol: Sendable {
    func analyze(assets: [MediaAsset]) async -> LibraryAnalysis
}

public protocol SmartCleanPolicyProtocol: Sendable {
    func selection(for analysis: LibraryAnalysis) -> SmartCleanSelection
}

public protocol CompressionEngineProtocol: Sendable {
    func estimateSavings(for assets: [MediaAsset]) async -> CompressionEstimate
}

public protocol ContactsCleanupServiceProtocol: Sendable {
    func loadContacts(scope: ScanScope) async throws -> [ContactRecord]
    func mergeSuggestions(from contacts: [ContactRecord]) -> [ContactMergeSuggestion]
}

@MainActor
public protocol VaultServiceProtocol {
    func configurationState() -> VaultConfigurationState
    func configure(passcode: String, enableBiometrics: Bool) throws -> VaultConfigurationState
    func store(_ payload: VaultPayload) throws -> VaultRecord
    func unlockVault(method: VaultUnlockMethod) async throws
    func unlock(_ record: VaultRecord, method: VaultUnlockMethod) async throws -> VaultPayload
    func listRecords() -> [VaultRecord]
}

@MainActor
public protocol BreachCheckServiceProtocol {
    func check(email: String) -> BreachCheckResult
    func datasetMetadata() -> BreachDatasetMetadata
}

@MainActor
public protocol SubscriptionServiceProtocol {
    func currentState() async -> SubscriptionState
    func refreshEntitlements() async -> SubscriptionState
    func loadProducts() async throws -> [SubscriptionProduct]
    func purchase(plan: SubscriptionPlan) async throws -> SubscriptionState
    func restorePurchases() async throws -> SubscriptionState
}

@MainActor
public protocol CleanupExecutionServiceProtocol {
    func executeDelete(for assets: [MediaAsset]) async throws -> CleanupExecutionResult
}

@MainActor
public protocol MetricsServiceProtocol {
    func record(_ event: AppMetricEvent)
    func events() -> [AppMetricEvent]
}
