//
//  SignatureCanvasView.swift
//  LOTO2Main
//
//  A finger-drawn signature pad backed by a UIView for reliable iPad touch handling.
//  Strokes are captured in real-time and exported as a UIImage via onSigned callback.
//
//  Scroll-freezing: on touchesBegan the canvas walks up the view hierarchy and
//  disables isScrollEnabled on every parent UIScrollView so SwiftUI Form /
//  UICollectionView / UITableView can't intercept the drawing gesture.
//  Scrolling is restored the moment the stroke ends or is cancelled.
//

import SwiftUI
import UIKit

// MARK: - SignatureCanvasView (SwiftUI wrapper)

struct SignatureCanvasView: UIViewRepresentable {

    /// Called whenever the signature changes (nil = canvas cleared or empty).
    var onSigned: (UIImage?) -> Void

    func makeUIView(context: Context) -> SignaturePadUIView {
        let pad = SignaturePadUIView()
        pad.onSignatureChanged = onSigned
        return pad
    }

    func updateUIView(_ uiView: SignaturePadUIView, context: Context) {}
}

// MARK: - SignaturePadUIView

final class SignaturePadUIView: UIView {

    var onSignatureChanged: ((UIImage?) -> Void)?

    private var strokes: [[CGPoint]] = []
    private var currentStroke: [CGPoint] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 10
        clipsToBounds = true
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Scroll-freeze helpers

    /// Walk the superview chain and set isScrollEnabled on every UIScrollView found.
    /// SwiftUI Form uses a UICollectionView (a UIScrollView subclass) — disabling it
    /// while a stroke is in progress prevents the form from intercepting the pan gesture.
    private func setParentScrollsEnabled(_ enabled: Bool) {
        var view: UIView? = superview
        while let v = view {
            if let scrollView = v as? UIScrollView {
                scrollView.isScrollEnabled = enabled
            }
            view = v.superview
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self) else { return }
        setParentScrollsEnabled(false)   // lock the Form so it can't scroll under our finger
        currentStroke = [pt]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self) else { return }
        currentStroke.append(pt)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self) else {
            setParentScrollsEnabled(true)
            return
        }
        currentStroke.append(pt)
        strokes.append(currentStroke)
        currentStroke = []
        setNeedsDisplay()
        onSignatureChanged?(isEmpty ? nil : toImage())
        setParentScrollsEnabled(true)    // restore scrolling after stroke completes
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentStroke = []
        setNeedsDisplay()
        setParentScrollsEnabled(true)    // always restore, even if stroke was cancelled
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(rect)

        UIColor.black.setStroke()
        let allStrokes = strokes + (currentStroke.isEmpty ? [] : [currentStroke])
        for stroke in allStrokes {
            guard stroke.count > 1 else { continue }
            let path = UIBezierPath()
            path.lineWidth     = 2.0
            path.lineCapStyle  = .round
            path.lineJoinStyle = .round
            path.move(to: stroke[0])
            for pt in stroke.dropFirst() { path.addLine(to: pt) }
            path.stroke()
        }

        // Baseline guide
        UIColor(white: 0.85, alpha: 1).setStroke()
        let guide = UIBezierPath()
        guide.lineWidth = 0.5
        let baseY = rect.maxY - 14
        guide.move(to: CGPoint(x: rect.minX + 8, y: baseY))
        guide.addLine(to: CGPoint(x: rect.maxX - 8, y: baseY))
        guide.stroke()

        // "Sign here" placeholder if empty
        if isEmpty {
            let attr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 13),
                .foregroundColor: UIColor(white: 0.75, alpha: 1)
            ]
            let text = "Sign here"
            let ts = text.size(withAttributes: attr)
            text.draw(at: CGPoint(x: (rect.width - ts.width) / 2,
                                  y: baseY - ts.height - 4),
                      withAttributes: attr)
        }
    }

    // MARK: - Public API

    var isEmpty: Bool { strokes.isEmpty }

    func clear() {
        strokes       = []
        currentStroke = []
        setNeedsDisplay()
        onSignatureChanged?(nil)
    }

    /// Renders all strokes into a white-background UIImage at the view's current size.
    func toImage() -> UIImage? {
        guard !isEmpty else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in self.draw(bounds) }
    }
}
