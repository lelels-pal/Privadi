import Foundation

#if canImport(Contacts)
import Contacts
#endif

#if canImport(Photos)
import Photos
#endif

public enum DeviceDataAccessError: LocalizedError {
    case photoAccessRequired
    case emptyPreviewLibrary
    case emptyPhotoLibrary
    case unavailableOnCurrentPlatform

    public var errorDescription: String? {
        switch self {
        case .photoAccessRequired:
            "Photo Library access is required to scan your own media."
        case .emptyPreviewLibrary:
            "Privadi could not find enough recent photos or videos for a limited preview."
        case .emptyPhotoLibrary:
            "Privadi could not find any photos or videos to scan."
        case .unavailableOnCurrentPlatform:
            "Real-device preview is only available on supported Apple devices."
        }
    }
}

public struct DevicePhotoLibraryService: PhotoLibraryServiceProtocol {
    public init() {}

    public func loadAssets(scope: ScanScope) async throws -> [MediaAsset] {
        #if canImport(Photos)
        let authorization = await requestPhotoAuthorizationIfNeeded()
        guard authorization == .authorized || authorization == .limited else {
            throw DeviceDataAccessError.photoAccessRequired
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let limit = scope.assetLimit {
            options.fetchLimit = limit
        }

        let fetchedAssets = PHAsset.fetchAssets(with: options)
        var mappedAssets: [MediaAsset] = []
        mappedAssets.reserveCapacity(fetchedAssets.count)

        fetchedAssets.enumerateObjects { asset, _, _ in
            mappedAssets.append(mapAsset(asset))
        }

        if mappedAssets.isEmpty {
            throw scope == .preview ? DeviceDataAccessError.emptyPreviewLibrary : DeviceDataAccessError.emptyPhotoLibrary
        }

        return mappedAssets
        #else
        throw DeviceDataAccessError.unavailableOnCurrentPlatform
        #endif
    }

    public func currentAccessLevel() -> PhotoLibraryAccessLevel {
        #if canImport(Photos)
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .limited:
            .limited
        case .authorized:
            .full
        default:
            .demo
        }
        #else
        .demo
        #endif
    }

    #if canImport(Photos)
    private func requestPhotoAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func mapAsset(_ asset: PHAsset) -> MediaAsset {
        let kind = mediaKind(for: asset)
        let estimatedBytes = estimatedByteSize(for: asset, kind: kind)
        let createdAt = asset.creationDate ?? .now

        return MediaAsset(
            id: asset.localIdentifier,
            name: PHAssetResource.assetResources(for: asset).first?.originalFilename ?? fallbackName(for: kind, createdAt: createdAt),
            kind: kind,
            byteSize: estimatedBytes,
            checksum: nil,
            similarityKey: similarityKey(for: asset, kind: kind),
            qualityScore: qualityScore(for: asset, kind: kind),
            eyeClosureScore: 0,
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            createdAt: createdAt
        )
    }

    private func mediaKind(for asset: PHAsset) -> MediaKind {
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return .screenshot
        }

        if asset.mediaType == .video {
            return asset.mediaSubtypes.contains(.videoHighFrameRate) ? .sloMo : .video
        }

        if asset.mediaSubtypes.contains(.photoLive) {
            return .livePhoto
        }

        if asset.representsBurst {
            return .burst
        }

        return .photo
    }

    private func estimatedByteSize(for asset: PHAsset, kind: MediaKind) -> Int64 {
        let pixelCount = Double(max(asset.pixelWidth * asset.pixelHeight, 1))

        switch kind {
        case .photo:
            return max(Int64(pixelCount * 0.16), 900_000)
        case .burst:
            return max(Int64(pixelCount * 0.14), 800_000)
        case .screenshot:
            return max(Int64(pixelCount * 0.22), 700_000)
        case .livePhoto:
            return max(Int64(pixelCount * 0.17) + 3_000_000, 4_000_000)
        case .video:
            return max(Int64(asset.duration * videoBytesPerSecond(for: asset, slowMotion: false)), 5_000_000)
        case .sloMo:
            return max(Int64(asset.duration * videoBytesPerSecond(for: asset, slowMotion: true)), 12_000_000)
        }
    }

    private func videoBytesPerSecond(for asset: PHAsset, slowMotion: Bool) -> Double {
        if slowMotion {
            return 2_800_000
        }

        if asset.pixelWidth >= 3_840 || asset.pixelHeight >= 2_160 {
            return 5_200_000
        }

        if asset.pixelWidth >= 1_920 || asset.pixelHeight >= 1_080 {
            return 2_100_000
        }

        return 950_000
    }

    private func similarityKey(for asset: PHAsset, kind: MediaKind) -> String? {
        if let burstIdentifier = asset.burstIdentifier, !burstIdentifier.isEmpty {
            return "burst-\(burstIdentifier)"
        }

        guard let createdAt = asset.creationDate else {
            return nil
        }

        let bucket = Int(createdAt.timeIntervalSince1970 / 120)
        let dimensionBucket = "\(max(asset.pixelWidth / 400, 1))x\(max(asset.pixelHeight / 400, 1))"
        return "\(kind.rawValue)-\(bucket)-\(dimensionBucket)"
    }

    private func qualityScore(for asset: PHAsset, kind: MediaKind) -> Double {
        switch kind {
        case .screenshot:
            return 0.95
        case .video, .sloMo:
            if asset.pixelHeight >= 2_160 || asset.pixelWidth >= 3_840 {
                return 0.96
            }
            if asset.pixelHeight >= 1_080 || asset.pixelWidth >= 1_920 {
                return 0.84
            }
            return 0.56
        case .photo, .burst, .livePhoto:
            let baseline = Double(max(asset.pixelWidth * asset.pixelHeight, 1)) / 12_000_000.0
            return min(max(baseline, 0.28), 0.98)
        }
    }

    private func fallbackName(for kind: MediaKind, createdAt: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return "\(kind.rawValue)-\(formatter.string(from: createdAt))"
    }
    #endif
}

public struct DeviceContactsCleanupService: ContactsCleanupServiceProtocol {
    public init() {}

    public func loadContacts(scope: ScanScope) async throws -> [ContactRecord] {
        guard scope.includesContacts else {
            return []
        }

        #if canImport(Contacts)
        let contactStore = CNContactStore()
        let granted = try await requestContactsAccessIfNeeded(using: contactStore)
        guard granted else {
            return []
        }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [ContactRecord] = []

        try contactStore.enumerateContacts(with: request) { contact, _ in
            contacts.append(
                ContactRecord(
                    id: contact.identifier,
                    fullName: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines),
                    email: contact.emailAddresses.first?.value as String?,
                    phoneNumber: contact.phoneNumbers.first?.value.stringValue
                )
            )
        }

        return contacts
        #else
        return []
        #endif
    }

    public func mergeSuggestions(from contacts: [ContactRecord]) -> [ContactMergeSuggestion] {
        ContactsCleanupService().mergeSuggestions(from: contacts)
    }

    #if canImport(Contacts)
    private func requestContactsAccessIfNeeded(using store: CNContactStore) async throws -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            return false
        }
    }
    #endif
}
