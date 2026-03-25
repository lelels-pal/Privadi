import Foundation

public struct AppEnvironment {
    public let photoLibraryService: PhotoLibraryServiceProtocol
    public let mediaFingerprintingService: MediaFingerprintingServiceProtocol
    public let mediaAnalysisEngine: MediaAnalysisEngineProtocol
    public let smartCleanPolicy: SmartCleanPolicyProtocol
    public let compressionEngine: CompressionEngineProtocol
    public let contactsCleanupService: ContactsCleanupServiceProtocol
    public let vaultService: VaultServiceProtocol
    public let breachCheckService: BreachCheckServiceProtocol
    public let subscriptionService: SubscriptionServiceProtocol
    public let cleanupExecutionService: CleanupExecutionServiceProtocol
    public let metricsService: MetricsServiceProtocol

    public init(
        photoLibraryService: PhotoLibraryServiceProtocol,
        mediaFingerprintingService: MediaFingerprintingServiceProtocol,
        mediaAnalysisEngine: MediaAnalysisEngineProtocol,
        smartCleanPolicy: SmartCleanPolicyProtocol,
        compressionEngine: CompressionEngineProtocol,
        contactsCleanupService: ContactsCleanupServiceProtocol,
        vaultService: VaultServiceProtocol,
        breachCheckService: BreachCheckServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        cleanupExecutionService: CleanupExecutionServiceProtocol,
        metricsService: MetricsServiceProtocol
    ) {
        self.photoLibraryService = photoLibraryService
        self.mediaFingerprintingService = mediaFingerprintingService
        self.mediaAnalysisEngine = mediaAnalysisEngine
        self.smartCleanPolicy = smartCleanPolicy
        self.compressionEngine = compressionEngine
        self.contactsCleanupService = contactsCleanupService
        self.vaultService = vaultService
        self.breachCheckService = breachCheckService
        self.subscriptionService = subscriptionService
        self.cleanupExecutionService = cleanupExecutionService
        self.metricsService = metricsService
    }

    @MainActor
    public static func livePreview() -> AppEnvironment {
        let mediaFingerprintingService = InMemoryMediaFingerprintingService()
        return AppEnvironment(
            photoLibraryService: DemoPhotoLibraryService(),
            mediaFingerprintingService: mediaFingerprintingService,
            mediaAnalysisEngine: HeuristicMediaAnalysisEngine(),
            smartCleanPolicy: SmartCleanPolicy(),
            compressionEngine: CompressionEngine(),
            contactsCleanupService: ContactsCleanupService(),
            vaultService: FileVaultService(),
            breachCheckService: LocalHashBreachCheckService(),
            subscriptionService: MockSubscriptionService(),
            cleanupExecutionService: PreviewCleanupExecutionService(),
            metricsService: AggregateMetricsService()
        )
    }

    @MainActor
    public static func liveApp() -> AppEnvironment {
        let mediaFingerprintingService = FileBackedMediaFingerprintingService()
        return AppEnvironment(
            photoLibraryService: DevicePhotoLibraryService(mediaFingerprintingService: mediaFingerprintingService),
            mediaFingerprintingService: mediaFingerprintingService,
            mediaAnalysisEngine: HeuristicMediaAnalysisEngine(),
            smartCleanPolicy: SmartCleanPolicy(),
            compressionEngine: CompressionEngine(),
            contactsCleanupService: DeviceContactsCleanupService(),
            vaultService: FileVaultService(),
            breachCheckService: LocalHashBreachCheckService(),
            subscriptionService: StoreKitSubscriptionService(),
            cleanupExecutionService: DeviceCleanupExecutionService(),
            metricsService: AggregateMetricsService()
        )
    }
}
