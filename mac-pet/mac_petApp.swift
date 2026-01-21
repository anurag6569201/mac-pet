//
//  mac_petApp.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import SwiftUI

@main
struct mac_petApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
