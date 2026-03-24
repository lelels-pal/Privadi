import Foundation

public enum SampleData {
    public static let mediaAssets: [MediaAsset] = [
        MediaAsset(
            id: "1",
            name: "Kids Birthday Burst 1",
            kind: .burst,
            byteSize: 18_000_000,
            checksum: "dup-a",
            similarityKey: "party-a",
            qualityScore: 0.81,
            width: 3024,
            height: 4032,
            createdAt: .now.addingTimeInterval(-20_000)
        ),
        MediaAsset(
            id: "2",
            name: "Kids Birthday Burst 2",
            kind: .burst,
            byteSize: 17_500_000,
            checksum: "dup-a",
            similarityKey: "party-a",
            qualityScore: 0.42,
            eyeClosureScore: 0.91,
            width: 3024,
            height: 4032,
            createdAt: .now.addingTimeInterval(-19_000)
        ),
        MediaAsset(
            id: "3",
            name: "4K Drone Clip",
            kind: .video,
            byteSize: 240_000_000,
            similarityKey: "drone-1",
            qualityScore: 0.88,
            width: 3840,
            height: 2160,
            createdAt: .now.addingTimeInterval(-10_000)
        ),
        MediaAsset(
            id: "4",
            name: "Slow Motion Skate",
            kind: .sloMo,
            byteSize: 160_000_000,
            similarityKey: "skate-1",
            qualityScore: 0.74,
            width: 1920,
            height: 1080,
            createdAt: .now.addingTimeInterval(-9_500)
        ),
        MediaAsset(
            id: "5",
            name: "Screenshot Receipt",
            kind: .screenshot,
            byteSize: 3_500_000,
            qualityScore: 0.95,
            width: 1170,
            height: 2532,
            createdAt: .now.addingTimeInterval(-8_000)
        ),
        MediaAsset(
            id: "6",
            name: "Vacation Live",
            kind: .livePhoto,
            byteSize: 125_000_000,
            similarityKey: "trip-1",
            qualityScore: 0.89,
            width: 3024,
            height: 4032,
            createdAt: .now.addingTimeInterval(-7_500)
        ),
        MediaAsset(
            id: "7",
            name: "Budget Pro Headshot",
            kind: .photo,
            byteSize: 7_500_000,
            similarityKey: "profile-a",
            qualityScore: 0.31,
            width: 720,
            height: 720,
            createdAt: .now.addingTimeInterval(-5_000)
        ),
        MediaAsset(
            id: "8",
            name: "Budget Pro Headshot 2",
            kind: .photo,
            byteSize: 7_500_000,
            similarityKey: "profile-a",
            qualityScore: 0.87,
            width: 3024,
            height: 4032,
            createdAt: .now.addingTimeInterval(-4_500)
        ),
    ]

    public static let contacts: [ContactRecord] = [
        ContactRecord(id: "c1", fullName: "Maya Santos", email: "maya@example.com", phoneNumber: "09171234567"),
        ContactRecord(id: "c2", fullName: "Maya Santos", email: nil, phoneNumber: "09171234567"),
        ContactRecord(id: "c3", fullName: "Family Doctor", email: "clinic@example.com", phoneNumber: nil),
        ContactRecord(id: "c4", fullName: "Courier", email: nil, phoneNumber: nil),
    ]
}
