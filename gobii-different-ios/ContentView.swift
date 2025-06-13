//
//  ContentView.swift
//  gobii-different-ios
//
//  Created by Matt Greathouse on 6/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            VStack {
                TaskListView()
            }
            .padding()
            .navigationBarItems(leading: Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape")
            })
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
