import CryptoKit
import Foundation

#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

#if canImport(Security)
import Security
#endif

#if canImport(StoreKit)
import StoreKit
#endif

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

public actor InMemoryMediaFingerprintingService: MediaFingerprintingServiceProtocol {
    private var fingerprints: [String: String]

    public init(seed: [String: String] = [:]) {
        self.fingerprints = seed
    }

    public func cachedFingerprint(for key: String) async -> String? {
        fingerprints[key]
    }

    public func storeFingerprint(_ fingerprint: String, for key: String) async {
        fingerprints[key] = fingerprint
    }
}

public actor FileBackedMediaFingerprintingService: MediaFingerprintingServiceProtocol {
    private let fileURL: URL
    private let fileManager: FileManager
    private var fingerprints: [String: String]

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        let resolvedDirectoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.fileURL = resolvedDirectoryURL.appendingPathComponent("media-fingerprints.json")
        self.fingerprints = [:]

        try? fileManager.createDirectory(at: resolvedDirectoryURL, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: self.fileURL),
           let loaded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.fingerprints = loaded
        }
    }

    public func cachedFingerprint(for key: String) async -> String? {
        fingerprints[key]
    }

    public func storeFingerprint(_ fingerprint: String, for key: String) async {
        fingerprints[key] = fingerprint
        try? persist()
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("PrivadiCache", isDirectory: true)
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(fingerprints.sorted { $0.key < $1.key }.reduce(into: [String: String]()) { partialResult, item in
            partialResult[item.key] = item.value
        })
        try data.write(to: fileURL, options: .atomic)
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

public enum VaultServiceError: LocalizedError {
    case notConfigured
    case invalidPasscode
    case missingRecord
    case biometricsUnavailable
    case failedToPersistIndex
    case failedToReadIndex
    case keychainUnavailable

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Set up your vault before storing private items."
        case .invalidPasscode:
            "The vault passcode was not accepted."
        case .missingRecord:
            "The requested vault item could not be found."
        case .biometricsUnavailable:
            "Biometric unlock is not available on this device."
        case .failedToPersistIndex:
            "Privadi could not persist the vault index."
        case .failedToReadIndex:
            "Privadi could not read the stored vault index."
        case .keychainUnavailable:
            "Privadi could not access the secure key storage."
        }
    }
}

private struct VaultMetadata: Codable {
    let biometricsEnabled: Bool
}

private protocol VaultBiometricAuthorizing {
    func canUseBiometrics() -> Bool
}

private struct LiveVaultBiometricAuthorizer: VaultBiometricAuthorizing {
    func canUseBiometrics() -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #else
        return false
        #endif
    }
}

public final class FileVaultService: VaultServiceProtocol {
    private enum KeychainAccount {
        static let wrappedKey = "wrapped-root-key"
        static let biometricKey = "biometric-root-key"
        static let metadata = "vault-metadata"
    }

    private let directoryURL: URL
    private let indexURL: URL
    private let fileManager: FileManager
    private let keychainService: String
    private let biometricAuthorizer: VaultBiometricAuthorizing
    private var records: [VaultRecord] = []
    private var cachedKeyData: Data?
    private var cachedConfigurationState: VaultConfigurationState

