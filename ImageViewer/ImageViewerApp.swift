//
//  ImageViewerApp.swift
//  ImageViewer
//
//  Created by Dorian Wang on 2025/11/25.
//

import SwiftUI

@main
struct ImageViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity,
                       minHeight: 600, idealHeight: 700, maxHeight: .infinity)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}