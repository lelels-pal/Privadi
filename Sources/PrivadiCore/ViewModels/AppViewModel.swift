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

    @Published public private(set) var stage: Stage = .privacy
    @Published public private(set) var experienceMode: ExperienceMode = .live
    @Published public private(set) var summary: DashboardSummary?
    @Published public private(set) var selection: SmartCleanSelection?
    @Published public private(set) var contactSuggestions: [ContactMergeSuggestion] = []
    @Published public private(set) var breachResult: BreachCheckResult?
    @Published public private(set) var subscriptionState = SubscriptionState(isActive: false, plan: nil, trialEndsAt: nil)
    @Published public private(set) var compressionEstimate = CompressionEstimate(originalBytes: 0, optimizedBytes: 0)
    @Published public private(set) var vaultRecords: [VaultRecord] = []
    @Published public var statusText = "Ready to reclaim storage."

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func continueFromPrivacy() {
        environment.metricsService.record(AppMetricEvent(name: "privacy_viewed"))
        stage = .permissions
    }

    public func continueFromPermissions() {
        environment.metricsService.record(AppMetricEvent(name: "permissions_explained"))
        stage = .paywall
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
            await activate(plan: .annual)
        }
    }

    public func startMonthlyPlan() {
        Task {
            await activate(plan: .monthly)
        }
    }

    public func runBreachCheck(email: String) {
        breachResult = environment.breachCheckService.check(email: email)
        environment.metricsService.record(AppMetricEvent(name: "breach_checked"))
    }

    public func storeSampleInVault() {
        do {
            let payload = VaultPayload(itemType: .contact, rawData: Data("Privadi keeps this offline.".utf8))
            _ = try environment.vaultService.store(payload, passcode: "1234")
            vaultRecords = environment.vaultService.listRecords()
            environment.metricsService.record(AppMetricEvent(name: "vault_item_saved"))
        } catch {
            statusText = "Unable to store the sample item in the vault."
        }
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

    private func activate(plan: SubscriptionPlan) async {
        let returnStage = stage
        stage = .scanning
        statusText = "Preparing your private cleanup plan."
        experienceMode = .live
        environment.metricsService.record(AppMetricEvent(name: "trial_started"))
        subscriptionState = await environment.subscriptionService.startTrial(plan: plan)

        do {
            try await loadDashboard(as: .live, scope: .fullLibrary)
        } catch {
            statusText = liveScanErrorMessage(for: error)
            stage = returnStage
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
        self.vaultRecords = environment.vaultService.listRecords()
        self.summary = DashboardSummary(
            totalItems: analysis.assets.count,
            reclaimableBytes: selection.estimatedReclaimableBytes + compressionEstimate.savingsBytes,
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
            return "Instant scan complete. Potential reclaimable space is ready."
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
