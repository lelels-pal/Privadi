import Foundation

@MainActor
public protocol PhotoLibraryServiceProtocol {
    func loadAssets(scope: ScanScope) async throws -> [MediaAsset]
    func currentAccessLevel() -> PhotoLibraryAccessLevel
}

@MainActor
public protocol MediaAnalysisEngineProtocol {
    func analyze(assets: [MediaAsset]) async -> LibraryAnalysis
}

@MainActor
public protocol SmartCleanPolicyProtocol {
    func selection(for analysis: LibraryAnalysis) -> SmartCleanSelection
}

@MainActor
public protocol CompressionEngineProtocol {
    func estimateSavings(for assets: [MediaAsset]) async -> CompressionEstimate
}

@MainActor
public protocol ContactsCleanupServiceProtocol {
    func loadContacts(scope: ScanScope) async throws -> [ContactRecord]
    func mergeSuggestions(from contacts: [ContactRecord]) -> [ContactMergeSuggestion]
}

@MainActor
public protocol VaultServiceProtocol {
    func store(_ payload: VaultPayload, passcode: String) throws -> VaultRecord
    func unlock(_ record: VaultRecord, passcode: String) throws -> VaultPayload
    func listRecords() -> [VaultRecord]
}

@MainActor
public protocol BreachCheckServiceProtocol {
    func check(email: String) -> BreachCheckResult
}

@MainActor
public protocol SubscriptionServiceProtocol {
    func currentState() async -> SubscriptionState
    func startTrial(plan: SubscriptionPlan) async -> SubscriptionState
}

@MainActor
public protocol MetricsServiceProtocol {
    func record(_ event: AppMetricEvent)
    func events() -> [AppMetricEvent]
}