    public init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        keychainService: String = "com.privadi.vault"
    ) {
        let biometricAuthorizer = LiveVaultBiometricAuthorizer()
        self.fileManager = fileManager
        self.keychainService = keychainService
        self.biometricAuthorizer = biometricAuthorizer
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.indexURL = self.directoryURL.appendingPathComponent("vault-records.json")
        self.cachedConfigurationState = VaultConfigurationState(
            isConfigured: false,
            biometricsEnabled: false,
            canUseBiometrics: biometricAuthorizer.canUseBiometrics()
        )

        try? fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
        if let loadedRecords = try? Self.loadRecords(from: self.indexURL) {
            records = loadedRecords
        }
        cachedConfigurationState = loadConfigurationState()
    }

    public func configurationState() -> VaultConfigurationState {
        cachedConfigurationState
    }

    public func configure(passcode: String, enableBiometrics: Bool) throws -> VaultConfigurationState {
        let rootKeyData = randomKeyData()
        let wrappedKey = try wrapRootKey(rootKeyData, passcode: passcode)
        try storeKeychainItem(data: wrappedKey, account: KeychainAccount.wrappedKey)

        let biometricsEnabled = enableBiometrics && biometricAuthorizer.canUseBiometrics()
        if biometricsEnabled {
            try storeBiometricKey(rootKeyData)
        } else {
            deleteKeychainItem(account: KeychainAccount.biometricKey)
        }

        let metadata = VaultMetadata(biometricsEnabled: biometricsEnabled)
        let metadataData = try JSONEncoder().encode(metadata)
        try storeKeychainItem(data: metadataData, account: KeychainAccount.metadata)

        cachedKeyData = rootKeyData
        cachedConfigurationState = VaultConfigurationState(
            isConfigured: true,
            biometricsEnabled: biometricsEnabled,
            canUseBiometrics: biometricAuthorizer.canUseBiometrics()
        )
        return cachedConfigurationState
    }

    public func store(_ payload: VaultPayload) throws -> VaultRecord {
        guard let keyData = cachedKeyData else {
            throw VaultServiceError.notConfigured
        }

        let sealedBox = try AES.GCM.seal(payload.rawData, using: SymmetricKey(data: keyData))
        guard let combined = sealedBox.combined else {
            throw VaultServiceError.failedToPersistIndex
        }

        let record = VaultRecord(
            id: UUID(),
            storedAt: .now,
            fileName: "\(UUID().uuidString).vault",
            itemType: payload.itemType
        )

        try combined.write(to: directoryURL.appendingPathComponent(record.fileName), options: .atomic)
        records.append(record)
        try persistRecords()
        return record
    }

    public func unlockVault(method: VaultUnlockMethod) async throws {
        let keyData = try await resolveKeyData(for: method)
        cachedKeyData = keyData
    }

    public func unlock(_ record: VaultRecord, method: VaultUnlockMethod) async throws -> VaultPayload {
        let url = directoryURL.appendingPathComponent(record.fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            throw VaultServiceError.missingRecord
        }

        let keyData = try await resolveKeyData(for: method)
        let data = try Data(contentsOf: url)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData))
            cachedKeyData = keyData
            return VaultPayload(itemType: record.itemType, rawData: decrypted)
        } catch {
            throw VaultServiceError.invalidPasscode
        }
    }

    public func listRecords() -> [VaultRecord] {
        records.sorted { $0.storedAt > $1.storedAt }
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("PrivadiVault", isDirectory: true)
    }

    private static func loadRecords(from indexURL: URL) throws -> [VaultRecord] {
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([VaultRecord].self, from: data)
    }

    private func loadConfigurationState() -> VaultConfigurationState {
        guard let metadataData = try? readKeychainItem(account: KeychainAccount.metadata),
              let metadata = try? JSONDecoder().decode(VaultMetadata.self, from: metadataData)
        else {
            return VaultConfigurationState(
                isConfigured: false,
                biometricsEnabled: false,
                canUseBiometrics: biometricAuthorizer.canUseBiometrics()
            )
        }

        return VaultConfigurationState(
            isConfigured: true,
            biometricsEnabled: metadata.biometricsEnabled,
            canUseBiometrics: biometricAuthorizer.canUseBiometrics()
        )
    }

    private func persistRecords() throws {
        do {
            let data = try JSONEncoder().encode(records.sorted { $0.storedAt > $1.storedAt })
            try data.write(to: indexURL, options: .atomic)
        } catch {
            throw VaultServiceError.failedToPersistIndex
        }
    }

    private func resolveKeyData(for method: VaultUnlockMethod) async throws -> Data {
        switch method {
        case .passcode(let passcode):
            let wrappedKey = try readKeychainItem(account: KeychainAccount.wrappedKey)
            return try unwrapRootKey(wrappedKey, passcode: passcode)
        case .biometrics:
            return try readBiometricKey()
        }
    }

    private func wrapRootKey(_ rootKeyData: Data, passcode: String) throws -> Data {
        let passcodeKey = SymmetricKey(data: Data(SHA256.hash(data: Data(passcode.utf8))))
        let sealedBox = try AES.GCM.seal(rootKeyData, using: passcodeKey)
        guard let combined = sealedBox.combined else {
            throw VaultServiceError.keychainUnavailable
        }
        return combined
    }

    private func unwrapRootKey(_ wrappedKey: Data, passcode: String) throws -> Data {
        let passcodeKey = SymmetricKey(data: Data(SHA256.hash(data: Data(passcode.utf8))))
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: wrappedKey)
            return try AES.GCM.open(sealedBox, using: passcodeKey)
        } catch {
            throw VaultServiceError.invalidPasscode
        }
    }

    private func randomKeyData() -> Data {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    private func storeBiometricKey(_ keyData: Data) throws {
        #if canImport(Security) && canImport(LocalAuthentication)
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )

        var query = baseKeychainQuery(account: KeychainAccount.biometricKey)
        query[kSecValueData as String] = keyData
        query[kSecAttrAccessControl as String] = access

        SecItemDelete(baseKeychainQuery(account: KeychainAccount.biometricKey) as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultServiceError.keychainUnavailable
        }
        #else
        throw VaultServiceError.biometricsUnavailable
        #endif
    }

    private func readBiometricKey() throws -> Data {
        #if canImport(Security) && canImport(LocalAuthentication)
        guard biometricAuthorizer.canUseBiometrics() else {
            throw VaultServiceError.biometricsUnavailable
        }

        let context = LAContext()
        context.localizedReason = "Unlock your Privadi vault"

        var query = baseKeychainQuery(account: KeychainAccount.biometricKey)
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationContext as String] = context

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultServiceError.biometricsUnavailable
        }
        return data
        #else
        throw VaultServiceError.biometricsUnavailable
        #endif
    }

    private func storeKeychainItem(data: Data, account: String) throws {
        #if canImport(Security)
        var query = baseKeychainQuery(account: account)
        query[kSecValueData as String] = data

        SecItemDelete(baseKeychainQuery(account: account) as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultServiceError.keychainUnavailable
        }
        #else
        throw VaultServiceError.keychainUnavailable
        #endif
    }

    private func readKeychainItem(account: String) throws -> Data {
        #if canImport(Security)
        var query = baseKeychainQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultServiceError.keychainUnavailable
        }
        return data
        #else
        throw VaultServiceError.keychainUnavailable
        #endif
    }

    private func deleteKeychainItem(account: String) {
        #if canImport(Security)
        SecItemDelete(baseKeychainQuery(account: account) as CFDictionary)
        #endif
    }

    private func baseKeychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
    }
}

