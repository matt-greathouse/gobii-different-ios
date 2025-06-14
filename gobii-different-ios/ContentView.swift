//
//  ContentView.swift
//  gobii-different-ios
//
//  Created by Matt Greathouse on 6/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationView {
                TaskListView()
            }
            .tabItem {
                Label("Tasks", systemImage: "checkmark.circle")
            }
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}
