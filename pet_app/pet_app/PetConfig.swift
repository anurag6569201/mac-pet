import SceneKit

struct PetConfig {
    // MARK: - Character Settings
    static var characterScale = SCNVector3(0.7, 0.7, 0.7)
    
    // MARK: - Animation Speeds & Durations
    static let walkSpeed: CGFloat = 130.0
    static let runSpeed: CGFloat = 550.0
    static let slowRunSpeed: CGFloat = 380.0

    static let fallDuration: TimeInterval = 1.0
    static let standUpDuration: TimeInterval = 1.0
    static let overlapDuration: TimeInterval = 0.5
    static let transitionDuration: CGFloat = 0.3
    static let jumpSpeed: CGFloat = 380.0 // Little less than runSpeed (550)
    static let jumpPrepareDistance: CGFloat = 150.0 // Distance from edge to start/land jumping
    
    // MARK: - Positions
    static func startPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(size.width + 100, size.height + 200, 0)
    }
    
    static func groundPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(size.width - 200, 0, 0)
    }
    
    static func finalPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(50, 0, 0)
    }
    
    // MARK: - Asset Paths
    static let characterModel = "Assets.scnassets/character.dae"
    static let diffuseTexture = "diffuse.png"
    static let assetsDirectory = "Assets.scnassets"
    static let walkingAnimationFile = "running/normal-walking.dae"
    static let fastRunAnimationFile = "running/fast-run.dae"
    static let slowRunAnimationFile = "running/slow-run.dae"
    static let lookAroundAnimationFile = "idle-state/look-around.dae"
    static let idleBreathingAnimationFile = "idle-state/idle-looking.dae"
    static let armStretchAnimationFile = "idle-state/arm-stretching.dae"
    static let neckStretchAnimationFile = "idle-state/neck-stretching.dae"
    static let yawnAnimationFile = "idle-state/Yawn.dae"
    static let jumpOverAnimationFile = "transition/jump-over.dae"
    
    // Mouse Behavior Animation Files
    static let angryEmotionAnimationFile = "mouse_behavior/angry-emotion.dae"
    static let doubleHandWaveAnimationFile = "mouse_behavior/doublehand-wave.dae"
    static let oneHandWaveAnimationFile = "mouse_behavior/onehand-wave.dae"
    static let pointingGestureAnimationFile = "mouse_behavior/pointing-gesture.dae"
    static let surpriseAnimationFile = "mouse_behavior/surprise.dae"
    
    // MARK: - Idle Animation Settings
    static let idleTimeout: TimeInterval = 5.0
    static let rotationTransitionDuration: TimeInterval = 0.5
    
    // Look Around Settings
    static let lookAroundMinInterval: TimeInterval = 5.0
    static let lookAroundMaxInterval: TimeInterval = 10.0
    
    // Long Idle Settings (Stretch/Yawn)
    static let longIdleTimeout: TimeInterval = 30.0
    
    // Random Scratch Settings
    static let scratchCheckInterval: TimeInterval = 5.0
    static let scratchChance: Double = 0.05 // 5% chance per check
    
    // MARK: - Mouse Behavior Settings
    // Proximity detection (in screen points)
    static let mouseProximityNear: CGFloat = 250.0 // For waves and pointing
    static let mouseProximityClose: CGFloat = 200.0 // For surprise
    
    // Velocity tracking (points per second)
    static let mouseVelocityRapid: CGFloat = 800.0 // For angry emotion
    static let mouseVelocitySudden: CGFloat = 1500.0 // For surprise (sudden jumps)
    
    // Cooldown timers (seconds) - prevent spam
    static let angryEmotionCooldown: TimeInterval = 8.0
    static let doubleWaveCooldown: TimeInterval = 10.0
    static let oneHandWaveCooldown: TimeInterval = 5.0
    static let pointingCooldown: TimeInterval = 3.0
    static let surpriseCooldown: TimeInterval = 6.0
    
    // Hover detection
    static let hoverDuration: TimeInterval = 20.0 // How long mouse must hover for one hand wave
    
    // Mouse history tracking
    static let mouseHistorySize: Int = 10 // Number of recent positions to track
    
    // MARK: - Mouse Following Settings
    static let mouseDeadZoneRadius: CGFloat = 1.0 // Minimum distance before pet starts moving
}

