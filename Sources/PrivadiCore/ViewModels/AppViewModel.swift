import Foundation
import SwiftUI

@MainActor
public final class AppViewModel: ObservableObject {
    public enum Stage: Sendable, Equatable {
        case privacy
        case permissions
        case paywall
        case scanning
        case dashboard
    }

    public enum ExperienceMode: Sendable, Equatable {
        case live
        case limitedPreview
    }

    public enum CleanupExecutionPhase: Sendable, Equatable {
        case idle
        case reviewing
        case executing
        case completed(CleanupExecutionResult)
        case failed(String)
    }

    public enum VaultAccessState: Sendable, Equatable {
        case unconfigured
        case locked
        case unlocked
    }

    @Published public private(set) var stage: Stage = .privacy
    @Published public private(set) var experienceMode: ExperienceMode = .live
    @Published public private(set) var summary: DashboardSummary?
    @Published public private(set) var selection: SmartCleanSelection?
    @Published public private(set) var contactSuggestions: [ContactMergeSuggestion] = []
    @Published public private(set) var breachResult: BreachCheckResult?
    @Published public private(set) var subscriptionState = SubscriptionState(isActive: false, plan: nil, renewalDate: nil)
    @Published public private(set) var compressionEstimate = CompressionEstimate(originalBytes: 0, optimizedBytes: 0)
    @Published public private(set) var vaultRecords: [VaultRecord] = []
    @Published public private(set) var vaultConfiguration = VaultConfigurationState(isConfigured: false, biometricsEnabled: false, canUseBiometrics: false)
    @Published public private(set) var vaultAccessState: VaultAccessState = .unconfigured
    @Published public private(set) var cleanupCategories: [CleanupReviewCategory] = []
    @Published public private(set) var selectedCleanupCategoryIDs: Set<String> = []
    @Published public private(set) var cleanupReviewPlan: CleanupReviewPlan?
    @Published public private(set) var cleanupExecutionPhase: CleanupExecutionPhase = .idle
    @Published public private(set) var purchaseInProgress: SubscriptionPlan?
    @Published public private(set) var restoreInProgress = false
    @Published public private(set) var paywallStatusText: String?
    @Published public var statusText = "Ready to reclaim storage."

    private let environment: AppEnvironment
    private var hasBootstrapped = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func bootstrap() async {
        guard !hasBootstrapped else {
            return
        }
        hasBootstrapped = true
        refreshVaultState(preserveUnlockState: false)
        await reloadBillingState()
    }

    public func continueFromPrivacy() {
        environment.metricsService.record(AppMetricEvent(name: "privacy_viewed"))
        stage = .permissions
    }

    public func continueFromPermissions() {
        Task {
            await continueFromPermissionsFlow()
        }
    }

    public func startLimitedPreview() {
        Task {
            await startLimitedPreviewFlow(returnStage: stage)
        }
    }

    public func showPaywallFromPreview() {
        environment.metricsService.record(AppMetricEvent(name: "limited_preview_exited_to_paywall"))
        statusText = "Start a plan to run Privadi on your own library."
        experienceMode = .live
        stage = .paywall
    }

    public func startAnnualTrial() {
        Task {
            await purchase(plan: .annual)
        }
    }

    public func startMonthlyPlan() {
        Task {
            await purchase(plan: .monthly)
        }
    }

    public func restorePurchases() {
        Task {
            await restorePurchasesFlow()
        }
    }

    public func runBreachCheck(email: String) {
        breachResult = environment.breachCheckService.check(email: email)
        environment.metricsService.record(AppMetricEvent(name: "breach_checked"))
    }

    public func configureVault(passcode: String, enableBiometrics: Bool) {
        let trimmed = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else {
            statusText = "Use a vault passcode with at least four characters."
            return
        }

        do {
            vaultConfiguration = try environment.vaultService.configure(passcode: trimmed, enableBiometrics: enableBiometrics)
            vaultAccessState = .unlocked
            _ = try environment.vaultService.store(sampleVaultPayload())
            refreshVaultState(preserveUnlockState: true)
            environment.metricsService.record(AppMetricEvent(name: "vault_item_saved"))
            statusText = vaultConfiguration.biometricsEnabled
                ? "Vault configured and the sample item is now protected with passcode and biometrics."
                : "Vault configured and the sample item is now protected with your passcode."
        } catch {
            statusText = error.localizedDescription
        }
    }

