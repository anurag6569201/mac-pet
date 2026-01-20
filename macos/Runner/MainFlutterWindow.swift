import Cocoa
import FlutterMacOS

/// Main Flutter window delegate
/// Handles window behavior and ensures proper configuration
class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Configure window properties when window is created
        WindowController.configureWindow(self)
    }
    
    // Override to prevent window from becoming key (won't steal focus)
    override var canBecomeKey: Bool {
        return false
    }
    
    // Override to prevent window from becoming main window
    override var canBecomeMain: Bool {
        return false
    }
    
    // Allow window to accept mouse events
    override func acceptsMouseMovedEvents() -> Bool {
        return true
    }
}