public struct LocalHashBreachCheckService: BreachCheckServiceProtocol {
    private let hashes: Set<String>
    private let metadata: BreachDatasetMetadata

    public init(hashes: Set<String>) {
        self.hashes = hashes
        self.metadata = BreachDatasetMetadata(
            version: "custom",
            generatedAt: "unknown",
            entryCount: hashes.count,
            sourceDescription: "Injected hash set"
        )
    }

    public init(contents: String, metadata: BreachDatasetMetadata) {
        let loaded = Set(contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(Self.isValidHashLine))
        self.hashes = loaded
        self.metadata = BreachDatasetMetadata(
            version: metadata.version,
            generatedAt: metadata.generatedAt,
            entryCount: loaded.count,
            sourceDescription: metadata.sourceDescription
        )
    }

    public init(bundle: Bundle? = nil) {
        let bundle = bundle ?? .module
        let metadata = Self.loadMetadata(from: bundle)
        if let url = bundle.url(forResource: "breach_hashes", withExtension: "txt"),
           let contents = try? String(contentsOf: url) {
            self.init(contents: contents, metadata: metadata)
        } else {
            self.init(contents: "", metadata: metadata)
        }
    }

    public func check(email: String) -> BreachCheckResult {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = SHA256.hash(data: Data(normalized.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let breached = hashes.contains(hash)
        return BreachCheckResult(email: normalized, isBreached: breached, matchedHashes: breached ? 1 : 0)
    }

    public func datasetMetadata() -> BreachDatasetMetadata {
        metadata
    }

    private static func loadMetadata(from bundle: Bundle) -> BreachDatasetMetadata {
        guard let url = bundle.url(forResource: "breach_hashes_metadata", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let metadata = try? JSONDecoder().decode(BreachDatasetMetadata.self, from: data) else {
            return BreachDatasetMetadata(
                version: "missing",
                generatedAt: "unknown",
                entryCount: 0,
                sourceDescription: "Metadata unavailable"
            )
        }

        return metadata
    }

    private static func isValidHashLine(_ line: String) -> Bool {
        guard line.count == 64 else {
            return false
        }
        return line.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 97...102:
                true
            default:
                false
            }
        }
    }
}

public enum SubscriptionServiceError: LocalizedError {
    case productsUnavailable
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            "Privadi could not load the current subscription products."
        case .purchaseCancelled:
            "The purchase was cancelled before completion."
        case .purchasePending:
            "The purchase is pending approval."
        case .verificationFailed:
            "Privadi could not verify the purchase."
        case .unsupportedPlatform:
            "Subscriptions are not available on this platform."
        }
    }
}

public final class MockSubscriptionService: SubscriptionServiceProtocol {
    private let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")
    private var state = SubscriptionState(
        isActive: false,
        plan: nil,
        renewalDate: nil,
        availableProducts: [],
        manageSubscriptionsURL: URL(string: "https://apps.apple.com/account/subscriptions")
    )

    public init() {}

    public func currentState() async -> SubscriptionState {
        state
    }

    public func refreshEntitlements() async -> SubscriptionState {
        state
    }

