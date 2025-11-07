import Foundation
import Photos
import Vision
import ImageIO
import CommonCrypto

// MARK: - Data Structures
struct SimilarPhotoGroup {
    let photos: [PHAsset]
    var bestPhoto: PHAsset? // Optional: To be calculated on demand
    var reason: String?     // Optional: To be calculated on demand
    let totalSize: Int64
}

// MARK: - Main Cleaner Class
class SimilarPhotoCleaner {
    // lowResAnalysisSize has been removed

    // MARK: - Public API

    public func findSimilarPhotos() async throws -> [SimilarPhotoGroup] {
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        print("Photo Cleaner: Starting scan...")

        guard await requestPhotoLibraryAuthorization() else {
            throw PhotoError.authorizationDenied
        }

        let fetchStartTime = CFAbsoluteTimeGetCurrent()
        let allPhotos = fetchAllPhotos()
        let fetchTime = CFAbsoluteTimeGetCurrent() - fetchStartTime
        print(String(format: "Photo Cleaner: Fetched %d photos in %.3f seconds.", allPhotos.count, fetchTime))

        let groupingStartTime = CFAbsoluteTimeGetCurrent()
        let photoGroups = groupPhotosByTimeAndLocation(photos: allPhotos)
        let groupingTime = CFAbsoluteTimeGetCurrent() - groupingStartTime
        print(String(format: "Photo Cleaner: Metadata pre-processing created %d groups in %.3f seconds.", photoGroups.count, groupingTime))

        let similarities = try await findSimilarities(in: photoGroups)

        let totalTime = CFAbsoluteTimeGetCurrent() - totalStartTime
        print(String(format: "Photo Cleaner: Scan finished in %.3f seconds. Found %d similar groups.", totalTime, similarities.count))

        return similarities
    }

    // MARK: - Step 1 & 2: Fetch and Pre-filter

