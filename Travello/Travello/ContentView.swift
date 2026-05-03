//
//  ContentView.swift
//  Travello
//
//  Created by Daria Shmygovskaya on 28/04/2026.
//

import SwiftUI

// ContentView не используется напрямую — точка входа это TravelloApp → RootView.
// Оставляем для Preview.
struct ContentView: View {
    var body: some View {
        RootView()
            .environmentObject(AppState())
    }
}

#Preview {
    ContentView()
}
