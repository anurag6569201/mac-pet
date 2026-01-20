import Cocoa
import FlutterMacOS

/// Controller for configuring the main window properties
/// Sets up transparent, borderless, always-on-top window behavior
class WindowController {
    static func configureWindow(_ window: NSWindow) {
        // Set window style to borderless and full-size content view
        window.styleMask = [.borderless, .fullSizeContentView]
        
        // Make window background transparent
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        // Set window level to floating (always on top)
        // Using .floating ensures it appears above all other windows
        window.level = .floating
        
        // Configure collection behavior for all spaces
        // .canJoinAllSpaces: Window appears on all Spaces
        // .stationary: Window doesn't move when switching Spaces
        // .ignoresCycle: Window doesn't participate in window cycling
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Don't hide window when app is deactivated
        window.hidesOnDeactivate = false
        
        // Prevent window from becoming key window (won't steal focus)
        window.canBecomeKey = false
        
        // Allow window to accept mouse events even when not key
        window.acceptsMouseMovedEvents = true
        
        // Make window ignore mouse events except for the pet widget area
        // This is handled by Flutter, but we ensure the window can receive events
        window.ignoresMouseEvents = false
        
        // Set window to not be resizable
        window.styleMask.insert(.fullSizeContentView)
        
        // Center window initially (will be overridden by Flutter)
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let windowRect = NSRect(
                x: screenRect.midX - window.frame.width / 2,
                y: screenRect.midY - window.frame.height / 2,
                width: window.frame.width,
                height: window.frame.height
            )
            window.setFrame(windowRect, display: true)
        }
    }
    
    /// Hide dock icon by setting activation policy to accessory
    static func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
    }
}
