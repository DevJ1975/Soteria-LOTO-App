//
//  Image+Compression.swift
//  LOTO2Main
//
//  JPEG compression with EXIF stripping and 1 MB size budget enforcement.
//

import UIKit

extension UIImage {

    /// Returns JPEG-compressed data with EXIF stripped, targeting ≤ 1 MB.
    ///
    /// - Parameters:
    ///   - preferredQuality: Starting JPEG quality (0–1). Defaults to 0.7.
    ///   - maxBytes: Hard byte limit. Defaults to 1 048 576 (1 MB).
    func compressedJPEG(preferredQuality: CGFloat = 0.7, maxBytes: Int = 1_048_576) -> Data? {
        // Re-render to strip all EXIF metadata and normalise pixel orientation.
        guard let clean = redrawStrippingExif() else { return nil }

        // Happy path: preferred quality fits within the budget.
        if let data = clean.jpegData(compressionQuality: preferredQuality),
           data.count <= maxBytes {
            return data
        }

        // Binary search for the highest quality that still fits.
        var lo: CGFloat = 0.1
        var hi: CGFloat = preferredQuality
        var best: Data?

        for _ in 0..<8 {
            let mid = (lo + hi) / 2
            guard let data = clean.jpegData(compressionQuality: mid) else { break }
            if data.count <= maxBytes { best = data; lo = mid }
            else { hi = mid }
        }

        return best ?? clean.jpegData(compressionQuality: 0.1)
    }

    // MARK: - Private

    private func redrawStrippingExif() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
