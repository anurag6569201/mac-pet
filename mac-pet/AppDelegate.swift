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
        
        // Get all screens and calculate combined frame
        let screens = NSScreen.screens
        guard let mainScreen = NSScreen.main else { return }
        
        // Calculate frame covering all screens
        var combinedFrame = mainScreen.frame
        for screen in screens {
            combinedFrame = combinedFrame.union(screen.frame)
        }
        
        // Create the SwiftUI view
        let contentView = OverlayView()
        
        // Create the window covering all screens
        let window = NSWindow(
            contentRect: combinedFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties for full transparency
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        // Set window level to the highest possible level to ensure it's always on top
        // Using a custom level higher than screenSaver (1000) to be above everything
        let screenSaverLevel = Int(CGWindowLevelForKey(.screenSaverWindow))
        window.level = NSWindow.Level(rawValue: screenSaverLevel + 1)
        
        // Collection behavior for cross-space and fullscreen support
        window.collectionBehavior = [
            .canJoinAllSpaces,        // Appear on all Spaces
            .fullScreenAuxiliary,     // Appear above fullscreen apps
            .stationary,              // Don't move with Spaces
            .ignoresCycle             // Don't appear in window cycling
        ]
        
        // Ensure window stays on top even when other windows are created
        window.orderFrontRegardless()
        
        // Make window ignore mouse events (click-through)
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.isMovableByWindowBackground = false
        
        // Set content view
        window.contentView = NSHostingView(rootView: contentView)
        
        // Position window to cover all screens
        window.setFrame(combinedFrame, display: true)
        
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
