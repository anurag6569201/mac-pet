//
//  pet_appApp.swift
//  pet_app
//
//  Created by Anurag singh on 22/01/26.
//

import SwiftUI

@main
struct pet_appApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows needed here as they are managed by AppDelegate
        Settings {
            EmptyView()
        }
    }
}