    public func saveSampleToConfiguredVault() {
        do {
            guard vaultConfiguration.isConfigured else {
                statusText = "Set up the vault before saving private items."
                return
            }
            _ = try environment.vaultService.store(sampleVaultPayload())
            vaultAccessState = .unlocked
            refreshVaultState(preserveUnlockState: true)
            environment.metricsService.record(AppMetricEvent(name: "vault_item_saved"))
            statusText = "Another sample item was saved to your encrypted vault."
        } catch VaultServiceError.notConfigured {
            vaultAccessState = .locked
            statusText = "Unlock your vault before saving more private items."
        } catch {
            statusText = error.localizedDescription
        }
    }

    public func unlockVault(passcode: String) async {
        let trimmed = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = "Enter your vault passcode to unlock the encrypted items."
            return
        }

        do {
            try await environment.vaultService.unlockVault(method: .passcode(trimmed))
            vaultAccessState = .unlocked
            refreshVaultState(preserveUnlockState: true)
            statusText = "Vault unlocked. You can save protected items again."
        } catch {
            vaultAccessState = .locked
            statusText = error.localizedDescription
        }
    }

    public func unlockVaultWithBiometrics() async {
        do {
            try await environment.vaultService.unlockVault(method: .biometrics)
            vaultAccessState = .unlocked
            refreshVaultState(preserveUnlockState: true)
            statusText = "Vault unlocked with biometrics."
        } catch {
            vaultAccessState = .locked
            statusText = error.localizedDescription
        }
    }

    public func toggleCleanupCategory(_ id: String) {
        guard cleanupCategories.contains(where: { $0.id == id && $0.isSelectable }) else {
            return
        }

        if selectedCleanupCategoryIDs.contains(id) {
            selectedCleanupCategoryIDs.remove(id)
        } else {
            selectedCleanupCategoryIDs.insert(id)
        }
    }

    public func reviewCleanupPlan() {
        guard experienceMode == .live else {
            statusText = "Preview prepared offline. Start a plan when you want the full-library version on your own device."
            return
        }

        let selectedCategories = cleanupCategories.filter { selectedCleanupCategoryIDs.contains($0.id) }
        let deleteCandidates = deduplicatedAssets(
            from: selectedCategories
                .filter(\.isDestructive)
                .flatMap(\.eligibleAssets)
        )

        guard !deleteCandidates.isEmpty else {
            statusText = "Your selected categories are review-only for now. Choose media delete items to continue."
            return
        }

        let reclaimableBytes = deleteCandidates.reduce(Int64.zero) { $0 + $1.byteSize }
        cleanupReviewPlan = CleanupReviewPlan(
            categories: selectedCategories,
            selectedCategoryIDs: selectedCleanupCategoryIDs,
            deleteCandidates: deleteCandidates,
            estimatedReclaimableBytes: reclaimableBytes
        )
        cleanupExecutionPhase = .reviewing
        statusText = "Review the exact delete candidates before anything is removed."
    }

    public func dismissCleanupReview() {
        cleanupReviewPlan = nil
        if case .executing = cleanupExecutionPhase {
            return
        }
        cleanupExecutionPhase = .idle
    }

    public func executeCleanupPlan() {
        Task {
            await executeCleanupPlanFlow()
        }
    }

    public func selectedReclaimableBytes() -> Int64 {
        cleanupCategories
            .filter { selectedCleanupCategoryIDs.contains($0.id) }
            .reduce(into: Int64.zero) { partialResult, category in
                partialResult += category.estimatedBytes
            }
    }

    public func product(for plan: SubscriptionPlan) -> SubscriptionProduct? {
        subscriptionState.availableProducts.first { $0.plan == plan }
    }

    public func isProductActionDisabled(_ plan: SubscriptionPlan) -> Bool {
        purchaseInProgress != nil || restoreInProgress || product(for: plan) == nil
    }

    func startLimitedPreviewFlow(returnStage: Stage = .permissions) async {
        stage = .scanning
        statusText = "Scanning a limited set of recent items from your library on-device."
        environment.metricsService.record(AppMetricEvent(name: "limited_preview_started"))

        do {
            try await loadDashboard(as: .limitedPreview, scope: .preview)
        } catch {
            statusText = previewErrorMessage(for: error)
            stage = returnStage
        }
    }

    private func continueFromPermissionsFlow() async {
        environment.metricsService.record(AppMetricEvent(name: "permissions_explained"))
        await reloadBillingState()

        if subscriptionState.isActive {
            await loadSubscribedDashboard()
        } else {
            stage = .paywall
        }
    }

    private func purchase(plan: SubscriptionPlan) async {
        purchaseInProgress = plan
        paywallStatusText = nil

        do {
            subscriptionState = try await environment.subscriptionService.purchase(plan: plan)
            environment.metricsService.record(AppMetricEvent(name: "subscription_purchased_\(plan.rawValue)"))
            purchaseInProgress = nil
            await loadSubscribedDashboard()
        } catch {
            purchaseInProgress = nil
            paywallStatusText = error.localizedDescription
            stage = .paywall
        }
    }

    private func restorePurchasesFlow() async {
        restoreInProgress = true
        paywallStatusText = nil

        do {
            subscriptionState = try await environment.subscriptionService.restorePurchases()
            restoreInProgress = false
            if subscriptionState.isActive {
                environment.metricsService.record(AppMetricEvent(name: "subscription_restored"))
                await loadSubscribedDashboard()
            } else {
                paywallStatusText = "No active subscription was restored for this Apple ID."
            }
        } catch {
            restoreInProgress = false
            paywallStatusText = error.localizedDescription
        }
    }

    private func reloadBillingState() async {
        do {
            _ = try await environment.subscriptionService.loadProducts()
            subscriptionState = await environment.subscriptionService.refreshEntitlements()
            paywallStatusText = nil
        } catch {
            subscriptionState = await environment.subscriptionService.refreshEntitlements()
            paywallStatusText = error.localizedDescription
        }
    }

    private func loadSubscribedDashboard() async {
        stage = .scanning
        statusText = "Preparing your private cleanup plan."
        experienceMode = .live

        do {
            try await loadDashboard(as: .live, scope: .fullLibrary)
        } catch {
            statusText = liveScanErrorMessage(for: error)
            stage = .permissions
        }
    }

    private func executeCleanupPlanFlow() async {
        guard let reviewPlan = cleanupReviewPlan else {
            return
        }

        cleanupExecutionPhase = .executing
        statusText = "Deleting the selected items from your photo library."

        do {
            let result = try await environment.cleanupExecutionService.executeDelete(for: reviewPlan.deleteCandidates)
            cleanupReviewPlan = nil
            cleanupExecutionPhase = .completed(result)
            environment.metricsService.record(AppMetricEvent(name: "cleanup_executed"))

            let scope: ScanScope = experienceMode == .live ? .fullLibrary : .preview
            var didFailRefresh = false
            do {
                try await loadDashboard(as: experienceMode, scope: scope)
            } catch {
                didFailRefresh = true
                handlePostCleanupRefreshFailure(error, result: result, experienceMode: experienceMode)
            }

            if didFailRefresh {
                return
            }

            if result.failures.isEmpty {
                if case .completed = cleanupExecutionPhase {
                    statusText = "Deleted \(result.deletedCount) items and reclaimed \(result.reclaimedBytes.privadiByteString)."
                }
            } else {
                if case .completed = cleanupExecutionPhase {
                    statusText = "Deleted \(result.deletedCount) items, but \(result.failures.count) item(s) could not be removed."
                }
            }
        } catch {
            cleanupExecutionPhase = .failed(error.localizedDescription)
            statusText = "Privadi could not complete the cleanup. Please try again."
        }
    }

    private func loadDashboard(as experienceMode: ExperienceMode, scope: ScanScope) async throws {
        let assets = try await environment.photoLibraryService.loadAssets(scope: scope)

        let contacts: [ContactRecord]
        if scope.includesContacts {
            contacts = (try? await environment.contactsCleanupService.loadContacts(scope: scope)) ?? []
        } else {
            contacts = []
        }

        let analysis = await environment.mediaAnalysisEngine.analyze(assets: assets)
        let selection = environment.smartCleanPolicy.selection(for: analysis)
        let compressionEstimate = await environment.compressionEngine.estimateSavings(for: selection.autoSelectedAssets)
        let mergeSuggestions = environment.contactsCleanupService.mergeSuggestions(from: contacts)
        let accessLevel = environment.photoLibraryService.currentAccessLevel()

        self.experienceMode = experienceMode
        self.selection = selection
        self.compressionEstimate = compressionEstimate
        self.contactSuggestions = mergeSuggestions
        refreshVaultState(preserveUnlockState: true)
        self.cleanupCategories = buildCleanupCategories(
            analysis: analysis,
            selection: selection,
            compressionEstimate: compressionEstimate,
            contactSuggestionCount: mergeSuggestions.count,
            experienceMode: experienceMode
        )
        syncSelectedCleanupCategoryIDs()

        let deleteBytes = cleanupCategories
            .first(where: { $0.kind == .mediaDelete })?
            .estimatedBytes ?? selection.estimatedReclaimableBytes

        self.summary = DashboardSummary(
            totalItems: analysis.assets.count,
            reclaimableBytes: deleteBytes,
            duplicateGroupCount: analysis.duplicateGroups.count,
            similarGroupCount: analysis.similarGroups.count,
            lowQualityCount: analysis.lowQualityAssets.count,
            largeVideoCount: analysis.largeVideoAssets.count,
            screenshotCount: analysis.screenshots.count,
            sloMoCount: analysis.sloMoAssets.count,
            contactSuggestionCount: mergeSuggestions.count,
            vaultItemCount: vaultRecords.count
        )
        statusText = statusText(for: experienceMode, assetCount: analysis.assets.count, accessLevel: accessLevel)
        environment.metricsService.record(
            AppMetricEvent(
                name: experienceMode == .limitedPreview ? "limited_preview_completed" : "scan_completed"
            )
        )
        stage = .dashboard
    }

    private func refreshVaultState(preserveUnlockState: Bool) {
        vaultConfiguration = environment.vaultService.configurationState()
        vaultRecords = environment.vaultService.listRecords()

        if !vaultConfiguration.isConfigured {
            vaultAccessState = .unconfigured
        } else if preserveUnlockState, vaultAccessState == .unlocked {
            vaultAccessState = .unlocked
        } else {
            vaultAccessState = .locked
        }
    }

    private func handlePostCleanupRefreshFailure(
        _ error: Error,
        result: CleanupExecutionResult,
        experienceMode: ExperienceMode
    ) {
        if let accessError = error as? DeviceDataAccessError {
            switch accessError {
            case .emptyPhotoLibrary, .emptyPreviewLibrary:
                applyEmptyDashboardState(for: experienceMode)
            case .photoAccessRequired, .unavailableOnCurrentPlatform:
                break
            }
        }

        cleanupExecutionPhase = .completed(result)
        if result.failures.isEmpty {
            statusText = "Cleanup finished and reclaimed \(result.reclaimedBytes.privadiByteString), but Privadi could not refresh the library."
        } else {
            statusText = "Cleanup finished, but Privadi could not refresh the library after removing \(result.deletedCount) items."
        }
    }

    private func applyEmptyDashboardState(for experienceMode: ExperienceMode) {
        let selection = SmartCleanSelection(
            autoSelectedAssets: [],
            reviewSimilarGroups: [],
            estimatedReclaimableBytes: 0
        )
        let analysis = LibraryAnalysis(
            assets: [],
            duplicateGroups: [],
            similarGroups: [],
            lowQualityAssets: [],
            screenshots: [],
            sloMoAssets: [],
            largeVideoAssets: []
        )
        let compressionEstimate = CompressionEstimate(originalBytes: 0, optimizedBytes: 0)

        self.experienceMode = experienceMode
        self.selection = selection
        self.compressionEstimate = compressionEstimate
        refreshVaultState(preserveUnlockState: true)
        self.cleanupCategories = buildCleanupCategories(
            analysis: analysis,
            selection: selection,
            compressionEstimate: compressionEstimate,
            contactSuggestionCount: contactSuggestions.count,
            experienceMode: experienceMode
        )
        syncSelectedCleanupCategoryIDs()
        self.summary = DashboardSummary(
            totalItems: 0,
            reclaimableBytes: 0,
            duplicateGroupCount: 0,
            similarGroupCount: 0,
            lowQualityCount: 0,
            largeVideoCount: 0,
            screenshotCount: 0,
            sloMoCount: 0,
            contactSuggestionCount: contactSuggestions.count,
            vaultItemCount: vaultRecords.count
        )
        stage = .dashboard
    }

    private func buildCleanupCategories(
        analysis: LibraryAnalysis,
        selection: SmartCleanSelection,
        compressionEstimate: CompressionEstimate,
        contactSuggestionCount: Int,
        experienceMode: ExperienceMode
    ) -> [CleanupReviewCategory] {
        var categories = [
            CleanupReviewCategory(
                id: "media",
                kind: .mediaDelete,
                title: "Delete Candidates",
                metric: selection.estimatedReclaimableBytes.privadiByteString,
                subtitle: "\(selection.autoSelectedAssets.count) exact-duplicate or low-risk items ready for review",
                icon: "trash.fill",
                detailLines: [
                    "\(analysis.duplicateGroups.count) duplicate groups",
                    "\(analysis.similarGroups.count) similar groups stay review-only",
                    "\(analysis.lowQualityAssets.count) low-quality picks",
                ],
                estimatedBytes: selection.estimatedReclaimableBytes,
                eligibleAssets: selection.autoSelectedAssets,
                isDestructive: true,
                isSelectable: true
            ),
            CleanupReviewCategory(
                id: "compression",
                kind: .compressionReview,
                title: "Compression Center",
                metric: max(compressionEstimate.savingsBytes, 0).privadiByteString,
                subtitle: "Large media that can be reduced locally in a later release",
                icon: "video.fill",
                detailLines: [
                    "\(analysis.largeVideoAssets.count) large videos",
                    "\(analysis.screenshots.count) screenshots",
                    "\(analysis.sloMoAssets.count) slo-mo clips",
                ],
                estimatedBytes: 0,
                eligibleAssets: [],
                isDestructive: false,
                isSelectable: true
            ),
        ]

        if experienceMode == .live {
            categories.append(
                CleanupReviewCategory(
                    id: "contacts",
                    kind: .contactReview,
                    title: "Contact Hygiene",
                    metric: "\(contactSuggestionCount) fixes",
                    subtitle: "Duplicate and incomplete entries stay review-only",
                    icon: "person.crop.circle.badge.checkmark",
                    detailLines: [
                        "Review-first merge suggestions",
                        "No cloud contact matching",
                        "Pairs with the secure local vault",
                    ],
                    estimatedBytes: 0,
                    eligibleAssets: [],
                    isDestructive: false,
                    isSelectable: true
                )
            )
        }

        return categories
    }

    private func syncSelectedCleanupCategoryIDs() {
        let selectableIDs = Set(cleanupCategories.filter(\.isSelectable).map(\.id))
        if selectedCleanupCategoryIDs.isEmpty {
            selectedCleanupCategoryIDs = selectableIDs
        } else {
            selectedCleanupCategoryIDs = selectedCleanupCategoryIDs.intersection(selectableIDs)
            if selectedCleanupCategoryIDs.isEmpty {
                selectedCleanupCategoryIDs = selectableIDs
            }
        }
    }

    private func deduplicatedAssets(from assets: [MediaAsset]) -> [MediaAsset] {
        var seen = Set<String>()
        return assets.filter { asset in
            seen.insert(asset.id).inserted
        }
    }

    private func sampleVaultPayload() -> VaultPayload {
        VaultPayload(itemType: .contact, rawData: Data("Privadi keeps this offline.".utf8))
    }

    private func statusText(
        for experienceMode: ExperienceMode,
        assetCount: Int,
        accessLevel: PhotoLibraryAccessLevel
    ) -> String {
        switch experienceMode {
        case .limitedPreview:
            return "Limited preview ready. Privadi scanned \(assetCount) recent items locally so you can feel the workflow first."
        case .live:
            if accessLevel == .limited {
                return "Scan complete for the photos you shared with Privadi. Expand Photos access when you want a full-library review."
            }
            return "Instant scan complete. Exact-duplicate delete candidates are ready for review."
        }
    }

    private func previewErrorMessage(for error: Error) -> String {
        if let accessError = error as? DeviceDataAccessError {
            switch accessError {
            case .photoAccessRequired:
                return "Photo Library access is needed for a real-device preview. You can allow Limited Access and keep the scan on-device."
            case .emptyPreviewLibrary:
                return "Privadi could not find enough recent media for the preview yet. Add a few photos or videos and try again."
            case .emptyPhotoLibrary, .unavailableOnCurrentPlatform:
                return accessError.errorDescription ?? "Unable to run the limited preview right now."
            }
        }

        return "Unable to run the limited preview right now. Please try again."
    }

    private func liveScanErrorMessage(for error: Error) -> String {
        if let accessError = error as? DeviceDataAccessError {
            switch accessError {
            case .photoAccessRequired:
                return "Photo Library access is required before Privadi can scan your own media."
            case .emptyPhotoLibrary:
                return "Privadi could not find any photos or videos to scan yet."
            case .emptyPreviewLibrary, .unavailableOnCurrentPlatform:
                return accessError.errorDescription ?? "The offline scan failed. Please review permissions and try again."
            }
        }

        return "The offline scan failed. Please review permissions and try again."
    }
}
