import Foundation
import Photos
import GoalsDomain

#if canImport(UIKit)
import UIKit
#endif

/// Service to backfill thumbnails for existing nutrition entries
public actor ThumbnailBackfillService {
    private static let backfillCompletedKey = "nutritionThumbnailBackfillCompleted"

    private let nutritionRepository: NutritionRepositoryProtocol

    public init(nutritionRepository: NutritionRepositoryProtocol) {
        self.nutritionRepository = nutritionRepository
    }

    /// Performs one-time backfill of thumbnails for entries that don't have them
    public func backfillIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: Self.backfillCompletedKey) else {
            return
        }

        do {
            let entries = try await nutritionRepository.fetchAllEntries()
            let entriesWithoutThumbnails = entries.filter { $0.thumbnailData == nil }

            guard !entriesWithoutThumbnails.isEmpty else {
                UserDefaults.standard.set(true, forKey: Self.backfillCompletedKey)
                return
            }

            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized || status == .limited else { return }

            for entry in entriesWithoutThumbnails {
                if let thumbnail = await loadThumbnail(for: entry.photoAssetId) {
                    let newEntry = NutritionEntry(
                        id: entry.id,
                        date: entry.date,
                        photoAssetId: entry.photoAssetId,
                        thumbnailData: thumbnail,
                        name: entry.name,
                        portionMultiplier: entry.portionMultiplier,
                        baseNutrients: entry.baseNutrients,
                        source: entry.source,
                        confidence: entry.confidence,
                        hasNutritionLabel: entry.hasNutritionLabel,
                        createdAt: entry.createdAt,
                        updatedAt: entry.updatedAt
                    )
                    _ = try? await nutritionRepository.updateEntry(newEntry)
                }
            }

            UserDefaults.standard.set(true, forKey: Self.backfillCompletedKey)
        } catch {
            // Will retry on next launch
        }
    }

    private func loadThumbnail(for assetId: String) async -> Data? {
        #if canImport(UIKit)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 200, height: 200)

        return await withCheckedContinuation { continuation in
            var hasResumed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }

                hasResumed = true
                continuation.resume(returning: image?.jpegData(compressionQuality: 0.7))
            }
        }
        #else
        return nil
        #endif
    }
}