    public func loadProducts() async throws -> [SubscriptionProduct] {
        let products = SubscriptionPlan.allCases.map { plan in
            SubscriptionProduct(
                id: plan.productIdentifier,
                plan: plan,
                displayName: plan.displayName,
                displayPrice: plan == .annual ? "$39.99/year" : "$8.99/month",
                detailText: plan == .annual ? "14-day free trial when eligible" : "Flexible monthly access"
            )
        }
        state = SubscriptionState(
            isActive: state.isActive,
            plan: state.plan,
            renewalDate: state.renewalDate,
            availableProducts: products,
            manageSubscriptionsURL: manageURL
        )
        return products
    }

    public func purchase(plan: SubscriptionPlan) async throws -> SubscriptionState {
        let renewalDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)
        let products = state.availableProducts.isEmpty ? (try? await loadProducts()) ?? [] : state.availableProducts
        state = SubscriptionState(
            isActive: true,
            plan: plan,
            renewalDate: renewalDate,
            availableProducts: products,
            manageSubscriptionsURL: manageURL
        )
        return state
    }

    public func restorePurchases() async throws -> SubscriptionState {
        state
    }
}

public final class StoreKitSubscriptionService: SubscriptionServiceProtocol {
    private let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")
    private var cachedProducts: [SubscriptionProduct] = []

    public init() {}

    public func currentState() async -> SubscriptionState {
        await refreshEntitlements()
    }

    public func refreshEntitlements() async -> SubscriptionState {
        let products = cachedProducts.isEmpty ? ((try? await loadProducts()) ?? []) : cachedProducts

        #if canImport(StoreKit)
        var activePlan: SubscriptionPlan?
        var renewalDate: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            guard transaction.revocationDate == nil else {
                continue
            }
            guard let plan = SubscriptionPlan.allCases.first(where: { $0.productIdentifier == transaction.productID }) else {
                continue
            }
            activePlan = plan
            renewalDate = transaction.expirationDate
            break
        }

        return SubscriptionState(
            isActive: activePlan != nil,
            plan: activePlan,
            renewalDate: renewalDate,
            availableProducts: products,
            manageSubscriptionsURL: manageURL
        )
        #else
        return SubscriptionState(
            isActive: false,
            plan: nil,
            renewalDate: nil,
            availableProducts: products,
            manageSubscriptionsURL: manageURL
        )
        #endif
    }

    public func loadProducts() async throws -> [SubscriptionProduct] {
        #if canImport(StoreKit)
        let productIDs = SubscriptionPlan.allCases.map(\.productIdentifier)
        let products = try await Product.products(for: productIDs)
        let mapped = products.compactMap { product -> SubscriptionProduct? in
            guard let plan = SubscriptionPlan.allCases.first(where: { $0.productIdentifier == product.id }) else {
                return nil
            }
            let detailText = product.subscription?.introductoryOffer == nil
                ? "Private, offline cleanup subscription"
                : "Includes an introductory offer when eligible"
            return SubscriptionProduct(
                id: product.id,
                plan: plan,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                detailText: detailText
            )
        }
        guard !mapped.isEmpty else {
            throw SubscriptionServiceError.productsUnavailable
        }
        cachedProducts = mapped.sorted { $0.plan.rawValue < $1.plan.rawValue }
        return cachedProducts
        #else
        throw SubscriptionServiceError.unsupportedPlatform
        #endif
    }

    public func purchase(plan: SubscriptionPlan) async throws -> SubscriptionState {
        #if canImport(StoreKit)
        let products = cachedProducts.isEmpty ? try await loadProducts() : cachedProducts
        guard let selected = products.first(where: { $0.plan == plan }) else {
            throw SubscriptionServiceError.productsUnavailable
        }
        let storeProducts = try await Product.products(for: [selected.id])
        guard let product = storeProducts.first else {
            throw SubscriptionServiceError.productsUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionServiceError.verificationFailed
            }
            await transaction.finish()
            return await refreshEntitlements()
        case .userCancelled:
            throw SubscriptionServiceError.purchaseCancelled
        case .pending:
            throw SubscriptionServiceError.purchasePending
        @unknown default:
            throw SubscriptionServiceError.verificationFailed
        }
        #else
        throw SubscriptionServiceError.unsupportedPlatform
        #endif
    }

    public func restorePurchases() async throws -> SubscriptionState {
        #if canImport(StoreKit)
        try await AppStore.sync()
        return await refreshEntitlements()
        #else
        throw SubscriptionServiceError.unsupportedPlatform
        #endif
    }
}

public enum CleanupExecutionServiceError: LocalizedError {
    case unsupported

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            "Cleanup execution is unavailable in this mode."
        }
    }
}

public struct PreviewCleanupExecutionService: CleanupExecutionServiceProtocol {
    public init() {}

    public func executeDelete(for assets: [MediaAsset]) async throws -> CleanupExecutionResult {
        throw CleanupExecutionServiceError.unsupported
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
