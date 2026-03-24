import Foundation
import Testing
@testable import PrivadiCore

@MainActor
@Test
func smartCleanAutoSelectsOnlyLowRiskAssets() async {
    let engine = HeuristicMediaAnalysisEngine()
    let analysis = await engine.analyze(assets: SampleData.mediaAssets)
    let selection = SmartCleanPolicy().selection(for: analysis)

    #expect(selection.autoSelectedAssets.contains { $0.kind == .screenshot })
    #expect(selection.autoSelectedAssets.contains { $0.kind == .sloMo })
    #expect(selection.autoSelectedAssets.contains { $0.checksum == "dup-a" })
    #expect(selection.reviewSimilarGroups.count > 0)
}

@MainActor
@Test
func breachCheckMatchesLocalHashIndex() {
    let service = LocalHashBreachCheckService(hashes: [
        "0bb1a6de76c5af97d45ca3d5e4af75b3f8bb32b20f550ebb293af06e0929bdc6"
    ])

    let breached = service.check(email: "compromised@example.com")
    let safe = service.check(email: "clean@example.com")

    #expect(breached.isBreached)
    #expect(!safe.isBreached)
}

@MainActor
@Test
func vaultConfigurationPersistsAndUnlocksPayloads() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let keychainService = "com.privadi.tests.\(UUID().uuidString)"
    let payload = VaultPayload(itemType: .contact, rawData: Data("secret".utf8))

    let firstService = FileVaultService(directoryURL: tempDir, keychainService: keychainService)
    do {
        _ = try firstService.configure(passcode: "1234", enableBiometrics: false)
    } catch VaultServiceError.keychainUnavailable {
        return
    }
    let record = try firstService.store(payload)

    let secondService = FileVaultService(directoryURL: tempDir, keychainService: keychainService)
    let opened = try await secondService.unlock(record, method: .passcode("1234"))

    #expect(secondService.configurationState().isConfigured)
    #expect(opened.rawData == payload.rawData)
    #expect(secondService.listRecords().count == 1)
}

@MainActor
@Test
func configuredVaultRequiresUnlockBeforeSavingAfterRelaunch() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let keychainService = "com.privadi.tests.\(UUID().uuidString)"

    let firstService = FileVaultService(directoryURL: tempDir, keychainService: keychainService)
    do {
        _ = try firstService.configure(passcode: "1234", enableBiometrics: false)
    } catch VaultServiceError.keychainUnavailable {
        return
    }

    let relaunchedService = FileVaultService(directoryURL: tempDir, keychainService: keychainService)
    let environment = makeEnvironment(vaultService: relaunchedService)
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    #expect(viewModel.vaultAccessState == .locked)
    #expect(viewModel.vaultRecords.isEmpty)

    viewModel.saveSampleToConfiguredVault()
    #expect(viewModel.vaultAccessState == .locked)
    #expect(viewModel.vaultRecords.isEmpty)
    #expect(viewModel.statusText.contains("Unlock your vault"))

    await viewModel.unlockVault(passcode: "1234")
    #expect(viewModel.vaultAccessState == .unlocked)

    viewModel.saveSampleToConfiguredVault()
    #expect(viewModel.vaultAccessState == .unlocked)
    #expect(viewModel.vaultRecords.count == 1)
}

@MainActor
@Test
func limitedPreviewLoadsDashboardWithoutActivatingSubscription() async {
    let viewModel = AppViewModel(environment: .livePreview())

    await viewModel.startLimitedPreviewFlow()

    #expect(viewModel.stage == .dashboard)
    #expect(viewModel.experienceMode == .limitedPreview)
    #expect(!viewModel.subscriptionState.isActive)
    #expect(viewModel.summary != nil)
}

@MainActor
@Test
func previewModeDoesNotOpenDestructiveCleanupReview() async {
    let viewModel = AppViewModel(environment: .livePreview())

    await viewModel.startLimitedPreviewFlow()
    viewModel.reviewCleanupPlan()

    #expect(viewModel.cleanupReviewPlan == nil)
    #expect(viewModel.cleanupExecutionPhase == .idle)
}

@MainActor
@Test
func cleanupReviewPlanUsesOnlyMediaDeleteCandidates() async {
    let environment = makeEnvironment(subscriptionService: FakeSubscriptionService(activePlan: .annual))
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()
    viewModel.reviewCleanupPlan()

    let deleteCandidateIDs = Set(viewModel.cleanupReviewPlan?.deleteCandidates.map(\.id) ?? [])
    let expectedIDs = Set(viewModel.selection?.autoSelectedAssets.map(\.id) ?? [])

    #expect(viewModel.stage == .dashboard)
    #expect(!deleteCandidateIDs.isEmpty)
    #expect(deleteCandidateIDs == expectedIDs)
}

