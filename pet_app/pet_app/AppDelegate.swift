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
        
        // Set up native space change monitoring
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        // Also keep Yabai listener as backup/complement (if needed for other things)
        YabaiAutomation.shared.onSpaceChanged = { [weak self] in
            self?.handleSpaceChange()
        }
        
        // Configure PetController with total world size
        if let mainScreen = NSScreen.main {
             let spaces = YabaiAutomation.shared.getAllSpaces()
             let desktopCount = max(spaces.count, 1)
             let totalWidth = mainScreen.frame.width * CGFloat(desktopCount)
             let worldSize = CGSize(width: totalWidth, height: mainScreen.frame.height)
             
             // Initialize the shared world once
             PetController.shared.configure(with: worldSize)
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
    
    @objc private func handleSpaceChange() {
        // Small delay to ensure space change is complete and isOnActiveSpace updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.createOverlayForCurrentDesktop()
        }
    }
    
    private func createOverlayForCurrentDesktop() {
        // 1. Logic: Check if WE already have a window on the active space.
        // filtering all our windows to find one that is on the active space
        let activeOverlay = overlaysBySpace.values.first { window in
            return window.isOnActiveSpace && window.isVisible
        }
        
        if let existing = activeOverlay {
            print(" [Overlay] Overlay already exists on active space. Window: \(existing.title). Skipping.")
            existing.orderFrontRegardless() // Ensure it's top
            return
        }

        // 2. No overlay found on active space. Proceed to create one.
        
        // Get current space index (needed for offset calculation)
        // Default to space 1 if detection fails, to ensure we at least show something.
        let currentSpaceIndex = getCurrentSpaceIndex() ?? 1
        
        // Double check our internal map just in case (though step 1 is more robust for "active space")
        if overlaysBySpace[currentSpaceIndex] != nil {
            print(" [Overlay] Map says overlay exists for index \(currentSpaceIndex), but isOnActiveSpace was false. Re-checking/Showing.")
            overlaysBySpace[currentSpaceIndex]?.orderFrontRegardless()
            return
        }
        
        print(" [Overlay] Creating NEW overlay for space index \(currentSpaceIndex)")
        
        // Get all spaces to calculate desktop count
        let spaces = YabaiAutomation.shared.getAllSpaces()
        let desktopCount = max(spaces.count, 1) // Ensure at least 1
        
        // Get main screen
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame // This is the size of ONE screen
        
        // Calculate desktop index (0-based)
        let desktopIndex = currentSpaceIndex - 1
        
        // Create the SwiftUI view for this specific desktop slice
        // We pass the desktop index so it knows which part of the world to show
        let contentView = OverlayView(
            desktopCount: desktopCount,
            desktopIndex: desktopIndex,
            screenSize: screenFrame.size
        )
        
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
        // .moveToActiveSpace allows it to follow? NO, we want it stuck to its space.
        // .canJoinAllSpaces false means it sticks to the current one.
        window.collectionBehavior = [
            .fullScreenAuxiliary,     // Appear above fullscreen apps
            .ignoresCycle,            // Don't appear in window cycling
            .transient,               // Don't show in Mission Control (optional, cleaner)
        ]
        
        // Explicitly NOT .canJoinAllSpaces, so it stays here.
        
        window.isMovable = false
        window.isMovableByWindowBackground = false
        
        // Make click-through immediately
        window.ignoresMouseEvents = true
        
        // Set content view
        window.contentView = NSHostingView(rootView: contentView)
        
        // Position window
        window.setFrame(screenFrame, display: true)
        
        // Make window visible and ensure it's on top
        // Do NOT use makeKeyAndOrderFront because this is a borderless/passive window 
        // and shouldn't steal focus. It causes warnings if we try.
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
