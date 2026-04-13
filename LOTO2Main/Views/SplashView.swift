//
//  SplashView.swift
//  LOTO2Main
//
//  Animated launch screen shown while the app boots and loads cached data.
//  Logo fades + scales in, then the screen slides up to reveal the main UI.
//

import SwiftUI

struct SplashView: View {

    @State private var logoScale:   CGFloat = 0.4
    @State private var logoOpacity: Double  = 0
    @State private var tagOpacity:  Double  = 0
    @State private var slideUp:     CGFloat = 0

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background gradient matching brand colours
            LinearGradient.brandHeader
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo
                Image("SnakKingLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // App title
                VStack(spacing: 6) {
                    Text("LOTO Placard Generator")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Lockout / Tagout Procedure")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(tagOpacity)
            }
        }
        .offset(y: slideUp)
        .onAppear { animate() }
    }

    private func animate() {
        // Phase 1 — logo bounces in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }

        // Phase 2 — tagline fades in
        withAnimation(.easeIn(duration: 0.4).delay(0.45)) {
            tagOpacity = 1.0
        }

        // Phase 3 — whole screen slides up and disappears
        withAnimation(.easeInOut(duration: 0.5).delay(1.4)) {
            slideUp = -UIScreen.main.bounds.height
        }

        // Notify parent after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            onFinished()
        }
    }
}