@MainActor
@Test
func activeEntitlementSkipsPaywallAndLoadsDashboard() async {
    let environment = makeEnvironment(subscriptionService: FakeSubscriptionService(activePlan: .annual))
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()

    #expect(viewModel.subscriptionState.isActive)
    #expect(viewModel.stage == .dashboard)
    #expect(viewModel.experienceMode == .live)
}

@MainActor
@Test
func restorePurchasesActivatesDashboardFlow() async {
    let subscriptionService = FakeSubscriptionService(activePlan: nil, restorePlan: .monthly)
    let environment = makeEnvironment(subscriptionService: subscriptionService)
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()
    #expect(viewModel.stage == .paywall)

    viewModel.restorePurchases()
    await settleAsyncFlow()

    #expect(viewModel.subscriptionState.isActive)
    #expect(viewModel.subscriptionState.plan == .monthly)
    #expect(viewModel.stage == .dashboard)
}

@MainActor
@Test
func purchaseFailureDuringLiveScanReturnsSubscribedUserToPermissions() async {
    let photoLibraryService = ScriptedPhotoLibraryService(
        fullLibraryResponses: [.failure(.photoAccessRequired)]
    )
    let environment = makeEnvironment(
        photoLibraryService: photoLibraryService,
        subscriptionService: FakeSubscriptionService(activePlan: nil)
    )
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()
    #expect(viewModel.stage == .paywall)

    viewModel.startAnnualTrial()
    await settleAsyncFlow()

    #expect(viewModel.subscriptionState.isActive)
    #expect(viewModel.subscriptionState.plan == .annual)
    #expect(viewModel.stage == .permissions)
    #expect(viewModel.statusText.contains("Photo Library access is required"))
}

@MainActor
@Test
func restoreFailureDuringLiveScanReturnsSubscribedUserToPermissions() async {
    let photoLibraryService = ScriptedPhotoLibraryService(
        fullLibraryResponses: [.failure(.emptyPhotoLibrary)]
    )
    let environment = makeEnvironment(
        photoLibraryService: photoLibraryService,
        subscriptionService: FakeSubscriptionService(activePlan: nil, restorePlan: .monthly)
    )
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()
    #expect(viewModel.stage == .paywall)

    viewModel.restorePurchases()
    await settleAsyncFlow()

    #expect(viewModel.subscriptionState.isActive)
    #expect(viewModel.subscriptionState.plan == .monthly)
    #expect(viewModel.stage == .permissions)
    #expect(viewModel.statusText.contains("could not find any photos or videos"))
}

@MainActor
@Test
func cleanupCompletionSurvivesRefreshFailure() async {
    let photoLibraryService = ScriptedPhotoLibraryService(
        fullLibraryResponses: [
            .success(SampleData.mediaAssets),
            .failure(.photoAccessRequired),
        ]
    )
    let environment = makeEnvironment(
        photoLibraryService: photoLibraryService,
        subscriptionService: FakeSubscriptionService(activePlan: .annual),
        cleanupExecutionService: FakeCleanupExecutionService()
    )
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()
    viewModel.reviewCleanupPlan()
    let expectedDeletedCount = viewModel.cleanupReviewPlan?.deleteCandidates.count ?? 0

    viewModel.executeCleanupPlan()
    await settleAsyncFlow()

    switch viewModel.cleanupExecutionPhase {
    case .completed(let result):
        #expect(result.deletedCount == expectedDeletedCount)
    default:
        Issue.record("Expected cleanup execution to remain completed after refresh failure.")
    }
    #expect(viewModel.statusText.contains("could not refresh the library"))
}

@MainActor
@Test
func cleanupDeletionOfLastItemsBuildsEmptyDashboardState() async {
    let photoLibraryService = ScriptedPhotoLibraryService(
        fullLibraryResponses: [
            .success(SampleData.mediaAssets),
            .failure(.emptyPhotoLibrary),
        ]
    )
    let environment = makeEnvironment(
        photoLibraryService: photoLibraryService,
        subscriptionService: FakeSubscriptionService(activePlan: .annual),
        cleanupExecutionService: FakeCleanupExecutionService()
    )
    let viewModel = AppViewModel(environment: environment)

    await viewModel.bootstrap()
    viewModel.continueFromPrivacy()
    viewModel.continueFromPermissions()
    await settleAsyncFlow()
    viewModel.reviewCleanupPlan()

    viewModel.executeCleanupPlan()
    await settleAsyncFlow()

    switch viewModel.cleanupExecutionPhase {
    case .completed:
        break
    default:
        Issue.record("Expected cleanup execution to remain completed when the library becomes empty.")
    }
    #expect(viewModel.stage == .dashboard)
    #expect(viewModel.summary?.totalItems == 0)
    #expect(viewModel.summary?.reclaimableBytes == 0)
    #expect(viewModel.statusText.contains("could not refresh the library"))
}

