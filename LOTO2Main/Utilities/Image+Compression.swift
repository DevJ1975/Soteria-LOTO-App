//
//  Image+Compression.swift
//  LOTO2Main
//
//  JPEG compression with EXIF stripping and 1 MB size budget enforcement.
//  Falls back to progressive pixel downscaling if quality reduction alone
//  cannot bring the image under the byte limit.
//

import UIKit

extension UIImage {

    /// Returns JPEG-compressed data targeting ≤ `maxBytes` (default 1 MB).
    /// Strips EXIF metadata and normalises pixel orientation first.
    /// Falls back to pixel downscaling if quality reduction alone isn't enough.
    func compressedJPEG(preferredQuality: CGFloat = 0.7, maxBytes: Int = 1_048_576) -> Data? {
        // Re-render strips EXIF and normalises orientation.
        guard let clean = redrawStrippingExif(scale: 1) else { return nil }

        // Happy path: preferred quality already within budget.
        if let data = clean.jpegData(compressionQuality: preferredQuality),
           data.count <= maxBytes {
            return data
        }

        // Phase 1 — binary search over quality (keeps full resolution).
        if let data = bestQuality(for: clean, maxBytes: maxBytes) {
            return data
        }

        // Phase 2 — progressive pixel downscale when quality alone isn't enough.
        // Halve pixel dimensions up to 3 times (1/2, 1/4, 1/8 of original area).
        var candidate = clean
        for _ in 0..<3 {
            let newSize = CGSize(width: candidate.size.width  / 2,
                                 height: candidate.size.height / 2)
            guard newSize.width > 100, newSize.height > 100 else { break }
            guard let scaled = candidate.redrawStrippingExif(size: newSize, scale: 1) else { break }
            candidate = scaled
            if let data = bestQuality(for: scaled, maxBytes: maxBytes) { return data }
        }

        // Last resort: minimum quality at the smallest size tried.
        return candidate.jpegData(compressionQuality: 0.1)
    }

    // MARK: - Private

    /// Binary search over quality 0.1–preferredQuality, returns best fit or nil.
    private func bestQuality(for image: UIImage,
                              maxBytes: Int,
                              preferredQuality: CGFloat = 0.7) -> Data? {
        var lo: CGFloat = 0.1
        var hi: CGFloat = preferredQuality
        var best: Data?
        for _ in 0..<8 {
            let mid = (lo + hi) / 2
            guard let data = image.jpegData(compressionQuality: mid) else { break }
            if data.count <= maxBytes { best = data; lo = mid } else { hi = mid }
        }
        return best
    }

    /// Redraws into a fresh bitmap, stripping EXIF and normalising orientation.
    /// Uses UIGraphicsImageRenderer (non-deprecated, correct colour space).
    private func redrawStrippingExif(size targetSize: CGSize? = nil, scale: CGFloat = 1) -> UIImage? {
        let drawSize = targetSize ?? self.size
        guard drawSize.width > 0, drawSize.height > 0 else { return nil }
        let format        = UIGraphicsImageRendererFormat.default()
        format.scale      = scale
        format.opaque     = false
        return UIGraphicsImageRenderer(size: drawSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: drawSize))
        }
    }
}
