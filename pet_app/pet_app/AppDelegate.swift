//
//  AppDelegate.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var keepOnTopTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon and Cmd+Tab
        NSApp.setActivationPolicy(.accessory)
        
        // Get main screen - use visibleFrame for fullscreen-like behavior
        guard let mainScreen = NSScreen.main else { return }
        
        // Use visibleFrame which gives us the fullscreen area (excluding menu bar/dock)
        // For true fullscreen coverage, use frame instead
        let screenFrame = mainScreen.frame
        
        // Create the SwiftUI view
        let contentView = OverlayView()
        
        // Create the window with fullscreen size
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties for full transparency
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        // Set window level to floating to stay on top
        window.level = .floating
        
        // Collection behavior for fullscreen-like overlay
        window.collectionBehavior = [
            .fullScreenAuxiliary,     // Appear above fullscreen apps
            .canJoinAllSpaces,        // Appear on all Spaces
            .stationary,              // Don't move with Spaces
            .ignoresCycle             // Don't appear in window cycling
        ]
        
        // Make window ignore mouse events (click-through)
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.isMovableByWindowBackground = false
        
        // Set content view
        window.contentView = NSHostingView(rootView: contentView)
        
        // Position window to cover full screen
        window.setFrame(screenFrame, display: true)
        
        // Make window visible and ensure it's on top
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        self.window = window
        
        // Periodically ensure window stays on top
        keepOnTopTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak window] _ in
            window?.orderFrontRegardless()
        }
        
        // Monitor for application activation to keep overlay on top
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        window?.orderFrontRegardless()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keepOnTopTimer?.invalidate()
        keepOnTopTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        keepOnTopTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}