@MainActor
private func makeEnvironment(
    photoLibraryService: PhotoLibraryServiceProtocol = DemoPhotoLibraryService(),
    subscriptionService: SubscriptionServiceProtocol = FakeSubscriptionService(activePlan: nil),
    cleanupExecutionService: CleanupExecutionServiceProtocol = PreviewCleanupExecutionService(),
    vaultService: VaultServiceProtocol? = nil
) -> AppEnvironment {
    let resolvedVaultService: VaultServiceProtocol
    if let vaultService {
        resolvedVaultService = vaultService
    } else {
        let keychainService = "com.privadi.tests.\(UUID().uuidString)"
        let vaultDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        resolvedVaultService = FileVaultService(directoryURL: vaultDirectory, keychainService: keychainService)
    }

    return AppEnvironment(
        photoLibraryService: photoLibraryService,
        mediaAnalysisEngine: HeuristicMediaAnalysisEngine(),
        smartCleanPolicy: SmartCleanPolicy(),
        compressionEngine: CompressionEngine(),
        contactsCleanupService: ContactsCleanupService(),
        vaultService: resolvedVaultService,
        breachCheckService: LocalHashBreachCheckService(),
        subscriptionService: subscriptionService,
        cleanupExecutionService: cleanupExecutionService,
        metricsService: AggregateMetricsService()
    )
}

private func settleAsyncFlow() async {
    try? await Task.sleep(for: .milliseconds(120))
}

@MainActor
private final class FakeSubscriptionService: SubscriptionServiceProtocol {
    private let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")
    private let restorePlan: SubscriptionPlan?
    private var activePlan: SubscriptionPlan?
    private let products = SubscriptionPlan.allCases.map { plan in
        SubscriptionProduct(
            id: plan.productIdentifier,
            plan: plan,
            displayName: plan.displayName,
            displayPrice: plan == .annual ? "$39.99/year" : "$8.99/month",
            detailText: "Loaded for tests"
        )
    }

    init(activePlan: SubscriptionPlan?, restorePlan: SubscriptionPlan? = nil) {
        self.activePlan = activePlan
        self.restorePlan = restorePlan
    }

    func currentState() async -> SubscriptionState {
        state()
    }

    func refreshEntitlements() async -> SubscriptionState {
        state()
    }

    func loadProducts() async throws -> [SubscriptionProduct] {
        products
    }

    func purchase(plan: SubscriptionPlan) async throws -> SubscriptionState {
        activePlan = plan
        return state()
    }

    func restorePurchases() async throws -> SubscriptionState {
        activePlan = restorePlan
        return state()
    }

    private func state() -> SubscriptionState {
        SubscriptionState(
            isActive: activePlan != nil,
            plan: activePlan,
            renewalDate: nil,
            availableProducts: products,
            manageSubscriptionsURL: manageURL
        )
    }
}

@MainActor
private final class ScriptedPhotoLibraryService: PhotoLibraryServiceProtocol {
    enum Response {
        case success([MediaAsset])
        case failure(DeviceDataAccessError)
    }

    private var previewResponses: [Response]
    private var fullLibraryResponses: [Response]
    private let accessLevel: PhotoLibraryAccessLevel

    init(
        previewResponses: [Response] = [.success(Array(SampleData.mediaAssets.prefix(30)))],
        fullLibraryResponses: [Response],
        accessLevel: PhotoLibraryAccessLevel = .full
    ) {
        self.previewResponses = previewResponses
        self.fullLibraryResponses = fullLibraryResponses
        self.accessLevel = accessLevel
    }

    func loadAssets(scope: ScanScope) async throws -> [MediaAsset] {
        switch scope {
        case .preview:
            return try nextResponse(from: &previewResponses)
        case .fullLibrary:
            return try nextResponse(from: &fullLibraryResponses)
        }
    }

    func currentAccessLevel() -> PhotoLibraryAccessLevel {
        accessLevel
    }

    private func nextResponse(from responses: inout [Response]) throws -> [MediaAsset] {
        let response = responses.isEmpty ? .success([]) : responses.removeFirst()
        switch response {
        case .success(let assets):
            return assets
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
private final class FakeCleanupExecutionService: CleanupExecutionServiceProtocol {
    func executeDelete(for assets: [MediaAsset]) async throws -> CleanupExecutionResult {
        CleanupExecutionResult(
            deletedAssetIDs: assets.map(\.id),
            deletedCount: assets.count,
            reclaimedBytes: assets.reduce(Int64.zero) { $0 + $1.byteSize },
            failures: []
        )
    }
}
