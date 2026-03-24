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
func vaultEncryptsAndUnlocksPayloads() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let service = FileVaultService(directoryURL: tempDir)
    let payload = VaultPayload(itemType: .contact, rawData: Data("secret".utf8))

    let record = try service.store(payload, passcode: "1234")
    let opened = try service.unlock(record, passcode: "1234")

    #expect(opened.rawData == payload.rawData)
    #expect(service.listRecords().count == 1)
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
