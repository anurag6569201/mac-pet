//
//  AppDelegate.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlaysBySpace: [Int: NSWindow] = [:] // Maps space index to overlay window
    var keepOnTopTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start Yabai verification sequence
        YabaiAutomation.shared.startVerification()
        
        // Hide dock icon and Cmd+Tab
        NSApp.setActivationPolicy(.accessory)
        
        // Set up space change monitoring
        YabaiAutomation.shared.onSpaceChanged = { [weak self] in
            self?.handleSpaceChange()
        }
        
        // Create overlay for current desktop only
        createOverlayForCurrentDesktop()
        
        // Periodically ensure windows stay on top
        keepOnTopTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.overlaysBySpace.values.forEach { $0.orderFrontRegardless() }
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
        overlaysBySpace.values.forEach { $0.orderFrontRegardless() }
    }
    
    // MARK: - Space Change Handling
    
    private func handleSpaceChange() {
        // Small delay to ensure space change is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.createOverlayForCurrentDesktop()
        }
    }
    
    private func createOverlayForCurrentDesktop() {
        // Get current space
        guard let currentSpaceIndex = getCurrentSpaceIndex() else {
            print(" [Overlay] Could not get current space index")
            return
        }
        
        // Check if overlay already exists for this space
        if overlaysBySpace[currentSpaceIndex] != nil {
            print(" [Overlay] Overlay already exists for space \(currentSpaceIndex), skipping")
            return
        }
        
        print(" [Overlay] Creating overlay for space \(currentSpaceIndex)")
        
        // Get all spaces to calculate desktop count
        let spaces = YabaiAutomation.shared.getAllSpaces()
        let desktopCount = spaces.count
        
        // Get main screen
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame
        
        // Calculate xOffset for this desktop
        let desktopIndex = currentSpaceIndex - 1
        let screenWidth = screenFrame.width
        let xOffset = -CGFloat(desktopIndex) * screenWidth
        
        // Create the SwiftUI view
        let contentView = OverlayView(desktopCount: desktopCount, xOffset: xOffset)
        
        // Create window on current space
        createOverlayWindow(
            spaceIndex: currentSpaceIndex,
            contentView: contentView,
            screenFrame: screenFrame
        )
    }
    
    private func createOverlayWindow(spaceIndex: Int, contentView: OverlayView, screenFrame: CGRect) {
        // Create window
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Set a unique title
        window.title = "mac-pet-overlay-space-\(spaceIndex)"
        
        // Configure window properties for full transparency
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        // Set window level to floating to stay on top
        window.level = .floating
        
        // Collection behavior - window stays on its specific desktop
        window.collectionBehavior = [
            .fullScreenAuxiliary,     // Appear above fullscreen apps
            .ignoresCycle             // Don't appear in window cycling
        ]
        // Note: Without .canJoinAllSpaces, window stays on the desktop where it was created
        
        window.isMovable = false
        window.isMovableByWindowBackground = false
        
        // Make click-through immediately
        window.ignoresMouseEvents = true
        
        // Set content view
        window.contentView = NSHostingView(rootView: contentView)
        
        // Position window
        window.setFrame(screenFrame, display: true)
        
        // Make window visible and ensure it's on top
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Store window for this space
        overlaysBySpace[spaceIndex] = window
        print(" [Overlay] ✓ Created overlay for space \(spaceIndex)")
    }
    
    private func getCurrentSpaceIndex() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yabai")
        process.arguments = ["-m", "query", "--spaces"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let jsonString = String(data: data, encoding: .utf8),
               let jsonData = jsonString.data(using: .utf8),
               let spaces = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                if let activeSpace = spaces.first(where: { ($0["has-focus"] as? Bool) == true }),
                   let index = activeSpace["index"] as? Int {
                    return index
                }
            }
        } catch {
            print(" [SpaceSwitch] Error getting current space: \(error)")
        }
        return nil
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
