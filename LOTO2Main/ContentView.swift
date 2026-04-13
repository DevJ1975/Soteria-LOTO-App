//
//  ContentView.swift
//  LOTO2Main
//
//  Root view — opens directly to the equipment list.
//  No authentication required.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        EquipmentListView()
    }
}

#Preview {
    ContentView()
        .environment(PlacardViewModel())
}
