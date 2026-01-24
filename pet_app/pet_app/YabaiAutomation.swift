import Foundation

/// Yabai Space Model for JSON Parsing
struct YabaiSpace: Codable {
    let id: Int
    let uuid: String
    let index: Int
    let label: String
    let type: String
    let display: Int
    let windows: [Int]
    let hasFocus: Bool
    let isVisible: Bool
    let isNativeFullscreen: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case index
        case label
        case type
        case display
        case windows
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}

class YabaiAutomation {
    static let shared = YabaiAutomation()
    
    private let yabaiPath = "/opt/homebrew/bin/yabai"
    private var fifoPath: String {
        return NSTemporaryDirectory().appending("yabai_events.fifo")
    }
    
    private var isListening = false
    var onSpaceChanged: (() -> Void)?
    
    // MARK: - Public API
    
    func startVerification() {
        print(" [YabaiStartup] Starting Yabai Verification...")
        
        // 1. Initial Query
        runQuery(context: "[YabaiStartup]")
        
        // 2. Setup Signals (Realtime Verification)
        setupRealtimeVerification()
    }
    
    func getDesktopCount() -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: yabaiPath)
        process.arguments = ["-m", "query", "--spaces"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus == 0 {
                do {
                    let spaces = try JSONDecoder().decode([YabaiSpace].self, from: data)
                    return spaces.count
                } catch {
                    print(" [YabaiError] JSON Parsing Failed: \(error)")
                    return 1
                }
            } else {
                return 1
            }
        } catch {
            print(" [YabaiError] Failed to execute process: \(error)")
            return 1
        }
    }
    
    func getAllSpaces() -> [YabaiSpace] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: yabaiPath)
        process.arguments = ["-m", "query", "--spaces"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus == 0 {
                do {
                    let spaces = try JSONDecoder().decode([YabaiSpace].self, from: data)
                    return spaces
                } catch {
                    print(" [YabaiError] JSON Parsing Failed: \(error)")
                    return []
                }
            } else {
                return []
            }
        } catch {
            print(" [YabaiError] Failed to execute process: \(error)")
            return []
        }
    }
    
    func moveWindowToSpace(windowId: Int, spaceIndex: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: yabaiPath)
        process.arguments = ["-m", "window", "--warp", "space:\(spaceIndex)"]
        
        // Note: This requires the window ID, but we'll use a different approach
        // We'll use the window's accessibility identifier or try a different method
    }
    
    // MARK: - Query Logic
    
    private func runQuery(context: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: yabaiPath)
        process.arguments = ["-m", "query", "--spaces"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus == 0 {
                // Raw JSON logging suppressed per user request
                // Parse and Log Metrics
                parseAndLogMetrics(data: data, context: context)
            } else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
                print(" [YabaiError] Query Failed: \(errorMsg)")
            }
            
        } catch {
            print(" [YabaiError] Failed to execute process: \(error)")
        }
    }
    
    private func parseAndLogMetrics(data: Data, context: String) {
        do {
            let spaces = try JSONDecoder().decode([YabaiSpace].self, from: data)
            
            let spaceCount = spaces.count
            let activeSpace = spaces.first(where: { $0.hasFocus })
            let activeIndex = activeSpace?.index ?? -1
            let activeWindowCount = activeSpace?.windows.count ?? 0
            
            print(" \(context) Stats:")
            print("   • Number of Desktops: \(spaceCount)")
            print("   • Current Desktop Index: \(activeIndex)")
            print("   • Windows on Current Desktop: \(activeWindowCount)")
            
        } catch {
            print(" [YabaiError] JSON Parsing Failed: \(error)")
        }
    }
    
    // MARK: - Realtime Verification (Signals & FIFO)
    
    private func setupRealtimeVerification() {
        // 1. Create FIFO if needed
        createFifo()
        
        // 2. Start Listening Thread
        startListeningToFifo()
        
        // 3. Register Signals with yabai
        registerSignals()
    }
    
    private func createFifo() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fifoPath) {
            _ = try? fileManager.removeItem(atPath: fifoPath)
        }
        
        // mkfifo
        let mkfifo = Process()
        mkfifo.executableURL = URL(fileURLWithPath: "/usr/bin/mkfifo")
        mkfifo.arguments = [fifoPath]
        try? mkfifo.run()
        mkfifo.waitUntilExit()
    }
    
    private func startListeningToFifo() {
        guard !isListening else { return }
        isListening = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            while true {
                // Blocking read
                // We use open/read in C-style or simple String(contentsOfFile:) which might not block correctly for FIFO in Swift wrapper?
                // Better to use FileHandle.
                if let fileHandle = FileHandle(forReadingAtPath: self.fifoPath) {
                    // This blocks until data is present (and writer opens it)
                    let data = fileHandle.availableData
                    if !data.isEmpty, let event = String(data: data, encoding: .utf8) {
                        let trimmedEvent = event.trimmingCharacters(in: .whitespacesAndNewlines)
                        print(" [YabaiSignal] Received: \(trimmedEvent)")
                        
                        // Re-run query
                        self.runQuery(context: "[YabaiQuery]")
                        
                        // Notify about space changes
                        if trimmedEvent == "space_changed" {
                            DispatchQueue.main.async {
                                self.onSpaceChanged?()
                            }
                        }
                    }
                    fileHandle.closeFile()
                } else {
                    // Wait a bit if file doesn't exist yet
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
        }
    }
    
    private func registerSignals() {
        let events = ["space_created", "space_destroyed", "space_changed"]
        
        for event in events {
            let command = "echo \(event) > \(fifoPath)"
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: yabaiPath)
            // Remove existing signal first? "register" usually appends.
            // But we don't need cleanup logic.
            // yabai -m signal --add event=... action=...
            process.arguments = ["-m", "signal", "--add", "event=\(event)", "action=\(command)"]
            
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    print(" [YabaiStartup] Registered signal for \(event)")
                } else {
                    print(" [YabaiError] Failed to register signal for \(event)")
                }
            } catch {
                print(" [YabaiError] Failed to run registration process: \(error)")
            }
        }
    }
}
