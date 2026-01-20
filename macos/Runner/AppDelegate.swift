import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        WindowController.hideDockIcon()
        
        // Get Flutter view controller
        let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        
        // Set up method channel for window configuration
        methodChannel = FlutterMethodChannel(
            name: "com.macpet.window/config",
            binaryMessenger: controller.engine.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard call.method == "configureWindow" else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            // Configure window properties
            if let window = self?.mainFlutterWindow {
                WindowController.configureWindow(window)
                result(nil)
            } else {
                result(FlutterError(
                    code: "WINDOW_NOT_FOUND",
                    message: "Main window not found",
                    details: nil
                ))
            }
        }
        
        // Configure window after a short delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = self.mainFlutterWindow {
                WindowController.configureWindow(window)
            }
        }
        
        super.applicationDidFinishLaunching(notification)
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
