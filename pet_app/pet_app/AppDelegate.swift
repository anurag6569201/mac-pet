//
//  AppDelegate.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    var windowNumbers: [Int: Int] = [:] // Maps window number to space index
    var keepOnTopTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start Yabai verification sequence
        YabaiAutomation.shared.startVerification()
        
        // Hide dock icon and Cmd+Tab
        NSApp.setActivationPolicy(.accessory)
        
        // Get main screen
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame
        let screenWidth = screenFrame.width
        _ = screenFrame.height
        
        // Get all spaces/desktops
        let spaces = YabaiAutomation.shared.getAllSpaces()
        let desktopCount = spaces.count
        
        // Get current space to return to later
        let currentSpace = spaces.first(where: { $0.hasFocus })?.index ?? spaces.first?.index ?? 1
        
        // Create one window per desktop by switching to each space sequentially
        // This ensures each window is created on its target space
        self.createWindowsSequentially(
            spaces: spaces,
            screenFrame: screenFrame,
            desktopCount: desktopCount,
            currentSpace: currentSpace,
            index: 0
        )
        
        // Periodically ensure windows stay on top
        keepOnTopTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.windows.forEach { $0.orderFrontRegardless() }
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
        windows.forEach { $0.orderFrontRegardless() }
    }
    
    private func createWindowsSequentially(
        spaces: [YabaiSpace],
        screenFrame: CGRect,
        desktopCount: Int,
        currentSpace: Int,
        index: Int
    ) {
        guard index < spaces.count else {
            // All windows created, return to original space and make click-through
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.switchToSpace(spaceIndex: currentSpace) {
                    // Make all windows click-through
                    self.makeWindowsClickThrough()
                }
            }
            return
        }
        
        let space = spaces[index]
        let screenWidth = screenFrame.width
        let desktopIndex = space.index - 1
        let xOffset = -CGFloat(desktopIndex) * screenWidth
        
        // Create the SwiftUI view with desktop count and offset
        let contentView = OverlayView(desktopCount: desktopCount, xOffset: xOffset)
        
        // Switch to this space and create window there
        switchToSpaceAndCreateWindow(
            space: space,
            contentView: contentView,
            screenFrame: screenFrame,
            xOffset: xOffset
        ) {
            // After window is created, move to next space
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.createWindowsSequentially(
                    spaces: spaces,
                    screenFrame: screenFrame,
                    desktopCount: desktopCount,
                    currentSpace: currentSpace,
                    index: index + 1
                )
            }
        }
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
    
    private func switchToSpace(spaceIndex: Int, completion: @escaping () -> Void) {
        // Check if we're already on this space
        if let currentSpace = getCurrentSpaceIndex(), currentSpace == spaceIndex {
            print(" [SpaceSwitch] Already on space \(spaceIndex), skipping switch")
            completion()
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yabai")
        process.arguments = ["-m", "space", "--focus", "\(spaceIndex)"]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Check if we successfully switched
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let newSpace = self.getCurrentSpaceIndex(), newSpace == spaceIndex {
                    print(" [SpaceSwitch] ✓ Successfully switched to space \(spaceIndex)")
                    completion()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown"
                    print(" [SpaceSwitch] ✗ Failed to switch to space \(spaceIndex): \(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines))")
                    // Still call completion - window will be created on current space
                    completion()
                }
            }
        } catch {
            print(" [SpaceSwitch] Error switching space: \(error)")
            completion()
        }
    }
    
    private func switchToSpaceAndCreateWindow(space: YabaiSpace, contentView: OverlayView, screenFrame: CGRect, xOffset: CGFloat, completion: @escaping () -> Void) {
        // Switch to the target space
        switchToSpace(spaceIndex: space.index) {
            // Verify we're on the correct space before creating window
            let currentSpace = self.getCurrentSpaceIndex()
            if currentSpace == space.index {
                print(" [WindowCreate] Confirmed on space \(space.index), creating window...")
            } else {
                print(" [WindowCreate] ⚠ Warning: On space \(currentSpace ?? -1) instead of \(space.index), creating window anyway...")
            }
            
            // Create window on this space
            let window = NSWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            // Set a unique title
            window.title = "mac-pet-overlay-space-\(space.index)"
            
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
            
            // Don't set ignoresMouseEvents yet
            window.isMovable = false
            window.isMovableByWindowBackground = false
            
            // Set content view
            window.contentView = NSHostingView(rootView: contentView)
            
            // Position window
            window.setFrame(screenFrame, display: true)
            
            // Make window visible and ensure it's on top
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            
            self.windows.append(window)
            print(" [WindowCreate] ✓ Created window '\(window.title)' (target space: \(space.index), current space: \(currentSpace ?? -1))")
            
            // Call completion after a brief delay to ensure window is fully created
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion()
            }
        }
    }
    
    private func moveWindowsToSpaces(spaces: [YabaiSpace], completion: @escaping () -> Void) {
        // Query yabai for all windows from our app
        let queryProcess = Process()
        queryProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yabai")
        queryProcess.arguments = ["-m", "query", "--windows"]
        
        let pipe = Pipe()
        queryProcess.standardOutput = pipe
        
        do {
            try queryProcess.run()
            queryProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let jsonString = String(data: data, encoding: .utf8) {
                print(" [WindowMove] Yabai windows JSON: \(jsonString.prefix(500))")
                
                if let jsonData = jsonString.data(using: .utf8),
                   let yabaiWindows = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    
                    // Try multiple methods to find our windows
                    let ourPid = ProcessInfo.processInfo.processIdentifier
                    let appName = Bundle.main.bundleIdentifier ?? "pet_app"
                    
                    print(" [WindowMove] Looking for windows with PID: \(ourPid), App: \(appName)")
                    print(" [WindowMove] Total windows in yabai: \(yabaiWindows.count)")
                    
                    // Method 1: Filter by PID
                    var ourWindows = yabaiWindows.compactMap { window -> (id: Int, title: String, pid: Int)? in
                        if let pid = window["pid"] as? Int,
                           let windowId = window["id"] as? Int,
                           let title = window["title"] as? String {
                            return (id: windowId, title: title, pid: pid)
                        }
                        return nil
                    }
                    
                    // Filter by our PID
                    ourWindows = ourWindows.filter { $0.pid == ourPid }
                    
                    // Method 2: If PID doesn't work, try by app name and title pattern
                    if ourWindows.isEmpty {
                        print(" [WindowMove] No windows found by PID, trying by app name and title...")
                        for window in yabaiWindows {
                            if let app = window["app"] as? String,
                               let windowId = window["id"] as? Int,
                               let title = window["title"] as? String {
                                if title.contains("mac-pet-overlay") {
                                    ourWindows.append((id: windowId, title: title, pid: window["pid"] as? Int ?? 0))
                                }
                            }
                        }
                    }
                    
                    print(" [WindowMove] Found \(ourWindows.count) windows from our app")
                    for win in ourWindows {
                        print("   - ID: \(win.id), Title: '\(win.title)', PID: \(win.pid)")
                    }
                    
                    // Match windows to spaces by title
                    for space in spaces {
                        let expectedTitle = "mac-pet-overlay-space-\(space.index)"
                        if let window = ourWindows.first(where: { $0.title == expectedTitle }) {
                            // Move window to its target space
                            let moveProcess = Process()
                            moveProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yabai")
                            moveProcess.arguments = ["-m", "window", "\(window.id)", "--space", "\(space.index)"]
                            
                            let errorPipe = Pipe()
                            moveProcess.standardError = errorPipe
                            
                            do {
                                try moveProcess.run()
                                moveProcess.waitUntilExit()
                                
                                if moveProcess.terminationStatus == 0 {
                                    print(" [WindowMove] ✓ Moved window '\(window.title)' (ID: \(window.id)) to space \(space.index)")
                                } else {
                                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown"
                                    print(" [WindowMove] ✗ Failed to move window '\(window.title)' to space \(space.index): \(errorMsg)")
                                }
                            } catch {
                                print(" [WindowMove] Error moving window: \(error)")
                            }
                            
                            // Small delay between moves
                            Thread.sleep(forTimeInterval: 0.15)
                        } else {
                            print(" [WindowMove] ⚠ Could not find window with title '\(expectedTitle)'")
                            // List all available titles for debugging
                            print(" [WindowMove] Available titles: \(ourWindows.map { $0.title })")
                        }
                    }
                }
            }
        } catch {
            print(" [WindowMove] Error querying windows: \(error)")
        }
        
        // Call completion after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion()
        }
    }
    
    private func makeWindowsClickThrough() {
        // Now make all windows borderless and click-through
        for window in windows {
            // Change to borderless style
            window.styleMask = [.borderless]
            // Make click-through
            window.ignoresMouseEvents = true
            print(" [WindowSetup] Made window borderless and click-through: \(window.title)")
        }
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
