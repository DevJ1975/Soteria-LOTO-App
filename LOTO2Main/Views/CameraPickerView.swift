//
//  CameraPickerView.swift
//  LOTO2Main
//
//  Wraps UIImagePickerController in a SwiftUI sheet for live camera capture.
//  Locks to landscape orientation (matching the placard layout).
//  Falls back gracefully on simulator where camera is unavailable.
//

import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {

    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = LandscapeImagePicker()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.cameraFlashMode = .auto   // Flash available via built-in camera controls
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Landscape-locked picker subclass (#3)

    private class LandscapeImagePicker: UIImagePickerController {
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
        override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
