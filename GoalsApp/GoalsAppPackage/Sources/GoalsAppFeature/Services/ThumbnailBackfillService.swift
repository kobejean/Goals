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
        // Check if already completed
        guard !UserDefaults.standard.bool(forKey: Self.backfillCompletedKey) else {
            return
        }

        do {
            let entries = try await nutritionRepository.fetchAllEntries()
            let entriesWithoutThumbnails = entries.filter { $0.thumbnailData == nil }

            guard !entriesWithoutThumbnails.isEmpty else {
                // No entries need backfill, mark as complete
                UserDefaults.standard.set(true, forKey: Self.backfillCompletedKey)
                return
            }

            // Request photo library access
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized || status == .limited else {
                // Can't access photos, will retry next launch
                return
            }

            var successCount = 0
            for entry in entriesWithoutThumbnails {
                if let thumbnail = await loadThumbnail(for: entry.photoAssetId) {
                    // Create new entry with thumbnail (thumbnailData is let, so we need to create new)
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
                    if (try? await nutritionRepository.updateEntry(newEntry)) != nil {
                        successCount += 1
                    }
                }
            }

            print("📸 Thumbnail backfill: \(successCount)/\(entriesWithoutThumbnails.count) entries updated")

            // Mark as complete even if some failed (they may have been deleted from Photo Library)
            UserDefaults.standard.set(true, forKey: Self.backfillCompletedKey)

        } catch {
            print("⚠️ Thumbnail backfill failed: \(error.localizedDescription)")
            // Don't mark as complete so we can retry
        }
    }

    /// Loads a thumbnail for a photo asset ID
    private func loadThumbnail(for assetId: String) async -> Data? {
        #if canImport(UIKit)
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else {
            return nil
        }

        // Request thumbnail image
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 200, height: 200)

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Check if this is the final result (not a degraded placeholder)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }

                guard let image = image else {
                    continuation.resume(returning: nil)
                    return
                }

                // Convert to JPEG data
                let jpegData = image.jpegData(compressionQuality: 0.7)
                continuation.resume(returning: jpegData)
            }
        }
        #else
        return nil
        #endif
    }
}
