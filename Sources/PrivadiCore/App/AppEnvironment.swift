import Foundation

public struct AppEnvironment {
    public let photoLibraryService: PhotoLibraryServiceProtocol
    public let mediaAnalysisEngine: MediaAnalysisEngineProtocol
    public let smartCleanPolicy: SmartCleanPolicyProtocol
    public let compressionEngine: CompressionEngineProtocol
    public let contactsCleanupService: ContactsCleanupServiceProtocol
    public let vaultService: VaultServiceProtocol
    public let breachCheckService: BreachCheckServiceProtocol
    public let subscriptionService: SubscriptionServiceProtocol
    public let metricsService: MetricsServiceProtocol

    public init(
        photoLibraryService: PhotoLibraryServiceProtocol,
        mediaAnalysisEngine: MediaAnalysisEngineProtocol,
        smartCleanPolicy: SmartCleanPolicyProtocol,
        compressionEngine: CompressionEngineProtocol,
        contactsCleanupService: ContactsCleanupServiceProtocol,
        vaultService: VaultServiceProtocol,
        breachCheckService: BreachCheckServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        metricsService: MetricsServiceProtocol
    ) {
        self.photoLibraryService = photoLibraryService
        self.mediaAnalysisEngine = mediaAnalysisEngine
        self.smartCleanPolicy = smartCleanPolicy
        self.compressionEngine = compressionEngine
        self.contactsCleanupService = contactsCleanupService
        self.vaultService = vaultService
        self.breachCheckService = breachCheckService
        self.subscriptionService = subscriptionService
        self.metricsService = metricsService
    }

    @MainActor
    public static func livePreview() -> AppEnvironment {
        AppEnvironment(
            photoLibraryService: DemoPhotoLibraryService(),
            mediaAnalysisEngine: HeuristicMediaAnalysisEngine(),
            smartCleanPolicy: SmartCleanPolicy(),
            compressionEngine: CompressionEngine(),
            contactsCleanupService: ContactsCleanupService(),
            vaultService: FileVaultService(),
            breachCheckService: LocalHashBreachCheckService(),
            subscriptionService: MockSubscriptionService(),
            metricsService: AggregateMetricsService()
        )
    }

    @MainActor
    public static func liveApp() -> AppEnvironment {
        AppEnvironment(
            photoLibraryService: DevicePhotoLibraryService(),
            mediaAnalysisEngine: HeuristicMediaAnalysisEngine(),
            smartCleanPolicy: SmartCleanPolicy(),
            compressionEngine: CompressionEngine(),
            contactsCleanupService: DeviceContactsCleanupService(),
            vaultService: FileVaultService(),
            breachCheckService: LocalHashBreachCheckService(),
            subscriptionService: MockSubscriptionService(),
            metricsService: AggregateMetricsService()
        )
    }
}
