//
//  LOTO2MainApp.swift
//  LOTO2Main
//
//  App entry point. Bootstraps PlacardViewModel into the SwiftUI environment.
//  No Microsoft/MSAL dependencies — uses Supabase for data and storage.
//

import SwiftUI

@main
struct LOTO2MainApp: App {

    @State private var placardVM    = PlacardViewModel()
    @State private var showSplash   = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(placardVM)
                    .preferredColorScheme(.light)

                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .zIndex(1)
                    .transition(.opacity)
                }
            }
            .task {
                await placardVM.loadEquipment()
                placardVM.startNetworkSync()
            }
        }
    }
}