    private func requestPhotoLibraryAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    private func fetchAllPhotos() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var assets = [PHAsset]()
        fetchResult.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        return assets
    }

    private func groupPhotosByTimeAndLocation(photos: [PHAsset], timeInterval: TimeInterval = 180) -> [[PHAsset]] {
        guard !photos.isEmpty else { return [] }

        var groups: [[PHAsset]] = []
        var currentGroup: [PHAsset] = [photos.first!]

        for i in 1..<photos.count {
            let previousAsset = photos[i-1]
            let currentAsset = photos[i]

            let timeDifference = currentAsset.creationDate!.timeIntervalSince(previousAsset.creationDate!)

            if timeDifference <= timeInterval && assetsHaveSimilarLocation(asset1: previousAsset, asset2: currentAsset) {
                currentGroup.append(currentAsset)
            } else {
                if currentGroup.count > 1 {
                    groups.append(currentGroup)
                }
                currentGroup = [currentAsset]
            }
        }

        if currentGroup.count > 1 {
            groups.append(currentGroup)
        }

        return groups
    }

    private func assetsHaveSimilarLocation(asset1: PHAsset, asset2: PHAsset, distanceThreshold: CLLocationDistance = 50.0) -> Bool {
        guard let loc1 = asset1.location, let loc2 = asset2.location else {
            return true
        }
        return loc1.distance(from: loc2) <= distanceThreshold
    }

    // MARK: - Step 3: Vision Feature Vector Similarity

    private func findSimilarities(in photoGroups: [[PHAsset]]) async throws -> [SimilarPhotoGroup] {
        var finalSimilarGroups: [SimilarPhotoGroup] = []
        let processStartTime = CFAbsoluteTimeGetCurrent()

        for (index, group) in photoGroups.enumerated() {
            let groupStartTime = CFAbsoluteTimeGetCurrent()

            do {
                let hashStartTime = CFAbsoluteTimeGetCurrent()
                let uniqueAssets = await deduplicateWithFileHash(assets: group)
                let hashTime = CFAbsoluteTimeGetCurrent() - hashStartTime
                if uniqueAssets.count <= 1 { continue }
                print(String(format: "  [Group %d] Hash deduplication reduced %d photos to %d in %.3f seconds.", index + 1, group.count, uniqueAssets.count, hashTime))

                // --- TASK ISOLATION ---
                let visionTask = Task.detached { () -> [SimilarPhotoGroup]? in
                    let featureStartTime = CFAbsoluteTimeGetCurrent()
                    let featurePrints = await self.getFeaturePrints(for: uniqueAssets, useLowResolution: true)
                    let featureTime = CFAbsoluteTimeGetCurrent() - featureStartTime
                    if featurePrints.count <= 1 { return nil }
                    print(String(format: "    [Isolated Task] Low-res Vision feature extraction for %d photos took %.3f seconds.", featurePrints.count, featureTime))

                    let similarityMatrix = try self.calculateSimilarity(featurePrints)
                    let connectedComponents = self.findConnectedComponents(in: similarityMatrix, assets: Array(featurePrints.keys))

                    var taskResults = [SimilarPhotoGroup]()
                    for component in connectedComponents where component.count > 1 {
                        // BEST PHOTO CALCULATION IS NOW DELAYED
                        // Instead of calculating the best photo here, we create the group without it.
                        // The UI will call the public recommendBestPhoto function on demand.
                        let totalSize = await self.calculateTotalSize(for: component)
                        taskResults.append(SimilarPhotoGroup(photos: component, bestPhoto: nil, reason: nil, totalSize: totalSize))
                    }
                    return taskResults
                }

                let visionResults = try await visionTask.value
                if let newGroups = visionResults {
                    finalSimilarGroups.append(contentsOf: newGroups)
                }
                // --- END TASK ISOLATION ---

            } catch {
                print(String(format: "  [Group %d] ERROR: An unexpected error occurred: \(error.localizedDescription). Skipping this group.", index + 1))
            }
            let groupTime = CFAbsoluteTimeGetCurrent() - groupStartTime
            print(String(format: "  [Group %d] Total processing time: %.3f seconds.", index + 1, groupTime))
        }
        let processTime = CFAbsoluteTimeGetCurrent() - processStartTime
        print(String(format: "Photo Cleaner: Total similarity processing time for all groups: %.3f seconds.", processTime))

        return finalSimilarGroups
    }

    private func getFeaturePrints(for assets: [PHAsset], useLowResolution: Bool) async -> [PHAsset: VNFeaturePrintObservation] {
        var results = [PHAsset: VNFeaturePrintObservation]()
        let batchSize = 4 // Process in smaller batches to avoid memory overload

        for i in stride(from: 0, to: assets.count, by: batchSize) {
            let batch = Array(assets[i..<min(i + batchSize, assets.count)])

            await withTaskGroup(of: (PHAsset, VNFeaturePrintObservation?).self) { group in
                for asset in batch {
                    group.addTask {
                        let observation = await self.generateFeaturePrint(for: asset, useLowResolution: useLowResolution)
                        return (asset, observation)
                    }
                }

                for await (asset, observation) in group {
                    if let observation = observation {
                        results[asset] = observation
                    }
                }
            }
        }

        return results
    }

    private func generateFeaturePrint(for asset: PHAsset, useLowResolution: Bool) async -> VNFeaturePrintObservation? {
        let imageSize: CGSize
        if useLowResolution {
            // New rule: Scale image so the smallest side is 512px, preserving aspect ratio.
            let targetMinSide: CGFloat = 512
            let originalWidth = CGFloat(asset.pixelWidth)
            let originalHeight = CGFloat(asset.pixelHeight)

            if originalWidth == 0 || originalHeight == 0 {
                 imageSize = CGSize(width: targetMinSide, height: targetMinSide) // Fallback
            } else if originalWidth < originalHeight {
                let scale = targetMinSide / originalWidth
                imageSize = CGSize(width: targetMinSide, height: originalHeight * scale)
            } else {
                let scale = targetMinSide / originalHeight
                imageSize = CGSize(width: originalWidth * scale, height: targetMinSide)
            }
        } else {
            imageSize = PHImageManagerMaximumSize
        }

        guard let cgImage = await getImage(for: asset, with: imageSize)?.cgImage else {
            return nil
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return await withTimeout(seconds: 10.0) {
            do {
                try handler.perform([request])
                return request.results?.first as? VNFeaturePrintObservation
            } catch {
                return nil
            }
        } onTimeout: {
            print("      [generate] CRITICAL: Vision request for asset \(asset.localIdentifier) timed out. Skipping.")
            return nil
        }
    }

    // MARK: - Concurrency Tools

    private actor ContinuationState {
        var resumed = false
        func resume<T>(continuation: CheckedContinuation<T, Never>, with value: T) {
            if !resumed {
                resumed = true
                continuation.resume(returning: value)
            }
        }
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T, onTimeout: @escaping @Sendable () -> T) async -> T {
        let state = ContinuationState()

        return await withCheckedContinuation { continuation in
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                await state.resume(continuation: continuation, with: onTimeout())
            }

            Task {
                let result = await operation()
                await state.resume(continuation: continuation, with: result)
            }
        }
    }

    // MARK: - Vision & Similarity Logic

    private func calculateSimilarity(_ featurePrints: [PHAsset: VNFeaturePrintObservation], threshold: Float = 0.3) throws -> [Bool] {
        let assets = Array(featurePrints.keys)
        let n = assets.count
        var similarityMatrix = [Bool](repeating: false, count: n * n)

        for i in 0..<n {
            for j in (i + 1)..<n {
                guard let fp1 = featurePrints[assets[i]], let fp2 = featurePrints[assets[j]] else { continue }

                var distance: Float = 0.0
                try fp1.computeDistance(&distance, to: fp2)

                if distance < threshold {
                    similarityMatrix[i * n + j] = true
                    similarityMatrix[j * n + i] = true
                }
            }
        }
        return similarityMatrix
    }

    private func findConnectedComponents(in matrix: [Bool], assets: [PHAsset]) -> [[PHAsset]] {
        let n = assets.count
        guard n > 0 else { return [] }

        var visited = [Bool](repeating: false, count: n)
        var components: [[PHAsset]] = []

        for i in 0..<n {
            if !visited[i] {
                var currentComponent: [PHAsset] = []
                var stack = [i]
                visited[i] = true

                while !stack.isEmpty {
                    let u = stack.popLast()!
                    currentComponent.append(assets[u])

                    for v in 0..<n where matrix[u * n + v] && !visited[v] {
                        visited[v] = true
                        stack.append(v)
                    }
                }
                components.append(currentComponent)
            }
        }
        return components
    }

    // MARK: - File Hash Deduplication

    private func deduplicateWithFileHash(assets: [PHAsset]) async -> [PHAsset] {
        var uniqueHashes = Set<String>()
        var uniqueAssets = [PHAsset]()

        for asset in assets {
            if let hash = await getHash(for: asset) {
                if !uniqueHashes.contains(hash) {
                    uniqueHashes.insert(hash)
                    uniqueAssets.append(asset)
                }
            } else {
                uniqueAssets.append(asset)
            }
        }
        return uniqueAssets
    }

    private func getHash(for asset: PHAsset) async -> String? {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.version = .original
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                guard let data = data else {
                    if let error = info?[PHImageErrorKey] as? Error {
                        print("Photo Cleaner: Failed to get image data for hash calculation (asset: \(asset.localIdentifier)): \(error.localizedDescription)")
                    }
                    continuation.resume(returning: nil)
                    return
                }
                let hash = self.sha256(data: data)
                continuation.resume(returning: hash)
            }
        }
    }

    private func sha256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Step 4: Best Photo Recommendation (Now Public)

    public func recommendBestPhoto(in assets: [PHAsset]) async throws -> PHAsset {
        if let favorite = assets.first(where: { $0.isFavorite }) { return favorite }

        var scoredPhotos = [(asset: PHAsset, score: Double)]()
        for asset in assets {
            scoredPhotos.append((asset, await calculatePhotoScore(for: asset)))
        }

        return scoredPhotos.max(by: { $0.score < $1.score })?.asset ?? assets.first!
    }

    private func calculatePhotoScore(for asset: PHAsset) async -> Double {
        guard let cgImage = await getImage(for: asset, with: PHImageManagerMaximumSize)?.cgImage else { return 0.0 }

        async let clarity = calculateClarityScore(cgImage: cgImage)
        async let face = calculateFaceScore(cgImage: cgImage)
        let metadata = calculateMetadataScore(asset: asset)

        return await (clarity * 0.5) + (face * 0.3) + (metadata * 0.2)
    }

    private func calculateClarityScore(cgImage: CGImage) async -> Double {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            if let results = request.results as? [VNClassificationObservation],
               let bestResult = results.first(where: { $0.identifier == "well composed" }) {
                return Double(bestResult.confidence)
            }
        } catch {}
        return 0.5
    }

    private func calculateFaceScore(cgImage: CGImage) async -> Double {
        let request = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else { return 0.5 }
            let totalQuality = results.compactMap { $0.faceCaptureQuality }.reduce(0, +)
            return Double(totalQuality) / Double(results.count)
        } catch { return 0.3 }
    }

    private func calculateMetadataScore(asset: PHAsset) -> Double {
        var score = Double(asset.pixelWidth * asset.pixelHeight) / 10_000_000.0
        if asset.location != nil { score += 0.2 }
        if asset.mediaSubtypes.contains(.photoPanorama) { score += 0.1 }
        if asset.mediaSubtypes.contains(.photoHDR) { score += 0.1 }
        return min(max(score, 0.0), 1.0)
    }

    // MARK: - Utility

    private func calculateTotalSize(for assets: [PHAsset]) async -> Int64 {
        var totalSize: Int64 = 0
        for asset in assets {
            totalSize += await getAssetFileSize(asset: asset)
        }
        return totalSize
    }

    private func getAssetFileSize(asset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first,
              let unsignedInt64 = resource.value(forKey: "fileSize") as? CLong else {
            return 0
        }
        return Int64(unsignedInt64)
    }

    private func getImage(for asset: PHAsset, with size: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("Photo Cleaner: Failed to get image for asset \(asset.localIdentifier): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    enum PhotoError: Error, LocalizedError {
        case authorizationDenied
        var errorDescription: String? { "Photo library access was denied." }
    }
}
