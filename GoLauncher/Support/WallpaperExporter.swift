import Photos
import SwiftUI
import UIKit

/// Saves your Go background as an iPhone wallpaper, so the real Home Screen behind Go's
/// widgets matches the Go app.
enum WallpaperExporter {
    /// The theme's background (gradient, photo or built-in wallpaper, dimming) at full screen resolution.
    @MainActor
    static func render(theme: Theme, store: LauncherStore) -> UIImage? {
        let screen = UIScreen.main
        let size = screen.bounds.size
        let image = WallpaperView.image(theme: theme, store: store)
        let content = ZStack {
            LinearGradient(
                colors: [Color(hex: theme.backgroundTopHex), Color(hex: theme.backgroundBottomHex)],
                startPoint: .top,
                endPoint: .bottom
            )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .saturation(1.18)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                if theme.wallpaperDim > 0 { Color.black.opacity(theme.wallpaperDim) }
            }
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = screen.scale
        return renderer.uiImage
    }

    enum SaveResult { case saved, denied, failed }

    /// Adds the image to Photos (asks for add-only access the first time).
    static func saveToPhotos(_ image: UIImage) async -> SaveResult {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return .saved
        } catch {
            return .failed
        }
    }
}
