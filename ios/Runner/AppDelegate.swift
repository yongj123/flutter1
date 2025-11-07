import UIKit
import Flutter
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var photoCleaner: SimilarPhotoCleaner?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    let photoChannel = FlutterMethodChannel(name: "com.example.photoCleaner",
                                            binaryMessenger: controller.binaryMessenger)

    photoChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in

      switch call.method {
      case "findSimilarPhotos":
        self?.findSimilarPhotos(result: result)
      case "deletePhotos":
        self?.deletePhotos(call: call, result: result)
      case "recommendBestPhoto":
        self?.recommendBestPhoto(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func findSimilarPhotos(result: @escaping FlutterResult) {
      photoCleaner = SimilarPhotoCleaner()
      Task {
        do {
            let groups = try await photoCleaner?.findSimilarPhotos()
            let flutterGroups = groups?.map { group -> [String: Any] in
                return [
                    "bestPhotoIdentifier": group.bestPhoto?.localIdentifier ?? "",
                    "reason": group.reason ?? "",
                    "photoIdentifiers": group.photos.map { $0.localIdentifier },
                    "totalSize": group.totalSize
                ]
            }
            result(flutterGroups)
        } catch {
            result(FlutterError(code: "ERROR",
                                message: error.localizedDescription,
                                details: nil))
        }
      }
  }

  private func deletePhotos(call: FlutterMethodCall, result: @escaping FlutterResult) {
      guard let args = call.arguments as? [String: Any], let identifiers = args["identifiers"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for deletePhotos", details: nil))
          return
      }

      let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
      PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.deleteAssets(assets)
      }, completionHandler: { success, error in
          if success {
              result(nil)
          } else {
              result(FlutterError(code: "DELETE_FAILED", message: error?.localizedDescription ?? "Failed to delete assets", details: nil))
          }
      })
  }

  private func recommendBestPhoto(call: FlutterMethodCall, result: @escaping FlutterResult) {
      guard let args = call.arguments as? [String: Any], let identifiers = args["identifiers"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for recommendBestPhoto", details: nil))
          return
      }

      let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
      var assetArray: [PHAsset] = []
      assets.enumerateObjects { (asset, _, _) in
          assetArray.append(asset)
      }

      if photoCleaner == nil {
          photoCleaner = SimilarPhotoCleaner()
      }

      Task {
          do {
              let bestPhoto = try await photoCleaner?.recommendBestPhoto(in: assetArray)
              result(bestPhoto?.localIdentifier)
          } catch {
              result(FlutterError(code: "RECOMMEND_FAILED", message: error.localizedDescription, details: nil))
          }
      }
  }
}
